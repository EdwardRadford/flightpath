// Aircraft Data Sheet screen.
//
// Shows a horizontally-scrollable tab bar — one tab per supported aircraft type.
// The tab matching the user's profile aircraft is selected on open.
// Each tab contains a scrollable data sheet: speeds, performance, distances,
// weights, and type-specific notes.
//
// Fully free — this is a reference tool, not a premium feature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/tools/data/aircraft_data.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

/// Aircraft Data Sheet — performance reference for common UK training types.
class AircraftDataScreen extends ConsumerStatefulWidget {
  const AircraftDataScreen({super.key});

  @override
  ConsumerState<AircraftDataScreen> createState() => _AircraftDataScreenState();
}

class _AircraftDataScreenState extends ConsumerState<AircraftDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: kAircraftDataList.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Jump to the tab that matches the user's profile aircraft type.
  /// Called once after the first user data frame arrives.
  void _jumpToUserAircraft(String? aircraftType) {
    if (_initialised || aircraftType == null) return;
    final idx = kAircraftDataList.indexWhere((a) => a.type == aircraftType);
    if (idx != -1) {
      _tabController.animateTo(idx);
    }
    _initialised = true;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Once we have user data, jump to their aircraft tab (once only).
    userAsync.whenData((user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToUserAircraft(user?.aircraftType);
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aircraft Data'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: cs.outline,
              labelColor: AppColors.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.55),
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              tabs: kAircraftDataList
                  .map((a) => Tab(text: _shortTabLabel(a.displayName)))
                  .toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: kAircraftDataList
            .map((data) => _AircraftTab(data: data))
            .toList(),
      ),
    );
  }

  /// Shortens the display name to fit comfortably in a tab label.
  static String _shortTabLabel(String displayName) {
    final parts = displayName.split(' ');
    if (parts.length <= 2) return displayName;
    // "Cessna 152" / "Cessna 172S Skyhawk" → "C152" / "C172S"
    if (parts[0] == 'Cessna') return 'C${parts[1]}';
    // "PA-28-161 Warrior II" → "PA-28-161"
    // "PA-28-181 Archer III" → "PA-28-181"
    // "Piper PA-38 Tomahawk" → "PA-38"
    if (parts[0].startsWith('PA-')) return parts[0];
    if (parts[0] == 'Piper') return parts[1];
    // "Diamond DA20-C1 Eclipse" → "DA20-C1"
    // "Diamond DA40 Diamond Star" → "DA40"
    if (parts[0] == 'Diamond') return parts[1];
    // "Robin DR400/160" → already 2 tokens, handled above
    // "Grob G115E Tutor" → "G115E"
    // "Tecnam P2002 Sierra" → "P2002"
    return parts[1];
  }
}

// ── Per-aircraft tab content ─────────────────────────────────────────────────

class _AircraftTab extends StatelessWidget {
  final AircraftData data;

  const _AircraftTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── Header ───────────────────────────────────────────────────────────
        Text(
          data.displayName,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.engine,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 14),

        // ── Disclaimer card ───────────────────────────────────────────────────
        _DisclaimerCard(isDark: isDark),
        const SizedBox(height: 16),

