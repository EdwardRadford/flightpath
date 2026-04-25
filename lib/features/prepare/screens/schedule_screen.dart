// Schedule screen — date/time picker for scheduling a lesson with notifications.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/shared/services/notification_service.dart';
import 'package:flight_path/shared/services/offline_lesson_service.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Lesson scheduling form with date/time pickers and evening-before reminders.
class ScheduleScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const ScheduleScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  DateTime? get _combinedDateTime {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    final combined = _combinedDateTime;
    if (combined == null) return;

    // Prevent scheduling in the past
    if (combined.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time in the future.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    setState(() => _saving = true);

    try {
      final offlineLessons = ref.read(offlineLessonServiceProvider);

      final lesson = Lesson(
        id: '',
        exerciseId: exerciseId,
        subExercise: subExerciseId ?? '',
        scheduledDate: combined,
        scheduledTime: _selectedTime!.format(context),
        status: LessonStatus.scheduled,
        createdAt: DateTime.now(),
        quizAttempts: 0,
      );

      final lessonId = await offlineLessons.createLesson(uid, lesson);

      // Schedule a check-in notification ~90 mins after the lesson
      final exerciseName = exerciseFullName(widget.compositeExerciseId);
      await NotificationService.scheduleCheckinNotification(
        id: lessonId.hashCode.abs(),
        exerciseName: exerciseName,
        lessonTime: combined,
      );

      // Schedule a reminder at 7pm Europe/London the evening before the lesson.
      await NotificationService.scheduleEveningReminder(
        widget.compositeExerciseId,
        combined,
        exerciseName,
      );

      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_scheduled',
        parameters: {'exercise_id': widget.compositeExerciseId},
      );

      if (!mounted) return;

      // Show SnackBar and navigate back
      final formattedDate =
          DateFormat('EEE d MMM yyyy \'at\' HH:mm').format(combined);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lesson scheduled for $formattedDate'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to schedule lesson. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave =
        _selectedDate != null && _selectedTime != null && !_saving;

    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Schedule Lesson'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'View all scheduled lessons',
            onPressed: () => context.push('/schedule/calendar'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Intro text
             Text(
              'Pick a date and time for your next lesson. You can update this later.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Date picker card
            _PickerCard(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: _selectedDate != null
                  ? DateFormat('EEEE, d MMMM yyyy').format(_selectedDate!)
                  : null,
              placeholder: 'Select a date',
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),

            // Time picker card
            _PickerCard(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: _selectedTime?.format(context),
              placeholder: 'Select a time',
              onTap: _pickTime,
            ),
            const SizedBox(height: 12),

            // Selected summary
            if (_combinedDateTime != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('EEE d MMM yyyy \'at\' HH:mm')
                            .format(_combinedDateTime!),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Optional notes field
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: InputSanitiser.maxShort,
                style:  TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Notes (optional) — e.g. "Flying with John today"',
                  hintStyle:  TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Schedule button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.surfaceVariant,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Schedule Lesson',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picker card widget
// ---------------------------------------------------------------------------

class _PickerCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const _PickerCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.divider,
            width: hasValue ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: hasValue ? AppColors.primary : AppColors.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style:  TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? placeholder,
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight:
                          hasValue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
