// Hours to Licence screen — shows progress against CAA PPL minimum requirements.
// Free feature, no paywall.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/features/progress/providers/minimums_provider.dart';

// ---------------------------------------------------------------------------
// Requirement definitions
// ---------------------------------------------------------------------------

class _Requirement {
  final String label;
  final String description;
  final double minimum;
  final double Function(PplMinimums) getValue;
  final String unit;

  const _Requirement({
    required this.label,
    required this.description,
    required this.minimum,
    required this.getValue,
    this.unit = 'hrs',
  });
}

// CAA PPL(A) minimum requirements — UK AIP / EASA FCL.210.A
const double _totalMin = 45.0;
const double _dualMin = 25.0;
const double _soloMin = 10.0;
const double _soloNavMin = 5.0;

final _requirements = [
  _Requirement(
    label: 'Total flight time',
    description: 'Total time in the air across all flights',
    minimum: _totalMin,
    getValue: (m) => m.totalHours,
    unit: 'hrs',
  ),
  _Requirement(
    label: 'Dual instruction',
    description: 'Time flown with a flight instructor',
    minimum: _dualMin,
    getValue: (m) => m.dualHours,
    unit: 'hrs',
  ),
  _Requirement(
    label: 'Supervised solo',
    description: 'Solo time flown under instructor supervision',
    minimum: _soloMin,
    getValue: (m) => m.picHours,
    unit: 'hrs',
  ),
  _Requirement(
    label: 'Solo cross-country nav',
    description: 'Solo navigation flights (Exercises 14–19)',
    minimum: _soloNavMin,
    getValue: (m) => m.soloNavHours,
    unit: 'hrs',
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Standalone screen showing CAA PPL minimum hour requirements.
/// Embedded as a tab in [ProgressScreen] — no separate route needed.
class HoursMinimumsScreen extends ConsumerWidget {
  const HoursMinimumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(allLessonsProvider);

    return lessonsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => const Center(
        child: Text(
          'Unable to load data. Please try again.',
          style: TextStyle(color: AppColors.error),
        ),
      ),
      data: (_) {
        final minimums = ref.watch(minimumsProvider);
        return _MinimumsBody(minimums: minimums);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _MinimumsBody extends StatelessWidget {
  final PplMinimums minimums;

  const _MinimumsBody({required this.minimums});

  /// Returns the additional hours still needed for a requirement (0 if met).
  double _remaining(_Requirement req) {
    final current = req.getValue(minimums);
    return (req.minimum - current).clamp(0.0, req.minimum);
  }

  /// Returns the requirement that has the most hours left to go.
  _Requirement? _mostBehind() {
    _Requirement? worst;
    double worstRemaining = 0;
    for (final req in _requirements) {
      final r = _remaining(req);
      if (r > worstRemaining) {
        worstRemaining = r;
        worst = req;
      }
    }
    return worst;
  }

  @override
  Widget build(BuildContext context) {
    final behind = _mostBehind();
    final behindHours = behind != null ? _remaining(behind) : 0.0;
    final allMet = behindHours == 0.0 && minimums.qxcCompleted;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary banner ───────────────────────────────────────────────
          _SummaryBanner(
            allMet: allMet,
            behindHours: behindHours,
            behindLabel: behind?.label,
          ),
          const SizedBox(height: 24),

          // ── Section heading ──────────────────────────────────────────────
          Text(
            'Hour requirements',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),

          // ── Requirement cards ────────────────────────────────────────────
          ..._requirements.map((req) {
            final current = req.getValue(minimums);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RequirementCard(
                label: req.label,
                description: req.description,
                current: current,
                minimum: req.minimum,
                unit: req.unit,
                showDataNote: req.label.contains('cross-country'),
              ),
            );
          }),

          // ── QXC card ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _QxcCard(completed: minimums.qxcCompleted),
          ),

          // ── Disclaimer note ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These are CAA minimum requirements. Your school may require more hours before signing you off.',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
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

// ---------------------------------------------------------------------------
// Summary banner
// ---------------------------------------------------------------------------

class _SummaryBanner extends StatelessWidget {
  final bool allMet;
  final double behindHours;
  final String? behindLabel;

  const _SummaryBanner({
    required this.allMet,
    required this.behindHours,
    this.behindLabel,
  });

  @override
  Widget build(BuildContext context) {
    final String message;
    final Color accent;
    final IconData icon;

    if (allMet) {
      message = 'You have met all CAA minimum hour requirements.';
      accent = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (behindHours == 0.0) {
      message = 'Hour requirements met. Complete your qualifying cross-country to finish.';
      accent = AppColors.warning;
      icon = Icons.radio_button_unchecked_rounded;
    } else {
      message =
          '${behindHours.toStringAsFixed(1)} more hours needed (${behindLabel ?? 'see below'}).';
      accent = AppColors.primary;
      icon = Icons.flight_takeoff_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requirement card
// ---------------------------------------------------------------------------

enum _Status { notStarted, inProgress, met }

class _RequirementCard extends StatelessWidget {
  final String label;
  final String description;
  final double current;
  final double minimum;
  final String unit;
  final bool showDataNote;

  const _RequirementCard({
    required this.label,
    required this.description,
    required this.current,
    required this.minimum,
    required this.unit,
    this.showDataNote = false,
  });

  _Status get _status {
    if (current <= 0) return _Status.notStarted;
    if (current >= minimum) return _Status.met;
    return _Status.inProgress;
  }

  Color _statusColor(_Status s) {
    switch (s) {
      case _Status.met:
        return AppColors.success;
      case _Status.inProgress:
        return AppColors.warning;
      case _Status.notStarted:
        return AppColors.onSurfaceVariant;
    }
  }

  String _statusLabel(_Status s) {
    switch (s) {
      case _Status.met:
        return 'MET';
      case _Status.inProgress:
        return 'IN PROGRESS';
      case _Status.notStarted:
        return 'NOT STARTED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final statusColor = _statusColor(status);
    final progress = (current / minimum).clamp(0.0, 1.0);
    final remaining = (minimum - current).clamp(0.0, minimum);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),

          // Hours label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${current.toStringAsFixed(1)} $unit / ${minimum.toStringAsFixed(0)} $unit',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status != _Status.met)
                Text(
                  '${remaining.toStringAsFixed(1)} to go',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),

          // Data note for fields we can't compute precisely
          if (showDataNote) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Estimated from PIC time on exercises 14–19. '
                    'Track your solo nav hours by marking lessons appropriately in your logbook.',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QXC card
// ---------------------------------------------------------------------------

class _QxcCard extends StatelessWidget {
  final bool completed;

  const _QxcCard({required this.completed});

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        completed ? AppColors.success : AppColors.onSurfaceVariant;
    final String statusLabel = completed ? 'COMPLETED' : 'NOT YET DONE';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completed
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qualifying cross-country (QXC)',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '150 nm minimum, 3 legs, 2 full-stop landings',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (!completed) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Mark a lesson as QXC in your logbook when you complete your qualifying cross-country.',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
