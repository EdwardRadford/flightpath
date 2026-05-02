// Single source of truth for syllabus walk computations — current exercise
// index, completed count, and free-window membership. Replaces three parallel
// implementations in home_provider.dart, flight_path_body.dart, and
// progress_screen.dart that independently walked `kExercises`.
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/exercises/widgets/exercise_list/flight_path_body.dart'
    show
        kExercises,
        aggregateStatus,
        findExerciseInList,
        nodeStatus,
        NodeStatus;
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

/// Snapshot of the user's position in the syllabus.
///
/// All fields are derived from the streaming providers it depends on
/// ([userExercisesProvider] for completion state, [appUserProvider] for the
/// persisted `currentExerciseNumber` field that drives the free window).
class SyllabusProgress {
  /// Index in `kExercises` of the user's current position. Equals the highest
  /// completed exercise + 1, clamped to `kExercises.length - 1`. Returns 0 if
  /// nothing is completed yet.
  final int currentIndex;

  /// Count of fully-completed parent exercises. Parents with sub-exercises
  /// only count as complete when *all* their children are complete or
  /// mastered.
  final int completedCount;

  /// First exercise number (1-based) inside the free window — `currentExerciseNumber - 2`,
  /// clamped to `>= 1`.
  final int freeWindowStart;

  /// Last exercise number (1-based) inside the free window — `currentExerciseNumber + 2`,
  /// clamped to `<= 19`.
  final int freeWindowEnd;

  const SyllabusProgress({
    required this.currentIndex,
    required this.completedCount,
    required this.freeWindowStart,
    required this.freeWindowEnd,
  });

  /// Alias for [currentIndex]. Provided for symmetry — post-2026-04-30 the
  /// "next incomplete" and "current" semantics are identical (both refer to
  /// the exercise after the highest completed one).
  int get nextIncompleteIndex => currentIndex;

  /// Returns true if the parent exercise at `kExercises[exerciseIndex]` falls
  /// within the user's free window (inclusive on both ends).
  bool isInFreeWindow(int exerciseIndex) {
    if (exerciseIndex < 0 || exerciseIndex >= kExercises.length) return false;
    final number = exerciseIndex + 1;
    return number >= freeWindowStart && number <= freeWindowEnd;
  }
}

/// Computes [SyllabusProgress] from the live exercise stream and the persisted
/// `currentExerciseNumber` on the user profile.
///
/// Returns a default snapshot (currentIndex 0, no completion, free window 1-3)
/// while either dependency is still loading. This keeps consumers simple —
/// they always get a value back, never an `AsyncValue` to unwrap.
final syllabusProgressProvider = Provider<SyllabusProgress>((ref) {
  final userExercises =
      ref.watch(userExercisesProvider).valueOrNull ?? const <UserExercise>[];
  final appUser = ref.watch(appUserProvider).valueOrNull;
  final currentExerciseNumber = appUser?.currentExerciseNumber ?? 1;

  int highestDone = -1;
  int completed = 0;
  for (int i = 0; i < kExercises.length; i++) {
    final item = kExercises[i];
    final status = item.hasSubExercises
        ? aggregateStatus(userExercises, item.exerciseId, item.subExercises)
        : nodeStatus(findExerciseInList(userExercises, item.exerciseId));
    if (status == NodeStatus.completed || status == NodeStatus.mastered) {
      highestDone = i;
      completed++;
    }
  }

  int currentIndex;
  if (highestDone < 0) {
    currentIndex = 0;
  } else {
    final next = highestDone + 1;
    currentIndex = next >= kExercises.length ? kExercises.length - 1 : next;
  }

  return SyllabusProgress(
    currentIndex: currentIndex,
    completedCount: completed,
    freeWindowStart: math.max(1, currentExerciseNumber - 2),
    freeWindowEnd: math.min(19, currentExerciseNumber + 2),
  );
});
