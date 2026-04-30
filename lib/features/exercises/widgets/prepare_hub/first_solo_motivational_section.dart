// First Solo (Exercise 14) milestone-specific blocks for the prepare hub.
//
// These render only when the exercise has [LessonType.milestone]. Design is
// kept flat and operational — no gradients, no fluff. Pilots want facts.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';

/// Short framing block at the top of the First Solo prepare hub.
///
/// Replaces the previous gradient hero card. Flat surface, single accent,
/// factual copy.
class FirstSoloMotivationalSection extends StatelessWidget {
  const FirstSoloMotivationalSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.flight_takeoff_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'First Solo',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Three circuits to a full stop. The aircraft will climb '
                  'better and float longer without the instructor on board.',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Operational reference cards shown on the First Solo prepare hub:
/// requirements, solo weather minima, and an emergency-procedures refresher.
class FirstSoloInfoCards extends StatelessWidget {
  const FirstSoloInfoCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _InfoCard(
          icon: Icons.rule_rounded,
          title: 'UK pre-solo requirements',
          lines: [
            'Minimum age 16',
            'Valid Class 2 medical (or LAPL medical)',
            'Instructor sign-off in your training record',
            'Pre-solo written test passed (Air Law + aircraft type)',
          ],
        ),
        SizedBox(height: 10),
        _InfoCard(
          icon: Icons.air_rounded,
          title: 'Solo weather minima',
          lines: [
            'Surface wind within instructor\'s solo limit (often 10–15 kt)',
            'Crosswind component below your solo limit',
            'VMC, visibility 5 km or better',
            'Cloud base above circuit altitude with margin',
          ],
        ),
        SizedBox(height: 10),
        _EmergencyRefresherCard(),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmergencyRefresherCard extends StatelessWidget {
  const _EmergencyRefresherCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.primary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Refresh emergency procedures',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'EFATO, go-around, engine failure in cruise, radio failure '
            '(squawk 7600). Run them from memory before you taxi.',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/tools/memory-drills'),
                  icon: const Icon(Icons.psychology_rounded, size: 18),
                  label: const Text('Memory drills'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/tools/emergency-drills'),
                  icon: const Icon(Icons.emergency_rounded, size: 18),
                  label: const Text('Emergency drills'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
