// Weather briefing screen — shows current conditions for the user's airfield
// via the getWeather Cloud Function (AVWX METAR proxy, europe-west2).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/core/services/weather_service.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// ---------------------------------------------------------------------------
// Daily limit (UID-scoped to prevent cross-user leakage)
// ---------------------------------------------------------------------------

String _kWeatherDailyCount() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return 'weather_briefing_daily_count_$uid';
}

String _kWeatherDailyDate() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return 'weather_briefing_daily_date_$uid';
}
const int kWeatherFreeDailyLimit = 3;

// ---------------------------------------------------------------------------
// Local state — ICAO override + fetch result
// ---------------------------------------------------------------------------

class _WeatherState {
  final String? icaoOverride;
  final bool loading;
  final WeatherData? data;
  final String? error;
  final bool noDataForStation;
  final DateTime? fetchedAt;

  const _WeatherState({
    this.icaoOverride,
    this.loading = false,
    this.data,
    this.error,
    this.noDataForStation = false,
    this.fetchedAt,
  });

  _WeatherState copyWith({
    String? icaoOverride,
    bool clearOverride = false,
    bool? loading,
    WeatherData? data,
    String? error,
    bool clearError = false,
    bool? noDataForStation,
    DateTime? fetchedAt,
  }) {
    return _WeatherState(
      icaoOverride: clearOverride ? null : (icaoOverride ?? this.icaoOverride),
      loading: loading ?? this.loading,
      data: data ?? this.data,
      error: clearError ? null : (error ?? this.error),
      noDataForStation: noDataForStation ?? this.noDataForStation,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  final WeatherService _service = WeatherService();
  _WeatherState _state = const _WeatherState();

  // True once a fetch has been counted for this screen session.
  bool _sessionCounted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoFetch());
  }

