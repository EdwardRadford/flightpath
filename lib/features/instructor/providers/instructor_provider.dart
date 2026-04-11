// Providers for instructor features — student linking, student list, and notes.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/models/instructor_link.dart';
import 'package:flight_path/shared/models/exercise_assessment.dart';
import 'package:flight_path/shared/models/instructor_note.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/models/message.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';

final _db = FirebaseFirestore.instance;

// ---------------------------------------------------------------------------
// Linked students — stream instructor links then fetch profiles
// ---------------------------------------------------------------------------

/// Streams instructor links for the current user (as instructor).
final linkedStudentsProvider = StreamProvider<List<InstructorLink>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  return _db
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

  final studentIds = links.map((l) => l.studentId).toList();
  final profiles = <AppUser>[];

  // Firestore whereIn supports max 10 items per query
  for (var i = 0; i < studentIds.length; i += 10) {
    final batch = studentIds.sublist(
      i,
      i + 10 > studentIds.length ? studentIds.length : i + 10,
    );
    final snap = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: batch)
        .get();
    for (final doc in snap.docs) {
      profiles.add(AppUser.fromFirestore(doc));
    }
  }
  return profiles;
});

// ---------------------------------------------------------------------------
// Student instructor link — for the student side (link / unlink)
// ---------------------------------------------------------------------------

/// Streams the instructor link for the current student (if any).
final studentInstructorLinkProvider =
    StreamProvider<InstructorLink?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);

  return _db
      .collection('instructor_links')
      .where('student_id', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .map((qs) => qs.docs.isEmpty
          ? null
          : InstructorLink.fromFirestore(qs.docs.first));
});

// ---------------------------------------------------------------------------
// Student data providers — used by instructor views
// ---------------------------------------------------------------------------

/// Streams lessons for a specific student (used by instructor views).
final studentLessonsProvider =
    StreamProvider.family<List<Lesson>, String>((ref, studentId) {
  return _db
      .collection('users')
      .doc(studentId)
      .collection('lessons')
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((qs) =>
          qs.docs.map((doc) => Lesson.fromFirestore(doc)).toList());
});

/// Streams user exercises for a specific student (used by instructor views).
final studentExercisesProvider =
    StreamProvider.family<List<UserExercise>, String>((ref, studentId) {
  return _db
      .collection('users')
      .doc(studentId)
      .collection('exercises')
      .snapshots()
      .map((qs) =>
          qs.docs.map((doc) => UserExercise.fromFirestore(doc)).toList());
});

// ---------------------------------------------------------------------------
// Instructor notes
// ---------------------------------------------------------------------------

/// Streams instructor notes for a specific student (written by the current
/// instructor).
final instructorNotesProvider =
    StreamProvider.family<List<InstructorNote>, String>((ref, studentId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  return _db
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

  return _db
      .collection('instructor_notes')
      .where('student_id', isEqualTo: uid)
      .where('exercise_id', isEqualTo: exerciseId)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((qs) =>
          qs.docs.map((doc) => InstructorNote.fromFirestore(doc)).toList());
});

// ---------------------------------------------------------------------------
// Exercise assessments
// ---------------------------------------------------------------------------

/// Streams all exercise assessments for a specific student written by the
/// current instructor.
final exerciseAssessmentsProvider =
    StreamProvider.family<List<ExerciseAssessment>, String>((ref, studentId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  return _db
      .collection('exercise_assessments')
      .where('instructor_id', isEqualTo: uid)
      .where('student_id', isEqualTo: studentId)
      .snapshots()
      .map((qs) => qs.docs
          .map((doc) => ExerciseAssessment.fromFirestore(doc))
          .toList());
});

/// Saves or updates an exercise assessment. Uses a deterministic doc ID
/// ({instructorId}_{studentId}_{exerciseId}) so repeated saves are upserts.
Future<void> saveExerciseAssessment({
  required String instructorId,
  required String studentId,
  required String exerciseId,
  required Map<String, int> criteriaRatings,
  int? overallRating,
  required bool signedOff,
  required String notes,
}) async {
  final sanitisedNotes = InputSanitiser.sanitise(
    notes,
    maxLength: InputSanitiser.maxMedium,
  );

  final docId = '${instructorId}_${studentId}_$exerciseId';
  final now = DateTime.now();

  // Check if document already exists to preserve assessedAt.
  final existing =
      await _db.collection('exercise_assessments').doc(docId).get();
  final assessedAt = existing.exists
      ? (existing.data()?['assessed_at'] as Timestamp?)?.toDate() ?? now
      : now;

  final assessment = ExerciseAssessment(
    id: docId,
    instructorId: instructorId,
    studentId: studentId,
    exerciseId: exerciseId,
    criteriaRatings: criteriaRatings,
    overallRating: overallRating,
    signedOff: signedOff,
    notes: sanitisedNotes,
    assessedAt: assessedAt,
    updatedAt: now,
  );

  await _db
      .collection('exercise_assessments')
      .doc(docId)
      .set(assessment.toFirestore());
}

