// Goal model — maps to documents in the Firestore `users/{uid}/goals`
// sub-collection. Tracks first-solo and full-PPL target dates.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Discriminator for goal type.
enum GoalType { firstSolo, fullPpl }

/// A training goal with a target date and completion state.
class Goal {
  final String id;
  final GoalType goalType;
  final DateTime targetDate;
  final DateTime createdAt;
  final bool completed;
  final DateTime? completedAt;
  final String notes;

  const Goal({
    required this.id,
    required this.goalType,
    required this.targetDate,
    required this.createdAt,
    required this.completed,
    this.completedAt,
    required this.notes,
  });

  /// Constructs a [Goal] from a Firestore document snapshot.
  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Goal(
      id: doc.id,
      goalType: data['goal_type'] == 'full_ppl'
          ? GoalType.fullPpl
          : GoalType.firstSolo,
      targetDate:
          (data['target_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completed: data['completed'] ?? false,
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
      notes: data['notes'] ?? '',
    );
  }

  /// Serialises this goal to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
        'goal_type': goalType == GoalType.fullPpl ? 'full_ppl' : 'first_solo',
        'target_date': Timestamp.fromDate(targetDate),
        'created_at': Timestamp.fromDate(createdAt),
        'completed': completed,
        if (completedAt != null)
          'completed_at': Timestamp.fromDate(completedAt!),
        'notes': notes,
      };

  /// Returns a copy with the given fields replaced.
  Goal copyWith({
    String? id,
    GoalType? goalType,
    DateTime? targetDate,
    DateTime? createdAt,
    bool? completed,
    DateTime? completedAt,
    String? notes,
  }) {
    return Goal(
      id: id ?? this.id,
      goalType: goalType ?? this.goalType,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }

  /// Human-readable goal name.
  String get displayName =>
      goalType == GoalType.firstSolo ? 'First Solo' : 'Full PPL Licence';

  /// Firestore document ID convention for each goal type.
  String get docId =>
      goalType == GoalType.firstSolo ? 'first_solo' : 'full_ppl';
}
