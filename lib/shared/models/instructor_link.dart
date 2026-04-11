// Instructor-student link model — maps to `instructor_links/{linkId}`.
// Kept at the top level because it involves two users.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Records a verified instructor-student relationship.
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

  /// Constructs an [InstructorLink] from a Firestore document snapshot.
  factory InstructorLink.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return InstructorLink(
      id: doc.id,
      instructorId: data['instructor_id'] ?? '',
      studentId: data['student_id'] ?? '',
      linkedAt:
          (data['linked_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Serialises this link to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'instructor_id': instructorId,
    'student_id': studentId,
    'linked_at': Timestamp.fromDate(linkedAt),
  };

  /// Returns a copy with the given fields replaced.
  InstructorLink copyWith({
    String? id,
    String? instructorId,
    String? studentId,
    DateTime? linkedAt,
  }) {
    return InstructorLink(
      id: id ?? this.id,
      instructorId: instructorId ?? this.instructorId,
      studentId: studentId ?? this.studentId,
      linkedAt: linkedAt ?? this.linkedAt,
    );
  }
}
