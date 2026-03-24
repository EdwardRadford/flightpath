// Weather briefing screen — full pre-flight weather assessment with METAR
// decoding, crosswind calculator, and go/no-go recommendation.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/services/weather_service.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Comprehensive weather briefing screen for student pilots. Shows:
/// 1. Current conditions (temp, pressure, humidity, visibility, wind, cloud)
/// 2. METAR display with decoded human-readable breakdown
/// 3. Crosswind calculator with wind diagram
/// 4. Go/No-Go recommendation with factor-by-factor breakdown
class WeatherBriefingScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const WeatherBriefingScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<WeatherBriefingScreen> createState() =>
      _WeatherBriefingScreenState();
}

class _WeatherBriefingScreenState extends ConsumerState<WeatherBriefingScreen> {
  WeatherData? _weather;
  bool _loading = false;
  String? _error;
  DateTime? _fetchedAt;

  // Crosswind calculator state
  int? _runwayHeading;
  String? _runwayLabel;
  final _runwayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRunwayPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchWeather());
  }

  @override
  void dispose() {
    _runwayController.dispose();
    super.dispose();
  }

  Future<void> _loadRunwayPreference() async {
    final heading = await RunwayPreferences.getRunwayHeading();
    final label = await RunwayPreferences.getRunwayLabel();
    if (heading != null && mounted) {
      setState(() {
        _runwayHeading = heading;
        _runwayLabel = label;
        _runwayController.text = heading.toString();
      });
    }
  }

  Future<void> _fetchWeather() async {
    final appUser = ref.read(appUserProvider).valueOrNull;
    final icao = appUser?.airfieldIcao ?? '';

    if (icao.isEmpty) {
      setState(() {
        _error = 'No home airfield set. Please update your profile.';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await WeatherService().getWeatherForAirfield(icao);
      if (mounted) {
        FirebaseAnalytics.instance.logEvent(
          name: 'weather_briefing_viewed',
          parameters: {'icao_code': icao},
        );
        setState(() {
          _weather = data;
          _fetchedAt = DateTime.now();
          _loading = false;
        });
        _markWeatherChecked();
      }
    } on WeatherServiceException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Unable to fetch weather data. Please check your connection and try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _markWeatherChecked() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);
    final exercises = ref.read(userExercisesProvider).valueOrNull ?? [];
    final existing = exercises
        .where((ue) =>
            ue.exerciseId == exerciseId && ue.subExercise == subExerciseId)
        .firstOrNull;
    final firestore = ref.read(firestoreServiceProvider);
    await firestore.upsertUserExercise(UserExercise(
      id: existing?.id ?? '',
      userId: uid,
      exerciseId: exerciseId,
      subExercise: subExerciseId,
      exerciseNumber: existing?.exerciseNumber ?? 0,
      status: existing?.status ?? ExerciseStatus.inProgress,
      bestRating: existing?.bestRating,
      timesAttempted: existing?.timesAttempted ?? 0,
      ratingHistory: existing?.ratingHistory ?? [],
      lastAttempted: existing?.lastAttempted,
      videoWatched: existing?.videoWatched ?? false,
      briefViewed: existing?.briefViewed ?? false,
      flashcardsCompleted: existing?.flashcardsCompleted ?? false,
      weatherChecked: true,
      spacedRepDue: existing?.spacedRepDue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(appUserProvider);
    final icao = appUserAsync.valueOrNull?.airfieldIcao ?? '';
    final aircraftType =
        appUserAsync.valueOrNull?.aircraftType ?? 'cessna_152';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          icao.isNotEmpty ? 'Weather Briefing \u2014 $icao' : 'Weather Briefing',
        ),
      ),
      body: _buildBody(icao, aircraftType),
    );
  }

  Widget _buildBody(String icao, String aircraftType) {
    if (_loading) {
      return  Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Fetching weather briefing\u2026',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style:  TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchWeather,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_weather == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final w = _weather!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Section 4: Go/No-Go banner (prominent at top) ----
          _GoNoGoBanner(
            assessment: w.assessGoNoGo(
              aircraftType: aircraftType,
              runwayHeading: _runwayHeading,
            ),
          ),
          const SizedBox(height: 20),

          // ---- Section 1: Current Conditions ----
          _SectionHeader(label: 'Current Conditions'),
          const SizedBox(height: 8),
          _CurrentConditionsCard(weather: w),
          const SizedBox(height: 20),

          // ---- Section 2: METAR Display ----
          _SectionHeader(label: 'METAR'),
          const SizedBox(height: 8),
          _MetarCard(weather: w, icao: icao),
          const SizedBox(height: 8),
          _MetarDecodedCard(weather: w),
          const SizedBox(height: 20),

          // ---- Section 3: Crosswind Calculator ----
          _SectionHeader(label: 'Crosswind Calculator'),
          const SizedBox(height: 8),
          _CrosswindCard(
            weather: w,
            aircraftType: aircraftType,
            icao: icao,
            runwayHeading: _runwayHeading,
            runwayLabel: _runwayLabel,
            runwayController: _runwayController,
            onRunwayChanged: (heading, label) {
              setState(() {
                _runwayHeading = heading;
                _runwayLabel = label;
              });
            },
          ),
          const SizedBox(height: 20),

          // ---- Section 4: Go/No-Go Factors ----
          _SectionHeader(label: 'Go/No-Go Assessment'),
          const SizedBox(height: 8),
          _GoNoGoFactorsCard(
            assessment: w.assessGoNoGo(
              aircraftType: aircraftType,
              runwayHeading: _runwayHeading,
            ),
            aircraftType: aircraftType,
          ),
          const SizedBox(height: 16),

          // Sunrise/Sunset & Trend
          Row(
            children: [
              Expanded(child: _SunTimesCard(weather: w)),
              const SizedBox(width: 12),
              Expanded(child: _TrendCard(weather: w)),
            ],
          ),
          const SizedBox(height: 24),

          // Freshness indicator
          if (_fetchedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Updated ${_freshnessText(_fetchedAt!)}',
                textAlign: TextAlign.center,
                style:  TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),

          // Refresh button
          OutlinedButton.icon(
            onPressed: _fetchWeather,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.divider),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child:  Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.warning, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Always consult your instructor for the final go/no-go '
                    'decision. Check official NOTAMs and met briefings '
                    'before flight. This data is for reference only.',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
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

  String _freshnessText(DateTime fetchedAt) {
    final diff = DateTime.now().difference(fetchedAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 1: Current Conditions
// ---------------------------------------------------------------------------

class _CurrentConditionsCard extends StatelessWidget {
  final WeatherData weather;

  const _CurrentConditionsCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final w = weather;
    final windDir = w.windDirectionDeg != null
        ? '${_compassPoint(w.windDirectionDeg!)} (${w.windDirectionDeg}\u00B0)'
        : 'Variable';
    final gustStr =
        w.windGustKt != null ? ', gusting ${w.windGustKt!.round()} kt' : '';

    // Estimate humidity from temp and dewpoint (reverse Magnus formula)
    final humidity = _estimateHumidity(w.temperature, w.dewpoint);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Condition summary row
          Row(
            children: [
              _WeatherIcon(conditionId: w.conditionId, iconCode: w.iconCode),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.conditions,
                      style:  TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${w.temperature.round()}\u00B0C',
                      style:  TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 12),

          // Detail grid
          _ConditionRow(
            icon: Icons.air_rounded,
            label: 'Wind',
            value: '$windDir at ${w.windSpeedKt.round()} kt$gustStr',
          ),
          _ConditionRow(
            icon: Icons.visibility_rounded,
            label: 'Visibility',
            value: '${w.visibilityMetres} m (${w.visibility})',
            valueColor: _visibilityColor(w.visibilityMetres),
          ),
          _ConditionRow(
            icon: Icons.cloud_rounded,
            label: 'Cloud',
            value: w.cloudLayers.isEmpty
                ? 'Sky clear'
                : w.cloudLayers.map((l) => l.label).join(', '),
            valueColor: _cloudBaseColor(w.lowestCloudBaseFt),
          ),
          _ConditionRow(
            icon: Icons.speed_rounded,
            label: 'QNH',
            value: '${w.pressureHpa.round()} hPa',
          ),
          _ConditionRow(
            icon: Icons.water_drop_outlined,
            label: 'Dewpoint',
            value: '${w.dewpoint.round()}\u00B0C',
          ),
          _ConditionRow(
            icon: Icons.water_rounded,
            label: 'Humidity',
            value: '${humidity.round()}%',
            isLast: true,
          ),
        ],
      ),
    );
  }

  double _estimateHumidity(double temp, double dewpoint) {
    // Reverse the Magnus approximation: humidity = 100 - 5 * (temp - dewpoint)
    final h = 100.0 - 5.0 * (temp - dewpoint);
    return h.clamp(0.0, 100.0);
  }

  Color _visibilityColor(int metres) {
    if (metres >= 8000) return AppColors.success;
    if (metres >= 5000) return AppColors.warning;
    return AppColors.error;
  }

  Color? _cloudBaseColor(int? baseFt) {
    if (baseFt == null) return AppColors.success;
    if (baseFt >= 3000) return AppColors.success;
    if (baseFt >= 2000) return AppColors.warning;
    return AppColors.error;
  }

  String _compassPoint(int deg) {
    const points = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
    ];
    final idx = ((deg / 22.5) + 0.5).floor() % 16;
    return points[idx];
  }
}

