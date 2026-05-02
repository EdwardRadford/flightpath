// Airfield Info screen — searchable list of UK training airfields with
// a detail view for each. All airfields are currently hasData: false
// (coming soon). When hasData is true in future, full detail is shown.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/tools/data/airfield_data.dart';
import 'package:flight_path/shared/models/airfield.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

// ---------------------------------------------------------------------------
// AirfieldScreen
// ---------------------------------------------------------------------------

class AirfieldScreen extends ConsumerStatefulWidget {
  const AirfieldScreen({super.key});

  @override
  ConsumerState<AirfieldScreen> createState() => _AirfieldScreenState();
}

class _AirfieldScreenState extends ConsumerState<AirfieldScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Airfield> _filtered(String? homeIcao) {
    final q = _query.trim().toUpperCase();
    final all = _sorted(homeIcao);
    if (q.isEmpty) return all;
    return all.where((a) {
      return a.icao.contains(q) ||
          a.name.toUpperCase().contains(q) ||
          a.location.toUpperCase().contains(q);
    }).toList();
  }

  /// Puts the home airfield first; otherwise preserves catalogue order.
  List<Airfield> _sorted(String? homeIcao) {
    if (homeIcao == null || homeIcao.isEmpty) return kAirfields;
    final home = homeIcao.toUpperCase();
    final result = [...kAirfields];
    result.sort((a, b) {
      if (a.icao == home) return -1;
      if (b.icao == home) return 1;
      return 0;
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appUserAsync = ref.watch(appUserProvider);
    final homeIcao = appUserAsync.valueOrNull?.airfieldIcao ?? '';
    final filtered = _filtered(homeIcao);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Airfield Info'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: cs.onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search by ICAO or name…',
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: cs.onSurface.withValues(alpha: 0.45),
                  size: 20,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: cs.onSurface.withValues(alpha: 0.45),
                          size: 18,
                        ),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _EmptySearch(query: _query)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final airfield = filtered[index];
                      final isHome = homeIcao.isNotEmpty &&
                          airfield.icao == homeIcao.toUpperCase();
                      return _AirfieldListTile(
                        airfield: airfield,
                        isHome: isHome,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => _AirfieldDetailScreen(
                              airfield: airfield,
                              isHome: isHome,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AirfieldListTile
// ---------------------------------------------------------------------------

class _AirfieldListTile extends StatelessWidget {
  final Airfield airfield;
  final bool isHome;
  final VoidCallback onTap;

  const _AirfieldListTile({
    required this.airfield,
    required this.isHome,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHome
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : (isDark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight),
              width: isHome ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            children: [
              // ICAO badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isHome
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  airfield.icao,
                  style: TextStyle(
                    color: isHome ? AppColors.primary : cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          airfield.name,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isHome) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'YOUR AIRFIELD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      airfield.location,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.35),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptySearch
// ---------------------------------------------------------------------------

class _EmptySearch extends StatelessWidget {
  final String query;

  const _EmptySearch({required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No airfields match "$query"',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AirfieldDetailScreen
// ---------------------------------------------------------------------------

class _AirfieldDetailScreen extends StatelessWidget {
  final Airfield airfield;
  final bool isHome;

  const _AirfieldDetailScreen({
    required this.airfield,
    required this.isHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${airfield.icao} ${airfield.name}'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: airfield.hasData
            ? _FullDetail(airfield: airfield, isHome: isHome)
            : _ComingSoon(airfield: airfield, isHome: isHome),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ComingSoon
// ---------------------------------------------------------------------------

class _ComingSoon extends StatelessWidget {
  final Airfield airfield;
  final bool isHome;

  const _ComingSoon({required this.airfield, required this.isHome});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        airfield.icao,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (isHome) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YOUR AIRFIELD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  airfield.name,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  airfield.location,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Coming soon card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.construction_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Coming soon',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "We're building airfield-specific content for UK training fields.\n"
                  "This airfield's data is coming soon.",
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  thickness: 0.5,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Flying from here? Let us know at support@getflightpath.app',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
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
// _FullDetail  (shown when hasData: true — reserved for future verified data)
// ---------------------------------------------------------------------------

class _FullDetail extends StatelessWidget {
  final Airfield airfield;
  final bool isHome;

  const _FullDetail({required this.airfield, required this.isHome});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _SectionCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isHome)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'YOUR AIRFIELD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                _DetailRow(
                  label: 'Elevation',
                  value: '${airfield.elevation} ft AMSL',
                ),
                const SizedBox(height: 8),
                _DetailRow(label: 'ATZ', value: airfield.atzDescription),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Runways
          if (airfield.runways.isNotEmpty) ...[
            _SectionHeader(title: 'Runways', cs: cs),
            const SizedBox(height: 8),
            _SectionCard(
              isDark: isDark,
              child: Column(
                children: [
                  for (int i = 0; i < airfield.runways.length; i++) ...[
                    if (i > 0)
                      Divider(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight,
                        thickness: 0.5,
                        height: 20,
                      ),
                    _RunwayRow(runway: airfield.runways[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Circuit
          _SectionHeader(title: 'Circuit', cs: cs),
          const SizedBox(height: 8),
          _SectionCard(
            isDark: isDark,
            child: Column(
              children: [
                _DetailRow(
                  label: 'Direction',
                  value: airfield.circuitDirection,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Altitude',
                  value: '${airfield.circuitAltitude} ft QFE',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Frequencies
          if (airfield.frequencies.isNotEmpty) ...[
            _SectionHeader(title: 'Frequencies', cs: cs),
            const SizedBox(height: 8),
            for (final freq in airfield.frequencies) ...[
              _FrequencyCard(frequency: freq, isDark: isDark),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
          ],

          // Local rules
          if (airfield.localRules.isNotEmpty) ...[
            _SectionHeader(title: 'Local Rules', cs: cs),
            const SizedBox(height: 8),
            _SectionCard(
              isDark: isDark,
              child: Text(
                airfield.localRules,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.85),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Common student mistakes
          if (airfield.commonStudentMistakes.isNotEmpty) ...[
            _SectionHeader(title: 'Common Student Mistakes', cs: cs),
            const SizedBox(height: 8),
            _SectionCard(
              isDark: isDark,
              child: Text(
                airfield.commonStudentMistakes,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.85),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared detail-view sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme cs;

  const _SectionHeader({required this.title, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.45),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RunwayRow extends StatelessWidget {
  final AirfieldRunway runway;

  const _RunwayRow({required this.runway});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          runway.designator,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${runway.lengthMetres}m',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.65),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            runway.surface,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _FrequencyCard extends StatelessWidget {
  final AirfieldFrequency frequency;
  final bool isDark;

  const _FrequencyCard({required this.frequency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  frequency.name,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  frequency.usage,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            frequency.frequency,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
