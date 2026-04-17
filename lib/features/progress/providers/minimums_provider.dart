// CAA PPL minimum hours provider — derives all five minimums from the
// existing lessons stream. No new Firestore queries.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

/// Aggregated values used by the Hours to Licence screen.
class PplMinimums {
  /// Sum of flightTimeMinutes (all non-cancelled lessons), in decimal hours.
  final double totalHours;

  /// Sum of dualTimeMinutes (all non-cancelled lessons), in decimal hours.
  final double dualHours;

  /// Sum of picTimeMinutes (all non-cancelled lessons), in decimal hours.
  final double picHours;

  /// Sum of picTimeMinutes where the lesson falls within the solo/nav exercise
  /// range (ex_14 – ex_19 family), in decimal hours.
  ///
  /// NOTE: The Lesson model has no dedicated `isNavExercise` or `isSoloNav`
  /// flag. This figure is the best approximation from existing data and may
  /// under-count if nav exercises are logged under earlier exercise IDs or
  /// as custom entries. Users are shown an explanatory note on screen.
  final double soloNavHours;

  /// True when at least one lesson has [Lesson.isQxc] set to true.
  final bool qxcCompleted;

  const PplMinimums({
    required this.totalHours,
    required this.dualHours,
    required this.picHours,
    required this.soloNavHours,
    required this.qxcCompleted,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// CAA PPL exercise IDs that count as navigation / solo cross-country work.
/// Exercises 14–19 in the UK PPL syllabus cover First Solo, Consolidation,
/// Advanced Turning, Navigation (ex_16, ex_17, ex_18 variants), and Solo
/// Cross-Country (ex_19).
const _navExerciseIds = {
  'ex_14',
  'ex_15',
  'ex_16',
  'ex_17',
  'ex_18',
  'ex_18_18a',
  'ex_18_18b',
  'ex_18_18c',
  'ex_19',
};

/// Computes [PplMinimums] from the existing [allLessonsProvider] stream.
/// Skips cancelled lessons and uses the proper logbook minute fields.
final minimumsProvider = Provider<PplMinimums>((ref) {
  final lessonsAsync = ref.watch(allLessonsProvider);
  final lessons = lessonsAsync.valueOrNull ?? [];

  double totalHours = 0;
  double dualHours = 0;
  double picHours = 0;
  double soloNavHours = 0;

  for (final lesson in lessons) {
    if (lesson.status == LessonStatus.cancelled) continue;

    // Use the dedicated logbook minute fields, falling back to lessonDuration
    // for legacy entries that pre-date the field split.
    final flightMinutes = lesson.flightTimeMinutes > 0
        ? lesson.flightTimeMinutes
        : lesson.lessonDuration;

    totalHours += flightMinutes / 60.0;
    dualHours += lesson.dualTimeMinutes / 60.0;
    picHours += lesson.picTimeMinutes / 60.0;

    // Solo nav: PIC time on nav/solo exercises, or any PIC time where the
    // additional exercise IDs include a nav exercise.
    if (lesson.picTimeMinutes > 0) {
      final inNavExercise = _navExerciseIds.contains(lesson.exerciseId) ||
          lesson.additionalExerciseIds.any(_navExerciseIds.contains);
      if (inNavExercise) {
        soloNavHours += lesson.picTimeMinutes / 60.0;
      }
    }
  }

  // QXC: true as soon as any lesson is explicitly marked as qualifying
  // cross-country via the isQxc flag.
  final qxcCompleted = lessons.any((l) => l.isQxc);

  return PplMinimums(
    totalHours: totalHours,
    dualHours: dualHours,
    picHours: picHours,
    soloNavHours: soloNavHours,
    qxcCompleted: qxcCompleted,
  );
});
