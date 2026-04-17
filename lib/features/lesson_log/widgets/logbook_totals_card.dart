import 'package:flutter/material.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/lesson.dart';

// ---------------------------------------------------------------------------
// Running totals model
// ---------------------------------------------------------------------------

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
      total += l.flightTimeMinutes > 0 ? l.flightTimeMinutes : l.lessonDuration;
      dual += l.dualTimeMinutes;
      pic += l.picTimeMinutes;
      landings += l.landings;
    }
    return LogbookTotals(
      totalMinutes: total,
      dualMinutes: dual,
      picMinutes: pic,
      totalLandings: landings,
      entryCount: lessons.where((l) => l.status != LessonStatus.cancelled).length,
    );
  }
}

// ---------------------------------------------------------------------------
// Totals card
// ---------------------------------------------------------------------------

String _formatMinutesAsHours(int minutes) {
  final hrs = minutes ~/ 60;
  final mins = minutes % 60;
  return '${hrs}h ${mins.toString().padLeft(2, '0')}m';
}

class LogbookTotalsCard extends StatelessWidget {
  final LogbookTotals totals;

  const LogbookTotalsCard({super.key, required this.totals});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _TotalItem(
              label: 'Total',
              value: _formatMinutesAsHours(totals.totalMinutes),
              icon: Icons.flight_rounded,
            ),
            _TotalItem(
              label: 'Dual',
              value: _formatMinutesAsHours(totals.dualMinutes),
              icon: Icons.people_outline,
            ),
            _TotalItem(
              label: 'PIC',
              value: _formatMinutesAsHours(totals.picMinutes),
              icon: Icons.person_outline,
            ),
            _TotalItem(
              label: 'Landings',
              value: '${totals.totalLandings}',
              icon: Icons.flight_land_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TotalItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