  // ── Daily limit helpers ───────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<bool> _checkLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final storedDate = prefs.getString(_kWeatherDailyDate()) ?? '';
    final count = storedDate == today ? (prefs.getInt(_kWeatherDailyCount()) ?? 0) : 0;
    if (count < kWeatherFreeDailyLimit) return true;
    return ref.read(premiumStatusProvider.future);
  }

  Future<void> _incrementDailyCount() async {
    if (_sessionCounted) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final storedDate = prefs.getString(_kWeatherDailyDate()) ?? '';
    final current = storedDate == today ? (prefs.getInt(_kWeatherDailyCount()) ?? 0) : 0;
    await prefs.setString(_kWeatherDailyDate(), today);
    await prefs.setInt(_kWeatherDailyCount(), current + 1);
    _sessionCounted = true;
  }

  String? get _activeIcao {
    if (_state.icaoOverride != null && _state.icaoOverride!.isNotEmpty) {
      return _state.icaoOverride;
    }
    final user = ref.read(appUserProvider).valueOrNull;
    final icao = user?.airfieldIcao;
    return (icao != null && icao.isNotEmpty) ? icao : null;
  }

  Future<void> _autoFetch() async {
    // Wait for the user stream to emit before checking airfieldIcao.
    final user = await ref.read(appUserProvider.future);
    final icao = _state.icaoOverride?.isNotEmpty == true
        ? _state.icaoOverride!
        : (user?.airfieldIcao.isNotEmpty == true ? user!.airfieldIcao : null);
    if (icao == null) return;
    await _fetch(icao);
  }

  Future<void> _fetch(String icao) async {
    // Gate: only check the limit before counting a new session.
    if (!_sessionCounted) {
      final allowed = await _checkLimit();
      if (!allowed) {
        if (!mounted) return;
        final purchased = await showPremiumPaywall(
          context,
          source: 'weather_briefing_daily_limit',
        );
        if (!purchased || !mounted) return;
      }
    }

    setState(() {
      _state = _state.copyWith(loading: true, clearError: true, noDataForStation: false);
    });
    try {
      final data = await _service.getWeatherForAirfield(icao);
      if (!mounted) return;
      await _incrementDailyCount();
      if (!mounted) return;
      setState(() {
        _state = _WeatherState(
          icaoOverride: _state.icaoOverride,
          loading: false,
          data: data,
          fetchedAt: DateTime.now(),
        );
      });
    } on NoWeatherDataException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(loading: false, noDataForStation: true, error: e.message);
      });
    } on WeatherServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(loading: false, error: e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          loading: false,
          error: 'Could not load weather. Please try again.',
        );
      });
    }
  }

  // ── ICAO change dialog ────────────────────────────────────────────────────

  Future<void> _showIcaoDialog() async {
    final controller = TextEditingController(text: _activeIcao ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change airfield'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 4,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
          ],
          decoration: const InputDecoration(
            hintText: 'ICAO code e.g. EGTC',
            counterText: '',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Fetch'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;
    final icao = result.trim().toUpperCase();
    setState(() {
      _state = _state.copyWith(icaoOverride: icao);
    });
    await _fetch(icao);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final profileIcao = userAsync.valueOrNull?.airfieldIcao;
    final displayIcao = _state.icaoOverride?.isNotEmpty == true
        ? _state.icaoOverride!
        : (profileIcao?.isNotEmpty == true ? profileIcao! : null);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Briefing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_state.data != null && displayIcao != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => _fetch(displayIcao),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _buildBody(displayIcao, isDark),
      ),
    );
  }

  // Known non-reporting airfields → nearest station that publishes weather.
  static const Map<String, String> _nearestReporting = {
    'EGBT': 'EGTC', // Turweston → Cranfield (~7 nm)
    'EGBS': 'EGCW', // Shobdon → Welshpool (~24 nm)
    'EGLS': 'EGHI', // Old Sarum → Southampton (~18 nm)
    'EGSG': 'EGSS', // Stapleford → Stansted (~14 nm)
    'EGHO': 'EGHI', // Thruxton → Southampton (~18 nm)
    'EGTB': 'EGUB', // Wycombe Air Park → Benson (~11 nm)
    'EGLM': 'EGLF', // White Waltham → Farnborough (~12 nm)
    'EGHR': 'EGKA', // Goodwood → Shoreham (~12 nm)
    'EGCB': 'EGCC', // Barton → Manchester (~8 nm)
    'EGCF': 'EGNM', // Sherburn-in-Elmet → Leeds Bradford (~15 nm)
  };

  Widget _buildBody(String? displayIcao, bool isDark) {
    // No airfield set and no override
    if (displayIcao == null && !_state.loading) {
      return EmptyStateWidget(
        icon: Icons.location_off_rounded,
        title: 'No airfield set',
        subtitle:
            'Go to Settings → Profile and set your home airfield to see weather here.',
        buttonText: 'Set airfield',
        onButtonPressed: () => context.push('/settings/profile'),
      );
    }

    if (_state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_state.noDataForStation && displayIcao != null) {
      return _buildNoDataCard(displayIcao);
    }

    if (_state.error != null) {
      return EmptyStateWidget(
        icon: Icons.cloud_off_rounded,
        title: 'Weather unavailable',
        subtitle: _state.error!,
        buttonText: 'Retry',
        onButtonPressed:
            displayIcao != null ? () => _fetch(displayIcao) : null,
      );
    }

    final data = _state.data;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _WeatherContent(
      data: data,
      icao: displayIcao!,
      isDark: isDark,
      fetchedAt: _state.fetchedAt,
      onChangeIcao: _showIcaoDialog,
    );
  }

  Widget _buildNoDataCard(String icao) {
    final fallback = _nearestReporting[icao.toUpperCase()];
    return Center(
      child: Padding(
        padding: AppSpacing.pageHorizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_cloudy_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '$icao doesn\'t publish live weather',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              fallback != null
                  ? 'This airfield has no automated weather reporting. Try $fallback nearby.'
                  : 'This airfield has no automated weather reporting. Enter a nearby reporting airfield using the ICAO code.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (fallback != null)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _state = _state.copyWith(icaoOverride: fallback);
                  });
                  _fetch(fallback);
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text('Check $fallback instead'),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content widget (data available)
// ---------------------------------------------------------------------------

class _WeatherContent extends StatefulWidget {
  final WeatherData data;
  final String icao;
  final bool isDark;
  final DateTime? fetchedAt;
  final VoidCallback onChangeIcao;

  const _WeatherContent({
    required this.data,
    required this.icao,
    required this.isDark,
    required this.fetchedAt,
    required this.onChangeIcao,
  });

  @override
  State<_WeatherContent> createState() => _WeatherContentState();
}

class _WeatherContentState extends State<_WeatherContent> {
  bool _metarExpanded = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — ICAO chip + last updated
          _buildHeader(context),
          const SizedBox(height: AppSpacing.sectionGap),

          // VFR badge
          _VfrBadge(data: widget.data),
          const SizedBox(height: AppSpacing.sectionGap),

          // Current conditions card
          _SectionLabel(label: 'CONDITIONS'),
          const SizedBox(height: 8),
          _ConditionsCard(data: widget.data, isDark: widget.isDark),
          const SizedBox(height: AppSpacing.sectionGap),

          // Cloud layers
          _SectionLabel(label: 'CLOUD LAYERS'),
          const SizedBox(height: 8),
          _CloudLayersCard(data: widget.data, isDark: widget.isDark),
          const SizedBox(height: AppSpacing.sectionGap),

          // Raw METAR — collapsible
          _SectionLabel(label: 'RAW METAR'),
          const SizedBox(height: 8),
          _CollapsibleMetar(
            metar: widget.data.toMetarString(widget.icao),
            isDark: widget.isDark,
            expanded: _metarExpanded,
            onToggle: () => setState(() => _metarExpanded = !_metarExpanded),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ageText = _ageText(widget.fetchedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ICAO chip + age text
        Row(
          children: [
            // Tappable ICAO chip
            GestureDetector(
              onTap: widget.onChangeIcao,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.icao,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (ageText != null)
              Text(
                ageText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // Route Planner shortcut
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/tools/plog'),
            icon: const Icon(Icons.route_rounded, size: 16),
            label: const Text('Route Planner (PLOG)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 1,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String? _ageText(DateTime? fetchedAt) {
    if (fetchedAt == null) return null;
    final diff = DateTime.now().difference(fetchedAt);
    if (diff.inSeconds < 60) return 'Just updated';
    if (diff.inMinutes == 1) return 'Updated 1 min ago';
    return 'Updated ${diff.inMinutes} min ago';
  }
}

// ---------------------------------------------------------------------------
// VFR badge
// ---------------------------------------------------------------------------

class _VfrBadge extends StatelessWidget {
  final WeatherData data;

  const _VfrBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    final visKm = data.visibilityMetres / 1000.0;
    final lowestBase = data.lowestCloudBaseFt;

    // Not VFR: vis < 5 km OR BKN/OVC ceiling < 1000 ft
    final ceilingBelowMin = lowestBase != null &&
        lowestBase < 1000 &&
        data.cloudLayers.any(
          (l) => l.coverage == 'BKN' || l.coverage == 'OVC',
        );

    final Color badgeColor;
    final String label;
    final IconData icon;

    if (visKm < 5 || ceilingBelowMin) {
      badgeColor = AppColors.error;
      label = 'Not VFR';
      icon = Icons.do_not_disturb_rounded;
    } else if (visKm < 8 ||
        (lowestBase != null && lowestBase < 3000 &&
            data.cloudLayers.any(
              (l) => l.coverage == 'BKN' || l.coverage == 'OVC',
            ))) {
      badgeColor = AppColors.warning;
      label = 'Marginal';
      icon = Icons.warning_amber_rounded;
    } else {
      badgeColor = AppColors.success;
      label = 'VFR OK';
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: badgeColor, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: badgeColor,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '— ${data.conditions}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conditions card
// ---------------------------------------------------------------------------

class _ConditionsCard extends StatelessWidget {
  final WeatherData data;
  final bool isDark;

  const _ConditionsCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final windDir = data.windDirectionDeg != null
        ? '${data.windDirectionDeg.toString().padLeft(3, '0')}°'
        : 'VRB';
    final gust = data.windGustKt != null
        ? ' (G${data.windGustKt!.round()} kt)'
        : '';

    return _DataCard(
      isDark: isDark,
      child: Column(
        children: [
          _DataRow(
            icon: Icons.thermostat_rounded,
            label: 'Temperature',
            value: '${data.temperature.toStringAsFixed(1)} °C'
                ' / DP ${data.dewpoint.toStringAsFixed(1)} °C',
          ),
          _Divider(isDark: isDark),
          _DataRow(
            icon: Icons.air_rounded,
            label: 'Wind',
            value: '$windDir  ${data.windSpeed}$gust',
          ),
          _Divider(isDark: isDark),
          _DataRow(
            icon: Icons.visibility_rounded,
            label: 'Visibility',
            value: data.visibility,
          ),
          _Divider(isDark: isDark),
          _DataRow(
            icon: Icons.speed_rounded,
            label: 'QNH',
            value: '${data.pressureHpa.round()} hPa',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cloud layers card
// ---------------------------------------------------------------------------

class _CloudLayersCard extends StatelessWidget {
  final WeatherData data;
  final bool isDark;

  const _CloudLayersCard({required this.data, required this.isDark});

  static const _coverageLabels = {
    'CLR': 'Clear',
    'FEW': 'Few',
    'SCT': 'Scattered',
    'BKN': 'Broken',
    'OVC': 'Overcast',
  };

  @override
  Widget build(BuildContext context) {
    if (data.cloudLayers.isEmpty) {
      return _DataCard(
        isDark: isDark,
        child: _DataRow(
          icon: Icons.wb_sunny_rounded,
          label: 'Sky condition',
          value: 'Clear below 12 000 ft',
        ),
      );
    }

    return _DataCard(
      isDark: isDark,
      child: Column(
        children: [
          for (var i = 0; i < data.cloudLayers.length; i++) ...[
            if (i > 0) _Divider(isDark: isDark),
            _CloudLayerRow(
              layer: data.cloudLayers[i],
              coverageLabel: _coverageLabels[data.cloudLayers[i].coverage] ??
                  data.cloudLayers[i].coverage,
            ),
          ],
        ],
      ),
    );
  }
}

class _CloudLayerRow extends StatelessWidget {
  final CloudLayer layer;
  final String coverageLabel;

  const _CloudLayerRow({required this.layer, required this.coverageLabel});

  Color _coverageColor() {
    switch (layer.coverage) {
      case 'BKN':
      case 'OVC':
        return layer.heightFt < 1000 ? AppColors.error : AppColors.warning;
      case 'SCT':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _coverageColor();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                layer.coverage,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontSize: 11,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              coverageLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            layer.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsible raw METAR
// ---------------------------------------------------------------------------

class _CollapsibleMetar extends StatelessWidget {
  final String metar;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggle;

  const _CollapsibleMetar({
    required this.metar,
    required this.isDark,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tap-to-expand header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  const Icon(Icons.cloud_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'RAW METAR',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                0,
                AppSpacing.cardPadding,
                AppSpacing.cardPadding,
              ),
              child: SelectableText(
                metar,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.6,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            letterSpacing: 1.2,
          ),
    );
  }
}

class _DataCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _DataCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
    );
  }
}
