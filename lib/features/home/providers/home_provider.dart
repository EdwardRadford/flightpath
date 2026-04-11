// Home screen providers — next lesson, suggested exercise, recent lessons,
// quick stats, and rating trend insights.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

// ---------------------------------------------------------------------------
// Exercise ordering
// ---------------------------------------------------------------------------

/// The canonical ordered list of exercise IDs as they appear in the CAA
/// syllabus. Exercises 10 and 18 expand into sub-exercises.
///
/// Each entry is a record of (exerciseId, subExerciseId?).
const List<({String exerciseId, String? subExerciseId})> _orderedExercises = [
  (exerciseId: 'ex_01', subExerciseId: null),
  (exerciseId: 'ex_02', subExerciseId: null),
  (exerciseId: 'ex_03', subExerciseId: null),
  (exerciseId: 'ex_04', subExerciseId: null),
  (exerciseId: 'ex_05', subExerciseId: null),
  (exerciseId: 'ex_06', subExerciseId: null),
  (exerciseId: 'ex_07', subExerciseId: null),
  (exerciseId: 'ex_08', subExerciseId: null),
  (exerciseId: 'ex_09', subExerciseId: null),
  (exerciseId: 'ex_10', subExerciseId: '10a'),
  (exerciseId: 'ex_10', subExerciseId: '10b'),
  (exerciseId: 'ex_11', subExerciseId: null),
  (exerciseId: 'ex_12', subExerciseId: null),
  (exerciseId: 'ex_13', subExerciseId: null),
  (exerciseId: 'ex_14', subExerciseId: null),
  (exerciseId: 'ex_15', subExerciseId: null),
  (exerciseId: 'ex_16', subExerciseId: null),
  (exerciseId: 'ex_17', subExerciseId: null),
  (exerciseId: 'ex_18', subExerciseId: '18a'),
  (exerciseId: 'ex_18', subExerciseId: '18b'),
  (exerciseId: 'ex_18', subExerciseId: '18c'),
  (exerciseId: 'ex_19', subExerciseId: null),
];

// ---------------------------------------------------------------------------
// Suggested exercise
// ---------------------------------------------------------------------------

/// Result type for the suggested exercise provider.
typedef SuggestedExercise = ({
  String exerciseId,
  String? subExerciseId,
  String reason,
});

/// Determines which exercise the student should work on next.
///
/// Priority order:
/// 1. Spaced-repetition due — any exercise whose [UserExercise.spacedRepDue]
///    is today or in the past. Among candidates, pick the one earliest in the
///    syllabus.
/// 2. Continuation — the lowest-numbered exercise that is [ExerciseStatus.notStarted]
///    or [ExerciseStatus.inProgress].
/// 3. Returns null if every exercise is complete.
final suggestedExerciseProvider =
    FutureProvider<SuggestedExercise?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;

  final exercisesAsync = ref.watch(userExercisesProvider);
  final exercises = exercisesAsync.valueOrNull ?? [];

  final now = DateTime.now();

  String compositeKey(String exerciseId, String? subExerciseId) =>
      subExerciseId != null ? '${exerciseId}_$subExerciseId' : exerciseId;

  final byKey = <String, UserExercise>{
    for (final ue in exercises) compositeKey(ue.exerciseId, ue.subExercise): ue,
  };

  // --- Pass 1: spaced repetition due ---
  for (final entry in _orderedExercises) {
    final key = compositeKey(entry.exerciseId, entry.subExerciseId);
    final ue = byKey[key];
    if (ue == null) continue;
    final due = ue.spacedRepDue;
    if (due != null && !due.isAfter(now)) {
      return (
        exerciseId: entry.exerciseId,
        subExerciseId: entry.subExerciseId,
        reason: 'Spaced repetition due',
      );
    }
  }

  // --- Pass 2: first notStarted or inProgress exercise ---
  for (final entry in _orderedExercises) {
    final key = compositeKey(entry.exerciseId, entry.subExerciseId);
    final ue = byKey[key];
    if (ue == null || !ue.status.isCompleted) {
      return (
        exerciseId: entry.exerciseId,
        subExerciseId: entry.subExerciseId,
        reason: 'Continue your training',
      );
    }
  }

  // All exercises complete.
  return null;
});

// ---------------------------------------------------------------------------
// Due for review
// ---------------------------------------------------------------------------

/// Data for a single exercise that is due for spaced-repetition review.
typedef DueExercise = ({
  String exerciseId,
  String? subExercise,
  String displayName,
  DateTime dueDate,
});

/// Returns all exercises with spacedRepDue <= now, sorted by due date (oldest
/// first). This list can be shown on the home screen or used to nudge the
/// student toward overdue reviews.
final dueForReviewProvider = Provider<List<DueExercise>>((ref) {
  final exercisesAsync = ref.watch(userExercisesProvider);
  final exercises = exercisesAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final due = <DueExercise>[];

  for (final ue in exercises) {
    final dueDate = ue.spacedRepDue;
    if (dueDate != null && !dueDate.isAfter(now)) {
      final compositeId = compositeExerciseId(ue.exerciseId, ue.subExercise);
      due.add((
        exerciseId: ue.exerciseId,
        subExercise: ue.subExercise,
        displayName: exerciseDisplayName(compositeId),
        dueDate: dueDate,
      ));
    }
  }

  due.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return due;
});