// ---------------------------------------------------------------------------
// Messaging — conversations/{conversationId}/messages subcollection
// ---------------------------------------------------------------------------

/// Deterministic conversation ID for a pair of users (sorted UIDs joined by '_').
String _conversationId(String uid1, String uid2) {
  final sorted = [uid1, uid2]..sort();
  return sorted.join('_');
}

/// Streams messages between the current user and [otherUserId].
/// Messages live in `conversations/{id}/messages` subcollection.
final messagingProvider =
    StreamProvider.family<List<Message>, String>((ref, otherUserId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  final convId = _conversationId(uid, otherUserId);

  return _db
      .collection('conversations')
      .doc(convId)
      .collection('messages')
      .orderBy('created_at')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => Message.fromFirestore(doc)).toList());
});

// ---------------------------------------------------------------------------
// Service functions
// ---------------------------------------------------------------------------

/// Links a student to an instructor using the instructor's invite code.
/// Returns a descriptive error string on failure, or null on success.
Future<String?> linkStudentToInstructor(
    String inviteCode, String studentId) async {
  // Look up instructor via the invite_codes collection (O(1) doc read —
  // avoids querying the users collection which requires owner-level access).
  final codeDoc = await _db
      .collection('invite_codes')
      .doc(inviteCode.toUpperCase())
      .get();

  if (!codeDoc.exists) {
    return 'No instructor found with that code. Please check and try again.';
  }

  final instructorId = codeDoc.data()?['instructor_id'] as String?;
  if (instructorId == null || instructorId.isEmpty) {
    return 'Invalid invite code. Please ask your instructor for a new one.';
  }

  if (instructorId == studentId) {
    return 'You cannot link to yourself.';
  }

  // Check if already linked
  final existingLink = await _db
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
  await _db.collection('instructor_links').doc(linkDocId).set({
    'instructor_id': instructorId,
    'student_id': studentId,
    'linked_at': FieldValue.serverTimestamp(),
  });

  return null; // success
}

/// Removes the link between a student and their instructor.
Future<void> unlinkStudent(String studentId) async {
  final links = await _db
      .collection('instructor_links')
      .where('student_id', isEqualTo: studentId)
      .get();

  for (final doc in links.docs) {
    await doc.reference.delete();
  }
}

/// Saves an instructor note for a student on a specific exercise.
Future<void> saveInstructorNote({
  required String instructorId,
  required String studentId,
  required String exerciseId,
  required String note,
}) async {
  final sanitised = InputSanitiser.sanitise(
    note,
    maxLength: InputSanitiser.maxMedium,
  );
  if (sanitised.isEmpty) return;

  await _db.collection('instructor_notes').add({
    'instructor_id': instructorId,
    'student_id': studentId,
    'exercise_id': exerciseId,
    'content': sanitised,
    'created_at': FieldValue.serverTimestamp(),
  });
}

/// Sends a message in the `conversations/{id}/messages` subcollection.
Future<void> sendConversationMessage({
  required String senderId,
  required String recipientId,
  required String text,
}) async {
  final sanitised = InputSanitiser.sanitise(
    text,
    maxLength: InputSanitiser.maxMedium,
  );
  if (sanitised.isEmpty) return;

  final convId = _conversationId(senderId, recipientId);
  final convRef = _db.collection('conversations').doc(convId);

  // Ensure the conversation document exists with participant list.
  await convRef.set({
    'participant_ids': [senderId, recipientId],
    'last_message_at': FieldValue.serverTimestamp(),
    'last_message_preview': sanitised.length > 80
        ? '${sanitised.substring(0, 80)}…'
        : sanitised,
  }, SetOptions(merge: true));

  await convRef.collection('messages').add({
    'sender_id': senderId,
    'content': sanitised,
    'created_at': FieldValue.serverTimestamp(),
    'read': false,
  });
}

/// Marks all unread messages in the conversation as read for [currentUserId].
Future<void> markConversationAsRead({
  required String currentUserId,
  required String otherUserId,
}) async {
  final convId = _conversationId(currentUserId, otherUserId);

  final unread = await _db
      .collection('conversations')
      .doc(convId)
      .collection('messages')
      .where('sender_id', isEqualTo: otherUserId)
      .where('read', isEqualTo: false)
      .get();

  final batch = _db.batch();
  for (final doc in unread.docs) {
    batch.update(doc.reference, {'read': true});
  }
  await batch.commit();
}
