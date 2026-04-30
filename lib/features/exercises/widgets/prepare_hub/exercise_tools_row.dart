// Horizontal scrollable row of tool chips shown in the prepare hub.
// Which tools appear depends on the exercise number.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/widgets/exercise_list/flight_path_body.dart'
    show exerciseNumber;

class ExerciseToolsRow extends StatelessWidget {
  final String exerciseId;
  final bool isPremium;

  const ExerciseToolsRow({
    super.key,
    required this.exerciseId,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final exNum = exerciseNumber(exerciseId);
    // ATIS and RT Practice only become relevant once radio work begins (ex 5+).
    final showRadioTools = exNum >= 5;

    final chips = <_ToolChip>[
      _ToolChip(
        icon: Icons.wb_cloudy_rounded,
        label: 'Weather',
        route: '/tools/weather',
        locked: false,
      ),
      if (showRadioTools)
        _ToolChip(
          icon: Icons.headset_mic_rounded,
          label: 'ATIS',
          route: '/learn/atis',
          locked: !isPremium,
        ),
      if (showRadioTools)
        _ToolChip(
          icon: Icons.radio_rounded,
          label: 'RT Practice',
          route: '/learn/rt-practice',
          locked: !isPremium,
        ),
      _ToolChip(
        icon: Icons.menu_book_rounded,
        label: 'Memory Drills',
        route: '/tools/memory-drills',
        locked: false,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map((chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ToolChipWidget(chip: chip),
                ))
            .toList(),
      ),
    );
  }
}

// ── Data class ───────────────────────────────────────────────────────────────

class _ToolChip {
  final IconData icon;
  final String label;
  final String route;
  final bool locked;

  const _ToolChip({
    required this.icon,
    required this.label,
    required this.route,
    required this.locked,
  });
}

// ── Chip widget ──────────────────────────────────────────────────────────────

class _ToolChipWidget extends StatelessWidget {
  final _ToolChip chip;

  const _ToolChipWidget({required this.chip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: chip.locked ? null : () => context.push(chip.route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chip.locked
              ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: chip.locked
                ? cs.outline.withValues(alpha: 0.5)
                : AppColors.primary.withValues(alpha: 0.30),
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chip.locked ? Icons.lock_rounded : chip.icon,
              size: 14,
              color: chip.locked
                  ? cs.onSurface.withValues(alpha: 0.35)
                  : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              chip.label,
              style: TextStyle(
                color: chip.locked
                    ? cs.onSurface.withValues(alpha: 0.35)
                    : AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
