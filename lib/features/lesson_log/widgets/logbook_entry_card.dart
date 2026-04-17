import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers (file-private)
// ---------------------------------------------------------------------------

String _exerciseDisplayNameForLesson(Lesson lesson) {
  final key = compositeExerciseId(lesson.exerciseId, lesson.subExercise);
  return exerciseLongName(key);
}

String _formatMinutesAsHours(int minutes) {
  final hrs = minutes ~/ 60;
  final mins = minutes % 60;
  return '${hrs}h ${mins.toString().padLeft(2, '0')}m';
}

String _routeString(Lesson lesson) {
  final dep = lesson.departureAirfield;
  final arr = lesson.arrivalAirfield;
  if (dep.isEmpty && arr.isEmpty) return '';
  if (dep == arr || arr.isEmpty) return dep;
  if (dep.isEmpty) return arr;
  return '$dep \u2192 $arr';
}

// ---------------------------------------------------------------------------
// Logbook entry card
// ---------------------------------------------------------------------------

class LogbookEntryCard extends StatelessWidget {
  final Lesson lesson;

  const LogbookEntryCard({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final date = lesson.lessonDate ?? lesson.createdAt;
    final dateStr = DateFormat('EEE, d MMM yyyy').format(date);
    final reg = lesson.aircraftRegistration;
    final route = _routeString(lesson);
    final flightTime = lesson.flightTimeMinutes > 0
        ? lesson.flightTimeMinutes
        : lesson.lessonDuration;
    final exerciseName = _exerciseDisplayNameForLesson(lesson);

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: date + day/night badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lesson.isDayFlight
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lesson.isDayFlight ? 'Day' : 'Night',
                    style: TextStyle(
                      color: lesson.isDayFlight
                          ? AppColors.warning
                          : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Registration + route row
            Row(
              children: [
                if (reg.isNotEmpty) ...[
                  const Icon(Icons.airplanemode_active,
                      color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    reg,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                if (route.isNotEmpty) ...[
                  Icon(Icons.navigation_outlined,
                      color: AppColors.onSurfaceVariant, size: 13),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route,
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Flight time + landings + exercise
            Row(
              children: [
                if (flightTime > 0) ...[
                  Icon(Icons.access_time_rounded,
                      color: AppColors.onSurfaceVariant, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    _formatMinutesAsHours(flightTime),
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                if (lesson.landings > 0) ...[
                  Icon(Icons.flight_land_outlined,
                      color: AppColors.onSurfaceVariant, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${lesson.landings} ldg',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Exercise name
            Text(
              exerciseName,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => LogbookDetailSheet(lesson: lesson),
    );
  }
}

// ---------------------------------------------------------------------------
// Logbook detail bottom sheet
// ---------------------------------------------------------------------------

class LogbookDetailSheet extends StatefulWidget {
  final Lesson lesson;

  const LogbookDetailSheet({super.key, required this.lesson});

  @override
  State<LogbookDetailSheet> createState() => _LogbookDetailSheetState();
}

class _LogbookDetailSheetState extends State<LogbookDetailSheet> {
  bool _showLessonDetail = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final date = lesson.lessonDate ?? lesson.createdAt;
    final exerciseName = _exerciseDisplayNameForLesson(lesson);
    final route = _routeString(lesson);
    final flightTime = lesson.flightTimeMinutes > 0
        ? lesson.flightTimeMinutes
        : lesson.lessonDuration;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d MMMM yyyy').format(date),
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lesson.isDayFlight
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lesson.isDayFlight ? 'Day' : 'Night',
                    style: TextStyle(
                      color: lesson.isDayFlight
                          ? AppColors.warning
                          : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              exerciseName,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // Logbook details grid
            LogbookDetailRow(
              label: 'Aircraft',
              value: lesson.aircraftRegistration.isNotEmpty
                  ? lesson.aircraftRegistration
                  : '—',
            ),
            LogbookDetailRow(
              label: 'Aircraft Type',
              value: _aircraftTypeLabel(lesson.aircraftType),
            ),
            if (route.isNotEmpty)
              LogbookDetailRow(label: 'Route', value: route),
            if (flightTime > 0)
              LogbookDetailRow(
                  label: 'Flight Time',
                  value: _formatMinutesAsHours(flightTime)),
            if (lesson.dualTimeMinutes > 0)
              LogbookDetailRow(
                  label: 'Dual Time',
                  value: _formatMinutesAsHours(lesson.dualTimeMinutes)),
            if (lesson.picTimeMinutes > 0)
              LogbookDetailRow(
                  label: 'PIC Time',
                  value: _formatMinutesAsHours(lesson.picTimeMinutes)),
            if (lesson.landings > 0)
              LogbookDetailRow(
                  label: 'Landings', value: '${lesson.landings}'),
            if (lesson.instructorName.isNotEmpty)
              LogbookDetailRow(
                  label: 'Instructor', value: lesson.instructorName),
            if (lesson.remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Remarks',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lesson.remarks,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],

            // Expandable lesson detail (ratings, quiz, AI debrief)
            if (_hasLessonDetail(lesson)) ...[
              const SizedBox(height: 20),
              Divider(color: AppColors.divider),
              GestureDetector(
                onTap: () =>
                    setState(() => _showLessonDetail = !_showLessonDetail),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lesson Details',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _showLessonDetail
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showLessonDetail) LogbookLessonDetailSection(lesson: lesson),
            ],

            // View full detail button
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/lesson-detail', extra: lesson);
                },
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                label: const Text('View Full Detail'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _hasLessonDetail(Lesson lesson) {
    return lesson.studentRating != null ||
        lesson.instructorRating != null ||
        lesson.quizScore > 0 ||
        lesson.aiDebriefWell.isNotEmpty ||
        lesson.instructorNotes.isNotEmpty ||
        lesson.personalReflection.isNotEmpty;
  }

  String _aircraftTypeLabel(String? type) {
    switch (type) {
      case 'cessna_152':
        return 'Cessna 152';
      case 'cessna_172':
        return 'Cessna 172';
      case 'pa28':
        return 'Piper PA-28';
      case 'da40':
        return 'Diamond DA40';
      default:
        return type ?? '—';
    }
  }
}

// ---------------------------------------------------------------------------
// Detail row
// ---------------------------------------------------------------------------

class LogbookDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const LogbookDetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable lesson detail section
// ---------------------------------------------------------------------------

class LogbookLessonDetailSection extends StatelessWidget {
  final Lesson lesson;

  const LogbookLessonDetailSection({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ratings row
        if (lesson.studentRating != null || lesson.instructorRating != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                if (lesson.studentRating != null)
                  _MiniStat(
                    icon: Icons.star_rounded,
                    label: 'Self',
                    value: '${lesson.studentRating}/5',
                  ),
                if (lesson.studentRating != null) const SizedBox(width: 12),
                if (lesson.instructorRating != null)
                  _MiniStat(
                    icon: Icons.person_rounded,
                    label: 'Instructor',
                    value: '${lesson.instructorRating}/5',
                  ),
                if (lesson.quizScore > 0) ...[
                  const SizedBox(width: 12),
                  _MiniStat(
                    icon: Icons.quiz_outlined,
                    label: 'Quiz',
                    value: '${lesson.quizScore}%',
                  ),
                ],
              ],
            ),
          ),

        // Instructor notes
        if (lesson.instructorNotes.isNotEmpty) ...[
          Text(
            "Instructor's Comments",
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lesson.instructorNotes,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Personal reflection
        if (lesson.personalReflection.isNotEmpty) ...[
          Text(
            'Personal Reflection',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lesson.personalReflection,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // AI Debrief
        if (lesson.aiDebriefWell.isNotEmpty ||
            lesson.aiDebriefImprove.isNotEmpty ||
            lesson.aiDebriefFocus.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
              const SizedBox(width: 6),
              Text(
                'AI Debrief',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lesson.aiDebriefWell.isNotEmpty)
            _AiField(
              label: 'What Went Well',
              content: lesson.aiDebriefWell,
              color: AppColors.success,
            ),
          if (lesson.aiDebriefImprove.isNotEmpty)
            _AiField(
              label: 'What to Improve',
              content: lesson.aiDebriefImprove,
              color: AppColors.warning,
            ),
          if (lesson.aiDebriefFocus.isNotEmpty)
            _AiField(
              label: 'Focus Next Lesson',
              content: lesson.aiDebriefFocus,
              color: AppColors.primary,
            ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiField extends StatelessWidget {
  final String label;
  final String content;
  final Color color;

  const _AiField({
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