// ---------------------------------------------------------------------------
// Recent lessons
// ---------------------------------------------------------------------------

/// Streams the five most recent lessons for the current user, newest first.
final recentLessonsProvider = StreamProvider<List<Lesson>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.recentLessonsStream(uid, count: 5);
});

// ---------------------------------------------------------------------------
// Rating trend insight
// ---------------------------------------------------------------------------

/// The type of trend detected for a single exercise.
enum RatingTrendType {
  declining,
  stuck,
  improving,
  dueForReview,
}

/// Data for the single most relevant rating trend insight to show.
typedef RatingTrendInsight = ({
  RatingTrendType type,
  String exerciseName,
  String message,
});

/// Analyses [userExercisesProvider] and returns the single most relevant
/// rating trend insight, or null if there is nothing meaningful to surface.
///
/// Priority: declining > stuck > improving > dueForReview.
final ratingTrendInsightProvider = Provider<RatingTrendInsight?>((ref) {
  final exercisesAsync = ref.watch(userExercisesProvider);
  final exercises = exercisesAsync.valueOrNull ?? [];

  if (exercises.isEmpty) return null;

  RatingTrendInsight? bestDeclining;
  RatingTrendInsight? bestStuck;
  RatingTrendInsight? bestImproving;
  RatingTrendInsight? bestDueForReview;

  final now = DateTime.now();

  for (final ue in exercises) {
    if (ue.timesAttempted == 0) continue;

    final compositeId = compositeExerciseId(ue.exerciseId, ue.subExercise);
    final name = exerciseDisplayName(compositeId);

    final history = ue.ratingHistory;
    if (history.length >= 3) {
      final r1 = history[history.length - 3];
      final r2 = history[history.length - 2];
      final r3 = history[history.length - 1];

      if (r3 < r2 && r2 < r1) {
        bestDeclining ??= (
          type: RatingTrendType.declining,
          exerciseName: name,
          message:
              '$name needs attention — your self-ratings have dropped over the last 3 lessons.',
        );
      } else if (r3 > r2 && r2 > r1) {
        bestImproving ??= (
          type: RatingTrendType.improving,
          exerciseName: name,
          message:
              'Your $name scores have improved from $r1 to $r3 over your last 3 lessons — great progress!',
        );
      } else if (r1 == r2 && r2 == r3) {
        bestStuck ??= (
          type: RatingTrendType.stuck,
          exerciseName: name,
          message:
              "You've rated yourself $r3/5 on $name three lessons in a row — focus on the weak areas in your next brief.",
        );
      }
    }

    final due = ue.spacedRepDue;
    if (due != null && !due.isAfter(now)) {
      final daysPast = now.difference(due).inDays;
      final label = daysPast == 0
          ? 'today'
          : daysPast == 1
              ? 'yesterday'
              : '$daysPast days ago';
      bestDueForReview ??= (
        type: RatingTrendType.dueForReview,
        exerciseName: name,
        message:
            '$name was due for review $label — worth revisiting before your next lesson.',
      );
    }
  }

  return bestDeclining ?? bestStuck ?? bestImproving ?? bestDueForReview;
});

// ---------------------------------------------------------------------------
// Quick stats
// ---------------------------------------------------------------------------

/// Aggregated stats for the home screen quick stats bar.
typedef QuickStats = ({
  double hoursFlown,
  int exercisesCompleted,
  int totalExercises,
  int daysSinceLastLesson,
  int completedLessons,
});

/// Computes quick stats from lessons and user exercises.
final quickStatsProvider = Provider<QuickStats?>((ref) {
  final lessonsAsync = ref.watch(allLessonsProvider);
  final exercisesAsync = ref.watch(userExercisesProvider);

  final lessons = lessonsAsync.valueOrNull;
  final exercises = exercisesAsync.valueOrNull;

  if (lessons == null || exercises == null) return null;

  double hours = 0;
  for (final l in lessons) {
    final isCountable = l.status == LessonStatus.completed ||
        l.status == LessonStatus.manualEntry;
    final mins =
        l.flightTimeMinutes > 0 ? l.flightTimeMinutes : l.lessonDuration;
    if (isCountable && mins > 0) {
      hours += mins / 60.0;
    }
  }

  final exCompleted = exercises.where((e) => e.status.isCompleted).length;

  final completedLessons =
      lessons.where((l) => l.status == LessonStatus.completed).toList();
  int daysSince = -1;
  if (completedLessons.isNotEmpty) {
    completedLessons.sort((a, b) {
      final aDate = a.lessonDate ?? a.createdAt;
      final bDate = b.lessonDate ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    final lastDate =
        completedLessons.first.lessonDate ?? completedLessons.first.createdAt;
    daysSince = DateTime.now().difference(lastDate).inDays;
  }

  return (
    hoursFlown: hours,
    exercisesCompleted: exCompleted,
    totalExercises: _orderedExercises.length,
    daysSinceLastLesson: daysSince,
    completedLessons: completedLessons.length,
  );
});
