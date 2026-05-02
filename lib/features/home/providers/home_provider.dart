// Home screen providers — next lesson, suggested exercise, recent lessons,
// quick stats, and rating trend insights.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/exercises/providers/syllabus_progress_provider.dart';
import 'package:flight_path/features/exercises/widgets/exercise_list/flight_path_body.dart'
    show kExercises;
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

  // --- Pass 2: the exercise AFTER the highest completed one ---
  // Defer the parent-level "what's current" calculation to syllabusProgress
  // so the home screen, exercise list, and progress screen all agree. Then
  // map that parent index onto the flat _orderedExercises list (which
  // expands sub-exercises) by picking the first not-yet-completed entry for
  // the current parent.
  final progress = ref.watch(syllabusProgressProvider);
  final currentParent = kExercises[progress.currentIndex];

  // If the parent has no sub-exercises, the flat-list entry is just the
  // parent itself.
  if (!currentParent.hasSubExercises) {
    // Edge case: every exercise completed — currentIndex clamps to last, but
    // that exercise is itself complete, so suppress the suggestion.
    final ue = byKey[currentParent.exerciseId];
    if (ue != null && ue.status.isCompleted) return null;
    return (
      exerciseId: currentParent.exerciseId,
      subExerciseId: null,
      reason: 'Continue your training',
    );
  }

  // Parent with sub-exercises: walk the flat list for the first sub of this
  // parent that isn't completed yet.
  for (final entry in _orderedExercises) {
    if (entry.exerciseId != currentParent.exerciseId) continue;
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

  // All subs of the current parent are complete (rare timing window) — no
  // suggestion.
  return null;
});

// ---------------------------------------------------------------------------
// Skills test readiness
// ---------------------------------------------------------------------------

/// Full breakdown of skills test readiness.
///
/// - [score] overall readiness 0.0–1.0
/// - [ready] exercises with bestRating >= 4 (green)
/// - [inProgress] exercises with bestRating 1–3 (amber)
/// - [notStarted] exercises with no bestRating (grey)
/// - [total] total exercises in the syllabus (22)
typedef SkillsReadinessData = ({
  double score,
  int ready,
  int inProgress,
  int notStarted,
  int total,
});

/// Returns [SkillsReadinessData] or null while data is loading.
final skillsReadinessDataProvider = Provider<SkillsReadinessData?>((ref) {
  final exercisesAsync = ref.watch(userExercisesProvider);
  final exercises = exercisesAsync.valueOrNull;
  if (exercises == null) return null;

  final total = _orderedExercises.length;

  final byKey = <String, UserExercise>{};
  for (final ue in exercises) {
    final key = ue.subExercise != null
        ? '${ue.exerciseId}_${ue.subExercise}'
        : ue.exerciseId;
    byKey[key] = ue;
  }

  int ready = 0;
  int inProgress = 0;
  int notStarted = 0;

  for (final entry in _orderedExercises) {
    final key = entry.subExerciseId != null
        ? '${entry.exerciseId}_${entry.subExerciseId}'
        : entry.exerciseId;
    final rating = byKey[key]?.bestRating;
    if (rating == null) {
      notStarted++;
    } else if (rating >= 4) {
      ready++;
    } else {
      inProgress++;
    }
  }

  return (
    score: ready / total,
    ready: ready,
    inProgress: inProgress,
    notStarted: notStarted,
    total: total,
  );
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
// Quick stats
// ---------------------------------------------------------------------------

/// Aggregated stats for the home screen quick stats bar.
typedef QuickStats = ({
  double hoursFlown,
  int exercisesCompleted,
  int totalExercises,
  int lessonsLogged,
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

  return (
    hoursFlown: hours,
    exercisesCompleted: exCompleted,
    totalExercises: _orderedExercises.length,
    lessonsLogged: lessons.length,
  );
});
