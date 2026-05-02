// PLOG route calculator screen — reached from the weather screen header button.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/tools/utils/plog_calculator.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PlogScreen extends ConsumerStatefulWidget {
  const PlogScreen({super.key});

  @override
  ConsumerState<PlogScreen> createState() => _PlogScreenState();
}

class _PlogScreenState extends ConsumerState<PlogScreen> {
  static const int _maxLegs = 6;

  final List<_LegState> _legs = [_LegState(index: 0)];

  void _addLeg() {
    if (_legs.length >= _maxLegs) return;
    final prev = _legs.last;
    setState(() {
      _legs.add(_LegState(
        index: _legs.length,
        initialTas: prev.tasController.text,
        initialWindFrom: prev.windFromController.text,
        initialWindSpeed: prev.windSpeedController.text,
      ));
    });
  }

  void _resetAll() {
    for (final leg in _legs) {
      leg.dispose();
    }
    setState(() {
      _legs
        ..clear()
        ..add(_LegState(index: 0));
    });
  }

  // Summary values across all legs that have valid results.
  ({double totalDist, double totalEta, double avgGs})? _summary() {
    double totalDist = 0;
    double totalEta = 0;
    int validLegs = 0;

    for (final leg in _legs) {
      final dist = double.tryParse(leg.distanceController.text);
      final result = leg.result;
      if (dist != null && result != null) {
        totalDist += dist;
        totalEta += result.etaMinutes;
        validLegs++;
      }
    }

    if (validLegs == 0) return null;
    final avgGs = (totalDist > 0 && totalEta > 0) ? (totalDist / totalEta) * 60.0 : 0.0;
    return (totalDist: totalDist, totalEta: totalEta, avgGs: avgGs);
  }

