// Logbook feature providers — sort mode and running totals.
// allLessonsProvider and lessonsByExerciseProvider live in lesson_provider.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';

export 'package:flight_path/features/lesson_log/providers/lesson_provider.dart'
    show allLessonsProvider, lessonsByExerciseProvider;

// ---------------------------------------------------------------------------
// Sort mode
// ---------------------------------------------------------------------------

enum LogbookSort { newestFirst, oldestFirst, byExercise }

/// Controls the current sort order in the logbook screen.
final logbookSortProvider = StateProvider<LogbookSort>(
  (ref) => LogbookSort.newestFirst,
);

// ---------------------------------------------------------------------------
// Running totals
// ---------------------------------------------------------------------------

/// Aggregate logbook statistics derived from a list of lessons.
class LogbookTotals {
  final int totalMinutes;
  final int dualMinutes;
  final int picMinutes;
  final int totalLandings;
  final int entryCount;

  const LogbookTotals({
    this.totalMinutes = 0,
    this.dualMinutes = 0,
    this.picMinutes = 0,
    this.totalLandings = 0,
    this.entryCount = 0,
  });

  factory LogbookTotals.fromLessons(List<Lesson> lessons) {
    int total = 0, dual = 0, pic = 0, landings = 0;
    for (final l in lessons) {
      if (l.status == LessonStatus.cancelled) continue;
      total += l.flightTimeMinutes > 0
          ? l.flightTimeMinutes
          : l.lessonDuration;
      dual += l.dualTimeMinutes;
      pic += l.picTimeMinutes;
      landings += l.landings;
    }
    return LogbookTotals(
      totalMinutes: total,
      dualMinutes: dual,
      picMinutes: pic,
      totalLandings: landings,
      entryCount:
          lessons.where((l) => l.status != LessonStatus.cancelled).length,
    );
  }

  String get totalHoursFormatted => _fmt(totalMinutes);
  String get dualHoursFormatted => _fmt(dualMinutes);
  String get picHoursFormatted => _fmt(picMinutes);

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }
}

/// Computes running totals from the full lessons stream.
final logbookTotalsProvider = Provider<LogbookTotals>((ref) {
  final lessonsAsync = ref.watch(allLessonsProvider);
  final lessons = lessonsAsync.valueOrNull ?? [];
  return LogbookTotals.fromLessons(
    lessons.where((l) => l.status != LessonStatus.cancelled).toList(),
  );
});
