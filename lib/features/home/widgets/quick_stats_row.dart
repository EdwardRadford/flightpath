// Home > Quick stats row (hours flown / exercises / last lesson).
// Extracted from home_screen.dart during 2026-04-13 refactor.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/home/providers/home_provider.dart';

String _formatHoursMinutes(double hours) {
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h}h ${m}m';
}

class QuickStatsRow extends StatelessWidget {
  final QuickStats stats;
  const QuickStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              label: 'Flown',
              value: _formatHoursMinutes(stats.hoursFlown),
              icon: Icons.flight_rounded,
              iconColor: AppColors.statHours,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Exercises',
              value: '${stats.exercisesCompleted}/22',
              icon: Icons.menu_book_outlined,
              iconColor: AppColors.statExercises,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Lessons',
              value: '${stats.lessonsLogged}',
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(height: 8),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