  @override
  void dispose() {
    for (final leg in _legs) {
      leg.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider).valueOrNull ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final summary = _summary();

    if (!isPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Route Planner (PLOG)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.pageHorizontal,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Route Planner',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Plan your cross-country with automatic wind correction, heading, and ETA calculations.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => showPremiumPaywall(context, source: 'plog_screen'),
                  child: const Text('Unlock Flight Path Training Pro'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Planner (PLOG)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _resetAll,
            child: const Text('Reset All'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.pagePaddingAll,
          children: [
            // Info card
            _InfoCard(isDark: isDark),
            const SizedBox(height: AppSpacing.cardGap),

            // Leg cards
            for (final leg in _legs) ...[
              _LegCard(
                key: ValueKey(leg.index),
                legState: leg,
                isDark: isDark,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.cardGap),
            ],

            // Add leg button
            if (_legs.length < _maxLegs)
              OutlinedButton.icon(
                onPressed: _addLeg,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Leg'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            // Summary card
            if (summary != null) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              _SummaryCard(
                totalDist: summary.totalDist,
                totalEta: summary.totalEta,
                avgGs: summary.avgGs,
                isDark: isDark,
                cs: cs,
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-leg mutable state (controllers + cached result)
// ---------------------------------------------------------------------------

class _LegState {
  final int index;
  final TextEditingController trackController;
  final TextEditingController distanceController;
  final TextEditingController tasController;
  final TextEditingController windFromController;
  final TextEditingController windSpeedController;

  PlogResult? result;

  _LegState({
    required this.index,
    String initialTas = '',
    String initialWindFrom = '',
    String initialWindSpeed = '',
  })  : trackController = TextEditingController(),
        distanceController = TextEditingController(),
        tasController = TextEditingController(text: initialTas),
        windFromController = TextEditingController(text: initialWindFrom),
        windSpeedController = TextEditingController(text: initialWindSpeed);

  void dispose() {
    trackController.dispose();
    distanceController.dispose();
    tasController.dispose();
    windFromController.dispose();
    windSpeedController.dispose();
  }
}

// ---------------------------------------------------------------------------
// Info card
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  final bool isDark;
  const _InfoCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        'Enter track, distance, TAS, and wind for each leg. Results update automatically.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leg card
// ---------------------------------------------------------------------------

class _LegCard extends StatefulWidget {
  final _LegState legState;
  final bool isDark;
  final VoidCallback onChanged;

  const _LegCard({
    super.key,
    required this.legState,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_LegCard> createState() => _LegCardState();
}

class _LegCardState extends State<_LegCard> {
  // Validation errors
  String? _trackError;
  String? _distanceError;
  String? _tasError;
  String? _windFromError;
  String? _windSpeedError;

  void _recalculate() {
    final leg = widget.legState;

    // Parse and validate
    int? track = int.tryParse(leg.trackController.text);
    double? distance = double.tryParse(leg.distanceController.text);
    int? tas = int.tryParse(leg.tasController.text);
    int? windFrom = int.tryParse(leg.windFromController.text);
    int? windSpeed = int.tryParse(leg.windSpeedController.text);

    String? trackErr;
    String? distErr;
    String? tasErr;
    String? wfErr;
    String? wsErr;

    if (track != null && (track < 0 || track > 360)) {
      trackErr = '0–360';
      track = track.clamp(0, 360);
    }
    if (distance != null && (distance <= 0 || distance > 999)) {
      distErr = '0.1–999';
      distance = distance.clamp(0.1, 999.0);
    }
    if (tas != null && (tas < 40 || tas > 250)) {
      tasErr = '40–250';
      tas = tas.clamp(40, 250);
    }
    if (windFrom != null && (windFrom < 0 || windFrom > 360)) {
      wfErr = '0–360';
      windFrom = windFrom.clamp(0, 360);
    }
    if (windSpeed != null && (windSpeed < 0 || windSpeed > 100)) {
      wsErr = '0–100';
      windSpeed = windSpeed.clamp(0, 100);
    }

    PlogResult? result;
    if (track != null &&
        distance != null &&
        tas != null &&
        windFrom != null &&
        windSpeed != null) {
      try {
        result = PlogCalculator.calculate(
          track: track,
          distance: distance,
          tas: tas,
          windFrom: windFrom,
          windSpeed: windSpeed,
        );
      } catch (_) {
        result = null;
      }
    }

    setState(() {
      _trackError = trackErr;
      _distanceError = distErr;
      _tasError = tasErr;
      _windFromError = wfErr;
      _windSpeedError = wsErr;
      leg.result = result;
    });

    widget.onChanged();
  }

  @override
  void initState() {
    super.initState();
    final leg = widget.legState;
    leg.trackController.addListener(_recalculate);
    leg.distanceController.addListener(_recalculate);
    leg.tasController.addListener(_recalculate);
    leg.windFromController.addListener(_recalculate);
    leg.windSpeedController.addListener(_recalculate);
    // Run once for pre-filled values.
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    final leg = widget.legState;
    final isDark = widget.isDark;
    final cs = Theme.of(context).colorScheme;
    final result = leg.result;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Leg ${leg.index + 1}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 14),

          // Input grid — 2 columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _NumField(
                      controller: leg.trackController,
                      label: 'Track (°M)',
                      integer: true,
                      error: _trackError,
                    ),
                    const SizedBox(height: 10),
                    _NumField(
                      controller: leg.distanceController,
                      label: 'Distance (nm)',
                      integer: false,
                      error: _distanceError,
                    ),
                    const SizedBox(height: 10),
                    _NumField(
                      controller: leg.tasController,
                      label: 'TAS (kt)',
                      integer: true,
                      error: _tasError,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _NumField(
                      controller: leg.windFromController,
                      label: 'Wind From (°M)',
                      integer: true,
                      error: _windFromError,
                    ),
                    const SizedBox(height: 10),
                    _NumField(
                      controller: leg.windSpeedController,
                      label: 'Wind Speed (kt)',
                      integer: true,
                      error: _windSpeedError,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Results row
          if (result != null) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ResultChip(
                  label: 'Hdg',
                  value: '${result.heading.toString().padLeft(3, '0')}°',
                  cs: cs,
                ),
                _ResultChip(
                  label: 'GS',
                  value: '${result.groundspeed} kt',
                  cs: cs,
                ),
                _ResultChip(
                  label: 'ETA',
                  value: '${result.etaMinutes.toStringAsFixed(1)} min',
                  cs: cs,
                ),
                _ResultChip(
                  label: 'WCA',
                  value: '${result.wca.abs().toStringAsFixed(1)}° ${result.wca >= 0 ? 'R' : 'L'}',
                  cs: cs,
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
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final double totalDist;
  final double totalEta;
  final double avgGs;
  final bool isDark;
  final ColorScheme cs;

  const _SummaryCard({
    required this.totalDist,
    required this.totalEta,
    required this.avgGs,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROUTE SUMMARY',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ResultChip(
                label: 'Total dist',
                value: '${totalDist.toStringAsFixed(1)} nm',
                cs: cs,
              ),
              _ResultChip(
                label: 'Total ETA',
                value: '${totalEta.toStringAsFixed(1)} min',
                cs: cs,
              ),
              _ResultChip(
                label: 'Avg GS',
                value: '${avgGs.toStringAsFixed(0)} kt',
                cs: cs,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool integer;
  final String? error;

  const _NumField({
    required this.controller,
    required this.label,
    required this.integer,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: integer
          ? const TextInputType.numberWithOptions(decimal: false, signed: false)
          : const TextInputType.numberWithOptions(decimal: true, signed: false),
      inputFormatters: integer
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
        errorText: error,
        errorStyle: const TextStyle(
          color: AppColors.error,
          fontSize: 10,
          height: 1.2,
        ),
        errorMaxLines: 1,
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _ResultChip({
    required this.label,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.75),
                  ),
            ),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
