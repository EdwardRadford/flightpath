// Goals providers — Firestore CRUD for the users/{uid}/goals sub-collection.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/shared/models/goal.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';

final _db = FirebaseFirestore.instance;

// ---------------------------------------------------------------------------
// Stream provider — watches all goals for the current user
// ---------------------------------------------------------------------------

/// Streams the current user's goals from the `users/{uid}/goals` sub-collection.
final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  return _db
      .collection('users')
      .doc(uid)
      .collection('goals')
      .orderBy('created_at')
      .snapshots()
      .map((qs) => qs.docs.map((doc) => Goal.fromFirestore(doc)).toList());
});

// ---------------------------------------------------------------------------
// Service functions
// ---------------------------------------------------------------------------

/// Saves or creates a goal. Uses the goal type as the document ID so there
/// can only be one goal per type.
Future<void> saveGoal({
  required String userId,
  required GoalType goalType,
  required DateTime targetDate,
  String notes = '',
}) async {
  final sanitisedNotes = InputSanitiser.sanitise(
    notes,
    maxLength: InputSanitiser.maxMedium,
  );

  final docId = goalType == GoalType.firstSolo ? 'first_solo' : 'full_ppl';
  final goal = Goal(
    id: docId,
    goalType: goalType,
    targetDate: targetDate,
    createdAt: DateTime.now(),
    completed: false,
    notes: sanitisedNotes,
  );

  await _db
      .collection('users')
      .doc(userId)
      .collection('goals')
      .doc(docId)
      .set(goal.toFirestore(), SetOptions(merge: true));
}

/// Updates an existing goal's target date and/or notes.
Future<void> updateGoal({
  required String userId,
  required String goalDocId,
  DateTime? targetDate,
  String? notes,
}) async {
  final updates = <String, dynamic>{};
  if (targetDate != null) {
    updates['target_date'] = Timestamp.fromDate(targetDate);
  }
  if (notes != null) {
    updates['notes'] = InputSanitiser.sanitise(
      notes,
      maxLength: InputSanitiser.maxMedium,
    );
  }
  if (updates.isEmpty) return;

  await _db
      .collection('users')
      .doc(userId)
      .collection('goals')
      .doc(goalDocId)
      .update(updates);
}

/// Marks a goal as completed.
Future<void> completeGoal({
  required String userId,
  required String goalDocId,
}) async {
  await _db
      .collection('users')
      .doc(userId)
      .collection('goals')
      .doc(goalDocId)
      .update({
    'completed': true,
    'completed_at': FieldValue.serverTimestamp(),
  });
}
