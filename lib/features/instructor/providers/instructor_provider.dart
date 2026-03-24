// Providers for instructor features — student linking, student list, and notes.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/lesson.dart';
import '../../../shared/models/user_exercise.dart';
import '../../../shared/utils/input_sanitiser.dart';

// ---------------------------------------------------------------------------
// Instructor link model
// ---------------------------------------------------------------------------

/// Represents a link between an instructor and a student.
class InstructorLink {
  final String id;
  final String instructorId;
  final String studentId;
  final DateTime linkedAt;

  const InstructorLink({
    required this.id,
    required this.instructorId,
    required this.studentId,
    required this.linkedAt,
  });

  factory InstructorLink.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InstructorLink(
      id: doc.id,
      instructorId: data['instructor_id'] ?? '',
      studentId: data['student_id'] ?? '',
      linkedAt: (data['linked_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Instructor note model
// ---------------------------------------------------------------------------

/// A note left by an instructor for a specific student on a specific exercise.
class InstructorNote {
  final String id;
  final String instructorId;
  final String studentId;
  final String exerciseId;
  final String note;
  final DateTime createdAt;

  const InstructorNote({
    required this.id,
    required this.instructorId,
    required this.studentId,
    required this.exerciseId,
    required this.note,
    required this.createdAt,
  });

  factory InstructorNote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InstructorNote(
      id: doc.id,
      instructorId: data['instructor_id'] ?? '',
      studentId: data['student_id'] ?? '',
      exerciseId: data['exercise_id'] ?? '',
      note: data['note'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'instructor_id': instructorId,
    'student_id': studentId,
    'exercise_id': exerciseId,
    'note': note,
    'created_at': Timestamp.fromDate(createdAt),
  };
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Streams instructor links for the current user (as instructor).
final linkedStudentsProvider = StreamProvider<List<InstructorLink>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('instructor_links')
      .where('instructor_id', isEqualTo: uid)
      .orderBy('linked_at', descending: true)
      .snapshots()
      .map((qs) =>
          qs.docs.map((doc) => InstructorLink.fromFirestore(doc)).toList());
});

/// Fetches full AppUser profiles for all linked students.
/// Uses batched whereIn queries (max 10 per Firestore limitation).
final linkedStudentProfilesProvider =
    FutureProvider<List<AppUser>>((ref) async {
  final linksAsync = ref.watch(linkedStudentsProvider);
  final links = linksAsync.valueOrNull ?? [];
  if (links.isEmpty) return [];

  final db = FirebaseFirestore.instance;
  final studentIds = links.map((l) => l.studentId).toList();
  final profiles = <AppUser>[];

  // Firestore whereIn supports max 10 items per query
  for (var i = 0; i < studentIds.length; i += 10) {
    final batch = studentIds.sublist(
      i,
      i + 10 > studentIds.length ? studentIds.length : i + 10,
    );
    final snap = await db
        .collection('users')
        .where(FieldPath.documentId, whereIn: batch)
        .get();
    for (final doc in snap.docs) {
      profiles.add(AppUser.fromFirestore(doc));
    }
  }
  return profiles;
});

/// Streams the instructor link for the current student (if any).
final studentInstructorLinkProvider =
    StreamProvider<InstructorLink?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('instructor_links')
      .where('student_id', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .map((qs) =>
          qs.docs.isEmpty ? null : InstructorLink.fromFirestore(qs.docs.first));
});

/// Streams lessons for a specific student (used by instructor views).
final studentLessonsProvider =
    StreamProvider.family<List<Lesson>, String>((ref, studentId) {
  return FirebaseFirestore.instance
      .collection('lessons')
      .where('user_id', isEqualTo: studentId)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((qs) =>
          qs.docs.map((doc) => Lesson.fromFirestore(doc)).toList());
});

/// Streams user exercises for a specific student (used by instructor views).
final studentExercisesProvider =
    StreamProvider.family<List<UserExercise>, String>((ref, studentId) {
  return FirebaseFirestore.instance
      .collection('user_exercises')
      .where('user_id', isEqualTo: studentId)
      .snapshots()
      .map((qs) =>
          qs.docs.map((doc) => UserExercise.fromFirestore(doc)).toList());
});

/// Streams instructor notes for a specific student.
final instructorNotesProvider =
    StreamProvider.family<List<InstructorNote>, String>((ref, studentId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('instructor_notes')
      .where('instructor_id', isEqualTo: uid)
      .where('student_id', isEqualTo: studentId)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((qs) =>
          qs.docs.map((doc) => InstructorNote.fromFirestore(doc)).toList());
});

/// Streams instructor notes for the current student on a specific exercise
/// (shown in the student's prepare hub).
final studentInstructorNotesProvider =
    StreamProvider.family<List<InstructorNote>, String>((ref, exerciseId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('instructor_notes')
      .where('student_id', isEqualTo: uid)
      .where('exercise_id', isEqualTo: exerciseId)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((qs) =>
          qs.docs.map((doc) => InstructorNote.fromFirestore(doc)).toList());
});

// ---------------------------------------------------------------------------
// Service functions
// ---------------------------------------------------------------------------

/// Links a student to an instructor using the instructor's invite code.
/// Returns a descriptive error string on failure, or null on success.
Future<String?> linkStudentToInstructor(String inviteCode, String studentId) async {
  final db = FirebaseFirestore.instance;
  // Find the instructor with this invite code
  final instructorQuery = await db
      .collection('users')
      .where('invite_code', isEqualTo: inviteCode.toUpperCase())
      .where('user_role', isEqualTo: 'instructor')
      .limit(1)
      .get();

  if (instructorQuery.docs.isEmpty) {
    return 'No instructor found with that code. Please check and try again.';
  }

  final instructorId = instructorQuery.docs.first.id;

  if (instructorId == studentId) {
    return 'You cannot link to yourself.';
  }

  // Check if already linked
  final existingLink = await db
      .collection('instructor_links')
      .where('instructor_id', isEqualTo: instructorId)
      .where('student_id', isEqualTo: studentId)
      .limit(1)
      .get();

  if (existingLink.docs.isNotEmpty) {
    return 'You are already linked to this instructor.';
  }

  // Create the link with a deterministic doc ID so Firestore rules can
  // verify the relationship via exists() checks.
  final linkDocId = '${instructorId}_$studentId';
  await db.collection('instructor_links').doc(linkDocId).set({
    'instructor_id': instructorId,
    'student_id': studentId,
    'linked_at': FieldValue.serverTimestamp(),
  });

  return null; // success
}

/// Removes the link between a student and their instructor.
Future<void> unlinkStudent(String studentId) async {
  final links = await FirebaseFirestore.instance
      .collection('instructor_links')
      .where('student_id', isEqualTo: studentId)
      .get();

  for (final doc in links.docs) {
    await doc.reference.delete();
  }
}

/// Saves an instructor note for a student on a specific exercise.
/// Defence-in-depth: sanitises the note text before writing to Firestore.
Future<void> saveInstructorNote({
  required String instructorId,
  required String studentId,
  required String exerciseId,
  required String note,
}) async {
  final sanitisedNote = InputSanitiser.sanitise(
    note,
    maxLength: InputSanitiser.maxMedium,
  );
  if (sanitisedNote.isEmpty) return; // Refuse to save empty notes.

  await FirebaseFirestore.instance.collection('instructor_notes').add({
    'instructor_id': instructorId,
    'student_id': studentId,
    'exercise_id': exerciseId,
    'note': sanitisedNote,
    'created_at': FieldValue.serverTimestamp(),
  });
}