        // ── Speed limits ──────────────────────────────────────────────────────
        _SectionHeader(label: 'Speed Limits'),
        _DataCard(
          isDark: isDark,
          rows: [
            _SpeedRow(
              label: 'VNE',
              valueText: '${data.vne} kt',
              description: 'Never exceed',
              valueColour: AppColors.error,
            ),
            _SpeedRow(
              label: 'VNO',
              valueText: '${data.vno} kt',
              description: 'Max structural cruise',
              valueColour: AppColors.warning,
            ),
            _SpeedRow(
              label: 'VA',
              valueText: '${data.va} kt',
              description: 'Manoeuvring (at MTOW)',
              valueColour: AppColors.primary,
            ),
            _SpeedRow(
              label: 'VFE',
              valueText: '${data.vfe} kt',
              description: 'Max flap extended',
              valueColour: AppColors.primary,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Climb & approach speeds ───────────────────────────────────────────
        _SectionHeader(label: 'Climb & Approach Speeds'),
        _DataCard(
          isDark: isDark,
          rows: [
            _SpeedRow(
              label: 'VY',
              valueText: '${data.vy} kt',
              description: 'Best rate of climb',
              valueColour: AppColors.primary,
            ),
            _SpeedRow(
              label: 'VX',
              valueText: '${data.vx} kt',
              description: 'Best angle of climb',
              valueColour: AppColors.primary,
            ),
            _SpeedRow(
              label: 'VS1',
              valueText: '${data.vs1} kt',
              description: 'Stall — clean',
              valueColour: AppColors.primary,
            ),
            _SpeedRow(
              label: 'VS0',
              valueText: '${data.vs0} kt',
              description: 'Stall — landing config',
              valueColour: AppColors.primary,
            ),
            _SpeedRow(
              label: 'VAPP',
              valueText: '${data.approachSpeed} kt',
              description: 'Normal approach (full flap)',
              valueColour: AppColors.primary,
            ),
            _SpeedRow(
              label: 'VG',
              valueText: '${data.bestGlide} kt',
              description: 'Best glide (engine out)',
              valueColour: AppColors.primary,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Performance ───────────────────────────────────────────────────────
        _SectionHeader(label: 'Performance'),
        _DataCard(
          isDark: isDark,
          rows: [
            _DataRow(
              label: 'Cruise TAS',
              value: '${data.cruiseTas} kt',
              subValue: '75% power, ISA',
              isDark: isDark,
            ),
            _DataRow(
              label: 'Fuel burn',
              value: '${data.fuelBurnGph.toStringAsFixed(1)} US gal/hr',
              subValue: '${data.fuelBurnLph.toStringAsFixed(1)} L/hr  •  75% power',
              isDark: isDark,
            ),
            _DataRow(
              label: 'Service ceiling',
              value: '${_formatFt(data.serviceCeiling)} ft',
              subValue: null,
              isDark: isDark,
            ),
            _DataRow(
              label: 'Climb rate',
              value: '${data.climbRate} fpm',
              subValue: 'Sea level, ISA, MTOW',
              isDark: isDark,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Field performance ─────────────────────────────────────────────────
        _SectionHeader(label: 'Field Performance'),
        Container(
          decoration: _cardDecoration(isDark),
          child: Column(
            children: [
              _FieldPerfHeader(isDark: isDark),
              _fieldDivider(isDark),
              _FieldPerfRow(
                label: 'T/O ground roll',
                metres: data.takeoffGroundRoll,
                isDark: isDark,
              ),
              _fieldDivider(isDark),
              _FieldPerfRow(
                label: 'T/O over 50 ft',
                metres: data.takeoffOver50ft,
                isDark: isDark,
              ),
              _fieldDivider(isDark),
              _FieldPerfRow(
                label: 'Landing roll',
                metres: data.landingGroundRoll,
                isDark: isDark,
              ),
              _fieldDivider(isDark),
              _FieldPerfRow(
                label: 'Landing over 50 ft',
                metres: data.landingOver50ft,
                isDark: isDark,
                isLast: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            'ISA conditions, sea level, MTOW',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Weights ───────────────────────────────────────────────────────────
        _SectionHeader(label: 'Weights'),
        _DataCard(
          isDark: isDark,
          rows: [
            _DataRow(
              label: 'MTOW',
              value: '${data.mtow} kg',
              subValue: '${_kgToLbs(data.mtow)} lb',
              isDark: isDark,
            ),
            _DataRow(
              label: 'Useful load',
              value: '${data.usefulLoad} kg',
              subValue: '${_kgToLbs(data.usefulLoad)} lb',
              isDark: isDark,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Notes ─────────────────────────────────────────────────────────────
        if (data.notes.isNotEmpty) ...[
          _SectionHeader(label: 'Notes'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(isDark),
            child: Text(
              data.notes,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      );

  Widget _fieldDivider(bool isDark) => Divider(
        height: 1,
        thickness: 0.5,
        color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        indent: 14,
        endIndent: 14,
      );

  static String _formatFt(int ft) {
    if (ft >= 1000) {
      final k = ft / 1000;
      return k == k.roundToDouble() ? '${k.round()},000' : ft.toString();
    }
    return ft.toString();
  }

  static String _kgToLbs(int kg) {
    return (kg * 2.20462).round().toString();
  }
}

// ── Disclaimer card ──────────────────────────────────────────────────────────

class _DisclaimerCard extends StatelessWidget {
  final bool isDark;

  const _DisclaimerCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: isDark ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 0.75,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              kAircraftDataDisclaimer,
              style: TextStyle(
                color: isDark
                    ? AppColors.onSurfaceDark.withValues(alpha: 0.75)
                    : AppColors.onSurfaceLight.withValues(alpha: 0.75),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

// ── Generic data card that wraps a list of row widgets ───────────────────────

class _DataCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> rows;

  const _DataCard({required this.isDark, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Column(children: rows),
    );
  }
}

// ── Speed row — label | value (coloured) | description ──────────────────────

class _SpeedRow extends StatelessWidget {
  final String label;
  final String valueText;
  final String description;
  final Color valueColour;
  final bool isLast;

  const _SpeedRow({
    required this.label,
    required this.valueText,
    required this.description,
    required this.valueColour,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Speed abbreviation
              SizedBox(
                width: 44,
                child: Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // Coloured speed value
              SizedBox(
                width: 64,
                child: Text(
                  valueText,
                  style: TextStyle(
                    color: valueColour,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Plain-language description
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }
}

// ── Generic data row — label | primary value | optional sub-value ────────────

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final bool isDark;
  final bool isLast;

  const _DataRow({
    required this.label,
    required this.value,
    required this.subValue,
    required this.isDark,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subValue != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subValue!,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }
}

// ── Field performance table header ───────────────────────────────────────────

class _FieldPerfHeader extends StatelessWidget {
  final bool isDark;

  const _FieldPerfHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Expanded(flex: 5, child: SizedBox()),
          Expanded(
            flex: 3,
            child: Text(
              'Metres',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Feet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field performance data row — label | metres | feet ───────────────────────

class _FieldPerfRow extends StatelessWidget {
  final String label;
  final int metres;
  final bool isDark;
  final bool isLast;

  const _FieldPerfRow({
    required this.label,
    required this.metres,
    required this.isDark,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final feet = (metres * 3.28084).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '$metres m',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '$feet ft',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
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
