// Instructor note model — maps to `instructor_notes/{noteId}`.
// Kept at the top level because instructor writes it but student owns it.
import 'package:cloud_firestore/cloud_firestore.dart';

/// A note written by an instructor about a student's performance on an exercise.
class InstructorNote {
  final String id;
  final String instructorId;
  final String studentId;
  final String exerciseId;
  final String content;
  final DateTime createdAt;

  const InstructorNote({
    required this.id,
    required this.instructorId,
    required this.studentId,
    required this.exerciseId,
    required this.content,
    required this.createdAt,
  });

  /// Constructs an [InstructorNote] from a Firestore document snapshot.
  factory InstructorNote.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return InstructorNote(
      id: doc.id,
      instructorId: data['instructor_id'] ?? '',
      studentId: data['student_id'] ?? '',
      exerciseId: data['exercise_id'] ?? '',
      content: data['content'] ?? '',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serialises this note to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'instructor_id': instructorId,
    'student_id': studentId,
    'exercise_id': exerciseId,
    'content': content,
    'created_at': Timestamp.fromDate(createdAt),
  };

  /// Returns a copy with the given fields replaced.
  InstructorNote copyWith({
    String? id,
    String? instructorId,
    String? studentId,
    String? exerciseId,
    String? content,
    DateTime? createdAt,
  }) {
    return InstructorNote(
      id: id ?? this.id,
      instructorId: instructorId ?? this.instructorId,
      studentId: studentId ?? this.studentId,
      exerciseId: exerciseId ?? this.exerciseId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