class _WeatherIcon extends StatelessWidget {
  final int conditionId;
  final String iconCode;

  const _WeatherIcon({required this.conditionId, required this.iconCode});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    if (conditionId >= 200 && conditionId <= 232) {
      icon = Icons.thunderstorm_rounded;
      color = AppColors.error;
    } else if (conditionId >= 300 && conditionId <= 531) {
      icon = Icons.grain_rounded;
      color = AppColors.warning;
    } else if (conditionId >= 600 && conditionId <= 622) {
      icon = Icons.ac_unit_rounded;
      color = AppColors.error;
    } else if (conditionId >= 700 && conditionId <= 781) {
      icon = Icons.foggy;
      color = AppColors.warning;
    } else if (conditionId == 800) {
      icon = iconCode.endsWith('n')
          ? Icons.nights_stay_rounded
          : Icons.wb_sunny_rounded;
      color = AppColors.success;
    } else {
      icon = Icons.cloud_rounded;
      color = AppColors.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _ConditionRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast
          ? null
          :  BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style:  TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 2: METAR Display
// ---------------------------------------------------------------------------

class _MetarCard extends StatelessWidget {
  final WeatherData weather;
  final String icao;

  const _MetarCard({required this.weather, required this.icao});

  @override
  Widget build(BuildContext context) {
    final metarStr = weather.toMetarString(icao);
    final catColor = _flightCategoryColor(weather.flightCategory);
    final catLabel = _flightCategoryLabel(weather.flightCategory);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
               Text(
                'METAR (Estimated)',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: catColor, width: 1),
                ),
                child: Text(
                  catLabel,
                  style: TextStyle(
                    color: catColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: catColor.withValues(alpha: 0.2)),
            ),
            child: SelectableText(
              metarStr,
              style:  TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
           Text(
            'Constructed from OpenWeatherMap data \u2014 not an official METAR.',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Color _flightCategoryColor(FlightCategory cat) {
    switch (cat) {
      case FlightCategory.vfr:
        return AppColors.success;
      case FlightCategory.mvfr:
        return AppColors.warning;
      case FlightCategory.ifr:
        return AppColors.error;
    }
  }

  String _flightCategoryLabel(FlightCategory cat) {
    switch (cat) {
      case FlightCategory.vfr:
        return 'VFR';
      case FlightCategory.mvfr:
        return 'MVFR';
      case FlightCategory.ifr:
        return 'IFR';
    }
  }
}

// ---------------------------------------------------------------------------
// METAR Decoded (human-readable line-by-line)
// ---------------------------------------------------------------------------

class _MetarDecodedCard extends StatelessWidget {
  final WeatherData weather;

  const _MetarDecodedCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final w = weather;

    // Build decoded lines
    final lines = <_DecodedLine>[];

    // Wind
    final windDirStr = w.windDirectionDeg != null
        ? '${w.windDirectionDeg}\u00B0'
        : 'Variable';
    final gustNote =
        w.windGustKt != null ? ', gusting ${w.windGustKt!.round()} kt' : '';
    lines.add(_DecodedLine(
      code: w.windDirectionDeg != null
          ? '${w.windDirectionDeg.toString().padLeft(3, '0')}${w.windSpeedKt.round().toString().padLeft(2, '0')}KT'
          : 'VRB${w.windSpeedKt.round().toString().padLeft(2, '0')}KT',
      meaning:
          'Wind from $windDirStr at ${w.windSpeedKt.round()} kt$gustNote',
      icon: Icons.air_rounded,
    ));

    // Visibility
    final visCode = w.visibilityMetres >= 9999
        ? '9999'
        : w.visibilityMetres.toString().padLeft(4, '0');
    final visText = w.visibilityMetres >= 9999
        ? '10 km or more'
        : '${w.visibilityMetres} metres';
    lines.add(_DecodedLine(
      code: visCode,
      meaning: 'Visibility $visText',
      icon: Icons.visibility_rounded,
      color: _visColor(w.visibilityMetres),
    ));

    // Clouds
    if (w.cloudLayers.isEmpty) {
      lines.add(const _DecodedLine(
        code: 'SKC',
        meaning: 'Sky clear \u2014 no cloud reported',
        icon: Icons.wb_sunny_rounded,
        color: AppColors.success,
      ));
    } else {
      for (final layer in w.cloudLayers) {
        final hundreds = (layer.heightFt / 100).round();
        final code =
            '${layer.coverage}${hundreds.toString().padLeft(3, '0')}';
        lines.add(_DecodedLine(
          code: code,
          meaning:
              '${_coverageName(layer.coverage)} at ${layer.heightFt} ft',
          icon: Icons.cloud_rounded,
          color: _cloudColor(layer.heightFt),
        ));
      }
    }

    // Temperature / Dewpoint
    lines.add(_DecodedLine(
      code:
          '${_metarTemp(w.temperature.round())}/${_metarTemp(w.dewpoint.round())}',
      meaning:
          'Temperature ${w.temperature.round()}\u00B0C, dewpoint ${w.dewpoint.round()}\u00B0C',
      icon: Icons.thermostat_rounded,
    ));

    // QNH
    lines.add(_DecodedLine(
      code: 'Q${w.pressureHpa.round()}',
      meaning: 'QNH ${w.pressureHpa.round()} hPa',
      icon: Icons.speed_rounded,
    ));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
            children: [
              Icon(Icons.translate_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Decoded',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...lines.map((line) => _DecodedLineWidget(line: line)),
        ],
      ),
    );
  }

  String _metarTemp(int temp) {
    if (temp < 0) return 'M${(-temp).toString().padLeft(2, '0')}';
    return temp.toString().padLeft(2, '0');
  }

  String _coverageName(String code) {
    switch (code) {
      case 'FEW':
        return 'Few cloud (1\u20132 oktas)';
      case 'SCT':
        return 'Scattered (3\u20134 oktas)';
      case 'BKN':
        return 'Broken (5\u20137 oktas)';
      case 'OVC':
        return 'Overcast (8 oktas)';
      case 'CLR':
        return 'Clear';
      default:
        return code;
    }
  }

  Color _visColor(int metres) {
    if (metres >= 8000) return AppColors.success;
    if (metres >= 5000) return AppColors.warning;
    return AppColors.error;
  }

  Color _cloudColor(int heightFt) {
    if (heightFt >= 3000) return AppColors.success;
    if (heightFt >= 2000) return AppColors.warning;
    return AppColors.error;
  }
}

class _DecodedLine {
  final String code;
  final String meaning;
  final IconData icon;
  final Color? color;

  const _DecodedLine({
    required this.code,
    required this.meaning,
    required this.icon,
    this.color,
  });
}

class _DecodedLineWidget extends StatelessWidget {
  final _DecodedLine line;

  const _DecodedLineWidget({required this.line});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(line.icon,
              color: line.color ?? AppColors.onSurfaceVariant, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              line.code,
              style:  TextStyle(
                color: AppColors.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.meaning,
              style: TextStyle(
                color: line.color ?? AppColors.onSurfaceVariant,
                fontSize: 12,
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
// Section 3: Crosswind Calculator
// ---------------------------------------------------------------------------

class _CrosswindCard extends StatelessWidget {
  final WeatherData weather;
  final String aircraftType;
  final String icao;
  final int? runwayHeading;
  final String? runwayLabel;
  final TextEditingController runwayController;
  final void Function(int heading, String label) onRunwayChanged;

  const _CrosswindCard({
    required this.weather,
    required this.aircraftType,
    required this.icao,
    required this.runwayHeading,
    required this.runwayLabel,
    required this.runwayController,
    required this.onRunwayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final xwindResult = runwayHeading != null
        ? weather.calculateCrosswind(runwayHeading!)
        : null;
    final xwLimit = WeatherData.crosswindLimit(aircraftType);

    // Find matching airfield runways
    final matchingRunways =
        commonUkRunways.where((r) => r.icao == icao.toUpperCase()).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aircraft crosswind limit info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.flight_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_aircraftName(aircraftType)} demonstrated crosswind limit: ${xwLimit.round()} kt',
                    style:  TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // All aircraft limits reference
          _AircraftLimitsTable(currentType: aircraftType),
          const SizedBox(height: 16),

          // Quick-select runway chips
          if (matchingRunways.isNotEmpty) ...[
             Text(
              'Select runway:',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: matchingRunways.map((r) {
                final isSelected = runwayHeading == r.heading;
                return ChoiceChip(
                  label: Text('Rwy ${r.runwayLabel}'),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.3),
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    color:
                        isSelected ? AppColors.primary : AppColors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color:
                        isSelected ? AppColors.primary : AppColors.divider,
                  ),
                  onSelected: (_) {
                    runwayController.text = r.heading.toString();
                    onRunwayChanged(r.heading, r.runwayLabel);
                    RunwayPreferences.saveRunway(r.heading, r.runwayLabel);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Manual runway heading input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: runwayController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Runway heading (e.g. 270)',
                    hintStyle:  TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixText: '\u00B0',
                    suffixStyle:  TextStyle(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  style:  TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed >= 1 && parsed <= 360) {
                      onRunwayChanged(
                        parsed,
                        (parsed ~/ 10).toString().padLeft(2, '0'),
                      );
                      RunwayPreferences.saveRunway(parsed, val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Result display
          if (xwindResult != null) ...[
            // Wind diagram
            SizedBox(
              height: 180,
              child: _WindDiagram(
                windDirection: weather.windDirectionDeg ?? 0,
                runwayHeading: runwayHeading!,
                crosswind: xwindResult,
              ),
            ),
            const SizedBox(height: 16),

            // Numeric results
            Row(
              children: [
                Expanded(
                  child: _CrosswindResultTile(
                    label: xwindResult.headwindKt >= 0
                        ? 'Headwind'
                        : 'Tailwind',
                    value: '${xwindResult.headwindKt.abs().round()} kt',
                    icon: xwindResult.headwindKt >= 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: xwindResult.headwindKt >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CrosswindResultTile(
                    label: 'Crosswind',
                    value: '${xwindResult.crosswindKt.abs().round()} kt',
                    icon: xwindResult.crosswindKt >= 0
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_back_rounded,
                    color: xwindResult.crosswindKt.abs() > xwLimit
                        ? AppColors.error
                        : xwindResult.crosswindKt.abs() > xwLimit * 0.7
                            ? AppColors.warning
                            : AppColors.success,
                    subtitle: 'Limit: ${xwLimit.round()} kt',
                  ),
                ),
              ],
            ),
            if (xwindResult.crosswindKt.abs() > xwLimit)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Crosswind exceeds ${_aircraftName(aircraftType)} '
                          'demonstrated limit of ${xwLimit.round()} kt',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ] else
             Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Enter a runway heading to calculate crosswind and '
                'headwind components.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _aircraftName(String type) {
    const names = {
      'cessna_152': 'C152',
      'cessna_172': 'C172',
      'pa28': 'PA-28',
      'da40': 'DA40',
    };
    return names[type] ?? type;
  }
}

// ---------------------------------------------------------------------------
// Aircraft limits reference table
// ---------------------------------------------------------------------------

class _AircraftLimitsTable extends StatelessWidget {
  final String currentType;

  const _AircraftLimitsTable({required this.currentType});

  @override
  Widget build(BuildContext context) {
    const aircraftLimits = [
      ('cessna_152', 'C152', 12),
      ('cessna_172', 'C172', 15),
      ('pa28', 'PA-28', 17),
      ('da40', 'DA40', 20),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Demonstrated crosswind limits:',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: aircraftLimits.map((a) {
              final isCurrent = a.$1 == currentType;
              return Column(
                children: [
                  Text(
                    a.$2,
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${a.$3} kt',
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.primary
                          : AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CrosswindResultTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _CrosswindResultTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: color.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wind Diagram (visual arrow diagram)
// ---------------------------------------------------------------------------

class _WindDiagram extends StatelessWidget {
  final int windDirection;
  final int runwayHeading;
  final CrosswindResult crosswind;

  const _WindDiagram({
    required this.windDirection,
    required this.runwayHeading,
    required this.crosswind,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 180),
      painter: _WindDiagramPainter(
        windDirection: windDirection,
        runwayHeading: runwayHeading,
        crosswind: crosswind,
      ),
    );
  }
}

class _WindDiagramPainter extends CustomPainter {
  final int windDirection;
  final int runwayHeading;
  final CrosswindResult crosswind;

  _WindDiagramPainter({
    required this.windDirection,
    required this.runwayHeading,
    required this.crosswind,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;

    // Compass circle
    final circlePaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, circlePaint);

    // Inner circle
    final innerCircle = Paint()
      ..color = AppColors.surfaceVariant
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 1, innerCircle);

    // Cardinal points
    _drawCardinalPoints(canvas, center, radius);

    // Runway line (grey)
    final rwyRad = (runwayHeading - 90) * math.pi / 180.0;
    final rwyStart =
        center + Offset(math.cos(rwyRad), math.sin(rwyRad)) * (radius * 0.7);
    final rwyEnd =
        center - Offset(math.cos(rwyRad), math.sin(rwyRad)) * (radius * 0.7);
    final rwyPaint = Paint()
      ..color = AppColors.onSurfaceVariant
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(rwyStart, rwyEnd, rwyPaint);

    // Runway number labels
    final rwyNum = (runwayHeading ~/ 10).toString().padLeft(2, '0');
    final reciprocal =
        ((runwayHeading + 180) % 360 ~/ 10).toString().padLeft(2, '0');
    _drawLabel(canvas, rwyStart, rwyNum, AppColors.onSurface);
    _drawLabel(canvas, rwyEnd, reciprocal, AppColors.onSurfaceVariant);

    // Wind arrow (orange)
    final windRad = (windDirection - 90) * math.pi / 180.0;
    final windTip = center -
        Offset(math.cos(windRad), math.sin(windRad)) * (radius * 0.5);
    final windBase = center +
        Offset(math.cos(windRad), math.sin(windRad)) * (radius * 0.8);
    final windPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(windBase, windTip, windPaint);

    // Arrowhead
    _drawArrowhead(canvas, windBase, windTip, AppColors.primary);

    // Wind label
    final windLabelPos = center +
        Offset(math.cos(windRad), math.sin(windRad)) * (radius * 0.9);
    _drawLabel(canvas, windLabelPos, 'WIND', AppColors.primary);
  }

  void _drawCardinalPoints(Canvas canvas, Offset center, double radius) {
    const points = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180.0;
      final pos =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius + 10);
      _drawLabel(canvas, pos, points[i], AppColors.onSurfaceVariant);
    }
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      pos - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Color color) {
    final direction = (to - from);
    final length = direction.distance;
    if (length == 0) return;
    final unit = direction / length;
    final normal = Offset(-unit.dy, unit.dx);

    const arrowSize = 8.0;
    final p1 = to;
    final p2 = to - unit * arrowSize + normal * arrowSize * 0.5;
    final p3 = to - unit * arrowSize - normal * arrowSize * 0.5;

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_WindDiagramPainter oldDelegate) =>
      windDirection != oldDelegate.windDirection ||
      runwayHeading != oldDelegate.runwayHeading;
}

// ---------------------------------------------------------------------------
// Section 4: Go/No-Go
// ---------------------------------------------------------------------------

class _GoNoGoBanner extends StatelessWidget {
  final GoNoGoAssessment assessment;

  const _GoNoGoBanner({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String subtitle;
    switch (assessment.overall) {
      case GoNoGoStatus.good:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        subtitle = 'Conditions look suitable for training';
      case GoNoGoStatus.marginal:
        color = AppColors.warning;
        icon = Icons.warning_rounded;
        subtitle = 'Some factors need attention \u2014 discuss with your instructor';
      case GoNoGoStatus.notSuitable:
        color = AppColors.error;
        icon = Icons.cancel_rounded;
        subtitle = 'One or more factors exceed student limits';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.summary,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.3,
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

class _GoNoGoFactorsCard extends StatelessWidget {
  final GoNoGoAssessment assessment;
  final String aircraftType;

  const _GoNoGoFactorsCard({
    required this.assessment,
    required this.aircraftType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
            children: [
              Icon(Icons.checklist_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Factor Checklist',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
           Text(
            'Each factor is assessed against student PPL limits:',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),

          // Threshold legend
          _ThresholdLegend(),
          const SizedBox(height: 12),

          // Factors
          ...assessment.factors.map(
            (f) => _FactorRow(factor: f),
          ),

          const SizedBox(height: 12),
          // Instructor disclaimer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Always consult your instructor for the final go/no-go decision.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          _LegendItem(
            color: AppColors.success,
            label: 'Good to fly',
            detail: 'Vis >5 km, ceiling >2 000 ft, wind within limits',
          ),
          SizedBox(height: 4),
          _LegendItem(
            color: AppColors.warning,
            label: 'Marginal',
            detail: 'Vis 5\u20138 km, ceiling 2 000\u20133 000 ft, crosswind 70\u2013100% of limit',
          ),
          SizedBox(height: 4),
          _LegendItem(
            color: AppColors.error,
            label: 'Not recommended',
            detail: 'Vis <5 km, ceiling <2 000 ft, crosswind >limit, CB/TS',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String detail;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: detail,
                  style:  TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  final WeatherFactor factor;

  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (factor.status) {
      case FactorStatus.green:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
      case FactorStatus.amber:
        color = AppColors.warning;
        icon = Icons.warning_rounded;
      case FactorStatus.red:
        color = AppColors.error;
        icon = Icons.cancel_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.name,
                  style:  TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  factor.value,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
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
// Sunrise/Sunset Card
// ---------------------------------------------------------------------------

class _SunTimesCard extends StatelessWidget {
  final WeatherData weather;

  const _SunTimesCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    final sunrise = weather.sunrise != null
        ? fmt.format(weather.sunrise!.toLocal())
        : '--:--';
    final sunset = weather.sunset != null
        ? fmt.format(weather.sunset!.toLocal())
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.wb_twilight_rounded,
              color: AppColors.warning, size: 24),
          const SizedBox(height: 8),
           Text(
            'Sun Times',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wb_sunny_rounded,
                  color: AppColors.warning, size: 14),
              const SizedBox(width: 4),
              Text(
                sunrise,
                style:  TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(Icons.nights_stay_rounded,
                  color: AppColors.onSurfaceVariant, size: 14),
              const SizedBox(width: 4),
              Text(
                sunset,
                style:  TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend Card
// ---------------------------------------------------------------------------

class _TrendCard extends StatelessWidget {
  final WeatherData weather;

  const _TrendCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (weather.trendIcon) {
      case 'trending_up':
        icon = Icons.trending_up_rounded;
      case 'trending_flat':
        icon = Icons.trending_flat_rounded;
      default:
        icon = Icons.trending_down_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
           Text(
            'Trend',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            weather.trendDescription,
            textAlign: TextAlign.center,
            style:  TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
