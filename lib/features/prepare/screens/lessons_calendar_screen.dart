// Lessons calendar screen — monthly view of all scheduled lessons.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/services/offline_lesson_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

class LessonsCalendarScreen extends ConsumerStatefulWidget {
  const LessonsCalendarScreen({super.key});

  @override
  ConsumerState<LessonsCalendarScreen> createState() =>
      _LessonsCalendarScreenState();
}

class _LessonsCalendarScreenState
    extends ConsumerState<LessonsCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Lesson> _eventsForDay(List<Lesson> lessons, DateTime day) {
    return lessons.where((l) {
      final d = l.scheduledDate;
      return d != null &&
          l.status != LessonStatus.cancelled &&
          isSameDay(d, day);
    }).toList();
  }

  String _lessonTitle(Lesson lesson) {
    if (lesson.exerciseId == 'custom') {
      return lesson.customExerciseName.isNotEmpty
          ? lesson.customExerciseName
          : 'Custom lesson';
    }
    return exerciseFullName(
      compositeExerciseId(lesson.exerciseId, lesson.subExercise.isNotEmpty ? lesson.subExercise : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(allLessonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Schedule'),
        leading: const BackButton(),
      ),
      body: lessonsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'Failed to load lessons.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        data: (allLessons) {
          final scheduled = allLessons
              .where((l) =>
                  l.scheduledDate != null &&
                  l.status != LessonStatus.cancelled)
              .toList();

          final dayLessons = _selectedDay != null
              ? _eventsForDay(scheduled, _selectedDay!)
              : _eventsForDay(scheduled, DateTime.now());

          return Column(
            children: [
              TableCalendar<Lesson>(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 730)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                },
                eventLoader: (day) => _eventsForDay(scheduled, day),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: TextStyle(color: AppColors.onSurface),
                  weekendTextStyle: TextStyle(color: AppColors.onSurface),
                  outsideTextStyle:
                      TextStyle(color: AppColors.onSurfaceVariant),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  todayTextStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.onSurface,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.onSurface,
                  ),
                  headerPadding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppColors.surface),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  weekendStyle: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: dayLessons.isEmpty
                    ? Center(
                        child: Text(
                          _selectedDay == null
                              ? 'No upcoming lessons scheduled'
                              : 'No lessons on this day',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: dayLessons.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final lesson = dayLessons[i];
                          return _LessonCard(
                            lesson: lesson,
                            title: _lessonTitle(lesson),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LessonCard extends ConsumerWidget {
  final Lesson lesson;
  final String title;

  const _LessonCard({required this.lesson, required this.title});

  Color get _statusColor {
    switch (lesson.status) {
      case LessonStatus.scheduled:
        return AppColors.statusScheduled;
      case LessonStatus.prepared:
        return AppColors.success;
      case LessonStatus.completed:
        return AppColors.success;
      case LessonStatus.cancelled:
        return AppColors.error;
      case LessonStatus.manualEntry:
        return AppColors.statusManualEntry;
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Cancel this lesson?',
          style: TextStyle(color: AppColors.onSurface, fontSize: 16),
        ),
        content: Text(
          'This will mark the lesson as cancelled.',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Cancel lesson',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    try {
      await ref
          .read(offlineLessonServiceProvider)
          .updateLesson(uid, lesson.id, {'status': 'cancelled'});
    } catch (_) {
      // Error is non-fatal; Firestore / sync handles retry.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = lesson.scheduledDate;
    final timeStr = lesson.scheduledTime.isNotEmpty
        ? lesson.scheduledTime
        : d != null
            ? DateFormat('HH:mm').format(d)
            : '';

    final isScheduled = lesson.status == LessonStatus.scheduled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lesson.status.name,
              style: TextStyle(
                color: _statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isScheduled) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
              tooltip: 'Reschedule',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                final cid = compositeExerciseId(
                  lesson.exerciseId,
                  lesson.subExercise.isNotEmpty ? lesson.subExercise : null,
                );
                context.push('/exercises/$cid/schedule');
              },
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.error,
              ),
              tooltip: 'Cancel lesson',
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmCancel(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
