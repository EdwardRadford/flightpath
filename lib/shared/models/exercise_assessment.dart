// Instructor exercise criterion assessment model — maps to
// `exercise_assessments/{instructorId}_{studentId}_{exerciseId}`.
// Kept at the top level (not nested under users) because the instructor
// writes it but it relates to a specific student + exercise pair.
import 'package:cloud_firestore/cloud_firestore.dart';

/// A per-exercise, per-student assessment with individual criterion ratings.
class ExerciseAssessment {
  final String id;
  final String instructorId;
  final String studentId;
  final String exerciseId;

  /// Criterion key -> 1-5 rating.
  final Map<String, int> criteriaRatings;

  /// Optional overall 1-5 rating (instructor's holistic judgement).
  final int? overallRating;

  /// Whether the exercise has been formally signed off.
  final bool signedOff;

  /// Free-text instructor comments.
  final String notes;

  final DateTime assessedAt;
  final DateTime updatedAt;

  const ExerciseAssessment({
    required this.id,
    required this.instructorId,
    required this.studentId,
    required this.exerciseId,
    required this.criteriaRatings,
    this.overallRating,
    this.signedOff = false,
    this.notes = '',
    required this.assessedAt,
    required this.updatedAt,
  });

  /// Constructs an [ExerciseAssessment] from a Firestore document snapshot.
  factory ExerciseAssessment.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return ExerciseAssessment(
      id: doc.id,
      instructorId: data['instructor_id'] ?? '',
      studentId: data['student_id'] ?? '',
      exerciseId: data['exercise_id'] ?? '',
      criteriaRatings: Map<String, int>.from(
        ((data['criteria_ratings'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      ),
      overallRating: (data['overall_rating'] as num?)?.toInt(),
      signedOff: data['signed_off'] ?? false,
      notes: data['notes'] ?? '',
      assessedAt:
          (data['assessed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serialises this assessment to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'instructor_id': instructorId,
    'student_id': studentId,
    'exercise_id': exerciseId,
    'criteria_ratings': criteriaRatings,
    if (overallRating != null) 'overall_rating': overallRating,
    'signed_off': signedOff,
    'notes': notes,
    'assessed_at': Timestamp.fromDate(assessedAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  /// Returns a copy with the given fields replaced.
  ExerciseAssessment copyWith({
    String? id,
    String? instructorId,
    String? studentId,
    String? exerciseId,
    Map<String, int>? criteriaRatings,
    int? overallRating,
    bool? signedOff,
    String? notes,
    DateTime? assessedAt,
    DateTime? updatedAt,
  }) {
    return ExerciseAssessment(
      id: id ?? this.id,
      instructorId: instructorId ?? this.instructorId,
      studentId: studentId ?? this.studentId,
      exerciseId: exerciseId ?? this.exerciseId,
      criteriaRatings: criteriaRatings ?? this.criteriaRatings,
      overallRating: overallRating ?? this.overallRating,
      signedOff: signedOff ?? this.signedOff,
      notes: notes ?? this.notes,
      assessedAt: assessedAt ?? this.assessedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
