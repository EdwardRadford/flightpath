// Weather service — fetches current conditions via a Firebase Cloud Function
// that proxies the OpenWeatherMap API.
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when the weather service cannot retrieve or parse data.
class WeatherServiceException implements Exception {
  final String message;
  const WeatherServiceException(this.message);

  @override
  String toString() => 'WeatherServiceException: $message';
}

// ---------------------------------------------------------------------------
// Cloud layer model
// ---------------------------------------------------------------------------

/// A single cloud layer from the OpenWeatherMap response.
class CloudLayer {
  /// Coverage abbreviation: FEW, SCT, BKN, OVC, CLR.
  final String coverage;

  /// Cloud base height in feet AGL (converted from metres).
  final int heightFt;

  const CloudLayer({required this.coverage, required this.heightFt});

  /// Human-readable label, e.g. "BKN 2 500 ft".
  String get label {
    final formatted = _formatAltitude(heightFt);
    return '$coverage $formatted ft';
  }

  static String _formatAltitude(int ft) {
    if (ft >= 1000) {
      // Aviation convention: "2 500", "10 000"
      final str = ft.toString();
      final buf = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
        buf.write(str[i]);
      }
      return buf.toString();
    }
    return ft.toString();
  }
}

// ---------------------------------------------------------------------------
// Crosswind result
// ---------------------------------------------------------------------------

/// Result of a crosswind calculation.
class CrosswindResult {
  /// Crosswind component in knots (positive = from the right).
  final double crosswindKt;

  /// Headwind component in knots (positive = headwind, negative = tailwind).
  final double headwindKt;

  /// The angle between the wind and the runway, in degrees.
  final double angleDeg;

  const CrosswindResult({
    required this.crosswindKt,
    required this.headwindKt,
    required this.angleDeg,
  });
}

// ---------------------------------------------------------------------------
// Go/No-Go assessment
// ---------------------------------------------------------------------------

/// Status of an individual weather factor.
enum FactorStatus { green, amber, red }

/// A single factor in the go/no-go assessment.
class WeatherFactor {
  final String name;
  final String value;
  final FactorStatus status;

  const WeatherFactor({
    required this.name,
    required this.value,
    required this.status,
  });
}

/// Overall go/no-go recommendation.
enum GoNoGoStatus { good, marginal, notSuitable }

/// Full go/no-go assessment with individual factors.
class GoNoGoAssessment {
  final GoNoGoStatus overall;
  final String summary;
  final List<WeatherFactor> factors;

  const GoNoGoAssessment({
    required this.overall,
    required this.summary,
    required this.factors,
  });
}

// ---------------------------------------------------------------------------
// Flight condition category
// ---------------------------------------------------------------------------

/// VFR flight condition category.
enum FlightCategory { vfr, mvfr, ifr }

// ---------------------------------------------------------------------------
// Weather data model
// ---------------------------------------------------------------------------

/// Parsed weather data returned by [WeatherService].
class WeatherData {
  /// Human-readable weather condition, e.g. "Broken cloud".
  final String conditions;

  /// OpenWeatherMap weather condition ID (for thunderstorm detection etc).
  final int conditionId;

  /// Temperature in degrees Celsius.
  final double temperature;

  /// Dewpoint in degrees Celsius.
  final double dewpoint;

  /// Wind speed expressed as a knot value string, e.g. "12 kt".
  final String windSpeed;

  /// Wind speed as a raw numeric value in knots (for storage).
  final double windSpeedKt;

  /// Wind gust speed in knots, or null if no gust reported.
  final double? windGustKt;

  /// Wind direction in degrees (0–360), or null if unavailable.
  final int? windDirectionDeg;

  /// Visibility string, e.g. ">10 km" or "4.2 km".
  final String visibility;

  /// Visibility in metres (for storage).
  final int visibilityMetres;

  /// QNH / sea-level pressure in hPa.
  final double pressureHpa;

  /// Cloud layers parsed from the response.
  final List<CloudLayer> cloudLayers;

  /// Lowest cloud base in feet, or null if sky clear.
  final int? lowestCloudBaseFt;

  /// OpenWeatherMap icon code, e.g. "04d".
  final String iconCode;

  /// Sunrise time (UTC), or null if unavailable.
  final DateTime? sunrise;

  /// Sunset time (UTC), or null if unavailable.
  final DateTime? sunset;

  /// True when conditions are broadly suitable for a lesson:
  /// visibility >= 5 000 m AND wind speed < 25 kt.
  final bool isSuitable;

  /// Flight category based on visibility and cloud base.
  final FlightCategory flightCategory;

  const WeatherData({
    required this.conditions,
    required this.conditionId,
    required this.temperature,
    required this.dewpoint,
    required this.windSpeed,
    required this.windSpeedKt,
    this.windGustKt,
    this.windDirectionDeg,
    required this.visibility,
    required this.visibilityMetres,
    required this.pressureHpa,
    required this.cloudLayers,
    this.lowestCloudBaseFt,
    required this.iconCode,
    this.sunrise,
    this.sunset,
    required this.isSuitable,
    required this.flightCategory,
  });

  /// Parses the normalised JSON object returned by the `getWeather`
  /// Cloud Function (sourced from AVWX METAR data).
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    // --- Conditions ---
    final conditions = _capitalise((json['conditions'] as String?) ?? 'Unknown');
    final conditionId = (json['condition_code'] as num?)?.toInt() ?? 800;

    // --- Temperature & Dewpoint ---
    final temperature = (json['temperature'] as num?)?.toDouble() ?? 0.0;
    final dewpoint = (json['dewpoint'] as num?)?.toDouble() ?? (temperature - 5.0);

    // --- Pressure ---
    final pressureHpa = (json['pressure_hpa'] as num?)?.toDouble() ?? 1013.25;

    // --- Wind (already in knots) ---
    final windKt = (json['wind_speed_kt'] as num?)?.toDouble() ?? 0.0;
    final gustKt = (json['wind_gust_kt'] as num?)?.toDouble();
    final windDeg = (json['wind_direction_deg'] as num?)?.toInt();
    final windSpeedStr = '${windKt.round()} kt';

    // --- Visibility (metres) ---
    final visMeters = (json['visibility_m'] as num?)?.toInt() ?? 0;
    final visibilityStr = visMeters >= 10000
        ? '>10 km'
        : '${(visMeters / 1000).toStringAsFixed(1)} km';

    // --- Cloud layers ---
    final cloudsRaw = json['clouds'] as List<dynamic>? ?? [];
    final List<CloudLayer> cloudLayers = cloudsRaw.map((c) {
      final cloud = c as Map<String, dynamic>;
      return CloudLayer(
        coverage: (cloud['coverage'] as String?) ?? 'FEW',
        heightFt: (cloud['height_ft'] as num?)?.toInt() ?? 0,
      );
    }).toList()
      ..sort((a, b) => a.heightFt.compareTo(b.heightFt));

    final lowestBase = cloudLayers.isNotEmpty ? cloudLayers.first.heightFt : null;

    // --- Flight category ---
    final flightCat = _determineFlightCategory(visMeters, lowestBase);

    // --- Suitability ---
    final suitable = windKt < 25 && visMeters >= 5000;

    return WeatherData(
      conditions: conditions,
      conditionId: conditionId,
      temperature: temperature,
      dewpoint: dewpoint,
      windSpeed: windSpeedStr,
      windSpeedKt: windKt,
      windGustKt: gustKt,
      windDirectionDeg: windDeg,
      visibility: visibilityStr,
      visibilityMetres: visMeters,
      pressureHpa: pressureHpa,
      cloudLayers: cloudLayers,
      lowestCloudBaseFt: lowestBase,
      iconCode: '',
      sunrise: null,
      sunset: null,
      isSuitable: suitable,
      flightCategory: flightCat,
    );
  }

  // ---- Pseudo-METAR generator ----

  /// Builds a METAR-style string from the weather data.
  String toMetarString(String icao) {
    final buf = StringBuffer();
    buf.write(icao.toUpperCase());
    buf.write(' ');

    // Time (Zulu)
    final now = DateTime.now().toUtc();
    buf.write(
      '${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}Z ',
    );

    // Wind
    if (windDirectionDeg != null) {
      buf.write(
        '${windDirectionDeg.toString().padLeft(3, '0')}'
        '${windSpeedKt.round().toString().padLeft(2, '0')}',
      );
      if (windGustKt != null && windGustKt! > windSpeedKt + 5) {
        buf.write('G${windGustKt!.round().toString().padLeft(2, '0')}');
      }
      buf.write('KT ');
    } else {
      buf.write('VRB${windSpeedKt.round().toString().padLeft(2, '0')}KT ');
    }

    // Visibility (metres, METAR style)
    if (visibilityMetres >= 9999) {
      buf.write('9999 ');
    } else {
      buf.write('${visibilityMetres.toString().padLeft(4, '0')} ');
    }

    // Clouds
    if (cloudLayers.isEmpty) {
      buf.write('SKC ');
    } else {
      for (final layer in cloudLayers) {
        // METAR uses hundreds of feet, 3 digits
        final hundreds = (layer.heightFt / 100).round();
        buf.write(
          '${layer.coverage}${hundreds.toString().padLeft(3, '0')} ',
        );
      }
    }

    // Temp / Dewpoint
    buf.write(
      '${_metarTemp(temperature.round())}/'
      '${_metarTemp(dewpoint.round())} ',
    );

    // QNH
    buf.write('Q${pressureHpa.round()}');

    return buf.toString();
  }

  static String _metarTemp(int temp) {
    if (temp < 0) return 'M${(-temp).toString().padLeft(2, '0')}';
    return temp.toString().padLeft(2, '0');
  }

  // ---- Crosswind calculator ----

  /// Calculates crosswind and headwind components for the given [runwayHeading].
  CrosswindResult? calculateCrosswind(int runwayHeading) {
    if (windDirectionDeg == null) return null;

    final windAngle = windDirectionDeg!.toDouble();
    final rwyHdg = runwayHeading.toDouble();
    final diff = (windAngle - rwyHdg) * math.pi / 180.0;

    final effectiveSpeed = windGustKt ?? windSpeedKt;
    final crosswind = effectiveSpeed * math.sin(diff);
    final headwind = effectiveSpeed * math.cos(diff);

    // Normalise angle difference to -180..180
    var angleDiff = windAngle - rwyHdg;
    while (angleDiff > 180) {
      angleDiff -= 360;
    }
    while (angleDiff < -180) {
      angleDiff += 360;
    }

    return CrosswindResult(
      crosswindKt: crosswind,
      headwindKt: headwind,
      angleDeg: angleDiff,
    );
  }

  // ---- Go/No-Go assessment ----

  /// Produces a full go/no-go assessment for a student pilot in the given
  /// [aircraftType] with optional [runwayHeading].
  GoNoGoAssessment assessGoNoGo({
    required String aircraftType,
    int? runwayHeading,
  }) {
    final factors = <WeatherFactor>[];
    var worstStatus = FactorStatus.green;

    void addFactor(WeatherFactor f) {
      factors.add(f);
      if (f.status.index > worstStatus.index) worstStatus = f.status;
    }

    // 1. Wind speed (student limit: 15 kt)
    final windStatus = windSpeedKt <= 12
        ? FactorStatus.green
        : windSpeedKt <= 15
            ? FactorStatus.amber
            : FactorStatus.red;
    addFactor(WeatherFactor(
      name: 'Wind speed',
      value: '${windSpeedKt.round()} kt (limit: 15 kt)',
      status: windStatus,
    ));

    // 2. Wind gust
    if (windGustKt != null) {
      final gustStatus = windGustKt! <= 15
          ? FactorStatus.green
          : windGustKt! <= 20
              ? FactorStatus.amber
              : FactorStatus.red;
      addFactor(WeatherFactor(
        name: 'Gusts',
        value: '${windGustKt!.round()} kt',
        status: gustStatus,
      ));
    }

    // 3. Crosswind (if runway heading available)
    if (runwayHeading != null) {
      final xwind = calculateCrosswind(runwayHeading);
      if (xwind != null) {
        final xwLimit = crosswindLimit(aircraftType);
        final absXw = xwind.crosswindKt.abs();
        final xwStatus = absXw <= xwLimit * 0.7
            ? FactorStatus.green
            : absXw <= xwLimit
                ? FactorStatus.amber
                : FactorStatus.red;
        addFactor(WeatherFactor(
          name: 'Crosswind',
          value: '${absXw.round()} kt (limit: ${xwLimit.round()} kt)',
          status: xwStatus,
        ));

        // Headwind/tailwind
        if (xwind.headwindKt < 0) {
          final tailwind = xwind.headwindKt.abs();
          final twStatus = tailwind <= 5
              ? FactorStatus.amber
              : FactorStatus.red;
          addFactor(WeatherFactor(
            name: 'Tailwind',
            value: '${tailwind.round()} kt',
            status: twStatus,
          ));
        }
      }
    }

    // 4. Visibility (student limit: >5 km)
    final visKm = visibilityMetres / 1000.0;
    final visStatus = visKm >= 8
        ? FactorStatus.green
        : visKm >= 5
            ? FactorStatus.amber
            : FactorStatus.red;
    addFactor(WeatherFactor(
      name: 'Visibility',
      value: '$visibility (limit: 5 km)',
      status: visStatus,
    ));

    // 5. Cloud base (student limit: >2000 ft)
    if (lowestCloudBaseFt != null) {
      final cbStatus = lowestCloudBaseFt! >= 3000
          ? FactorStatus.green
          : lowestCloudBaseFt! >= 2000
              ? FactorStatus.amber
              : FactorStatus.red;
      addFactor(WeatherFactor(
        name: 'Cloud base',
        value: '${lowestCloudBaseFt!} ft (limit: 2 000 ft)',
        status: cbStatus,
      ));
    }

    // 6. Thunderstorms (condition IDs 200-232)
    final hasThunderstorm =
        conditionId >= 200 && conditionId <= 232;
    if (hasThunderstorm) {
      addFactor(const WeatherFactor(
        name: 'Thunderstorms',
        value: 'Active',
        status: FactorStatus.red,
      ));
    }

    // 7. Precipitation
    final hasPrecipitation =
        (conditionId >= 300 && conditionId <= 321) || // drizzle
        (conditionId >= 500 && conditionId <= 531) || // rain
        (conditionId >= 600 && conditionId <= 622);   // snow
    if (hasPrecipitation) {
      final precipStatus =
          conditionId >= 600 ? FactorStatus.red : FactorStatus.amber;
      addFactor(WeatherFactor(
        name: 'Precipitation',
        value: conditions,
        status: precipStatus,
      ));
    }

    // Determine overall
    final GoNoGoStatus overall;
    final String summary;
    if (worstStatus == FactorStatus.red) {
      overall = GoNoGoStatus.notSuitable;
      summary = 'Not suitable for training';
    } else if (worstStatus == FactorStatus.amber) {
      overall = GoNoGoStatus.marginal;
      summary = 'Marginal — discuss with instructor';
    } else {
      overall = GoNoGoStatus.good;
      summary = 'Good to fly';
    }

    return GoNoGoAssessment(
      overall: overall,
      summary: summary,
      factors: factors,
    );
  }

  /// Returns the demonstrated crosswind limit in knots for the given aircraft.
  static double crosswindLimit(String aircraftType) {
    switch (aircraftType) {
      case 'cessna_152':
        return 12;
      case 'cessna_172':
        return 15;
      case 'pa28':
        return 17;
      case 'da40':
        return 20;
      default:
        return 12; // conservative default
    }
  }

  // ---- Trend estimation ----

  /// Rough trend based on pressure. In a real app this would compare multiple
  /// data points; with a single observation we use the pressure tendency hint.
  String get trendDescription {
    if (pressureHpa >= 1020) return 'Stable / high pressure';
    if (pressureHpa >= 1013) return 'Stable';
    if (pressureHpa >= 1005) return 'Possibly deteriorating';
    return 'Low pressure — conditions may be poor';
  }

  String get trendIcon {
    if (pressureHpa >= 1020) return 'trending_up';
    if (pressureHpa >= 1013) return 'trending_flat';
    return 'trending_down';
  }

  // ---- Helpers ----

  static String _capitalise(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Maps an OWM cloud coverage percentage to a METAR abbreviation.
  static String _mapCloudCoverage(int pct) {
    if (pct <= 0) return 'CLR';
    if (pct <= 25) return 'FEW';
    if (pct <= 50) return 'SCT';
    if (pct <= 87) return 'BKN';
    return 'OVC';
  }

  /// Estimates cloud height in feet from the OWM condition code when the API
  /// doesn't provide explicit layer heights (free tier).
  static int _estimateCloudHeight(int conditionId, int visMetres) {
    // Fog / mist → very low
    if (conditionId >= 700 && conditionId <= 762) return 500;
    // Thunderstorm → moderate base
    if (conditionId >= 200 && conditionId <= 232) return 2000;
    // Rain / drizzle → 1500–3000 depending on visibility
    if ((conditionId >= 300 && conditionId <= 321) ||
        (conditionId >= 500 && conditionId <= 531)) {
      return visMetres < 5000 ? 1500 : 3000;
    }
    // Snow
    if (conditionId >= 600 && conditionId <= 622) return 1000;
    // Overcast
    if (conditionId == 804) return 3000;
    // Broken
    if (conditionId == 803) return 3500;
    // Scattered / few
    if (conditionId == 802) return 4000;
    if (conditionId == 801) return 5000;
    // Clear
    return 10000;
  }

  /// Determines the flight category from visibility and cloud base.
  static FlightCategory _determineFlightCategory(
    int visMetres,
    int? lowestBaseFt,
  ) {
    final baseFt = lowestBaseFt ?? 99999;
    // IFR: vis < 3 SM (≈4800 m) OR ceiling < 1000 ft
    if (visMetres < 4800 || baseFt < 1000) return FlightCategory.ifr;
    // MVFR: vis 3–5 SM (4800–8000 m) OR ceiling 1000–3000 ft
    if (visMetres < 8000 || baseFt < 3000) return FlightCategory.mvfr;
    return FlightCategory.vfr;
  }
}

// ---------------------------------------------------------------------------
// Runway preferences
// ---------------------------------------------------------------------------

/// Persists the user's preferred runway heading for crosswind calculations.
class RunwayPreferences {
  static const _keyRunwayHeading = 'weather_runway_heading';
  static const _keyRunwayLabel = 'weather_runway_label';

  /// Loads the saved runway heading, or null if none saved.
  static Future<int?> getRunwayHeading() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyRunwayHeading);
  }

  /// Loads the saved runway label, e.g. "08/26".
  static Future<String?> getRunwayLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRunwayLabel);
  }

  /// Saves the user's preferred runway heading and label.
  static Future<void> saveRunway(int heading, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRunwayHeading, heading);
    await prefs.setString(_keyRunwayLabel, label);
  }
}

// ---------------------------------------------------------------------------
// Common UK training airfield runways
// ---------------------------------------------------------------------------

/// A predefined runway at a common UK training airfield.
class AirfieldRunway {
  final String airfieldName;
  final String icao;
  final String runwayLabel;
  final int heading;

  const AirfieldRunway({
    required this.airfieldName,
    required this.icao,
    required this.runwayLabel,
    required this.heading,
  });
}

/// Common UK training airfield runways for quick selection.
const List<AirfieldRunway> commonUkRunways = [
  AirfieldRunway(airfieldName: 'Bournemouth', icao: 'EGHH', runwayLabel: '08/26', heading: 80),
  AirfieldRunway(airfieldName: 'Cranfield', icao: 'EGTC', runwayLabel: '03/21', heading: 30),
  AirfieldRunway(airfieldName: 'Elstree', icao: 'EGTR', runwayLabel: '08/26', heading: 80),
  AirfieldRunway(airfieldName: 'Gloucester', icao: 'EGBJ', runwayLabel: '09/27', heading: 90),
  AirfieldRunway(airfieldName: 'Goodwood', icao: 'EGHR', runwayLabel: '06/24', heading: 60),
  AirfieldRunway(airfieldName: 'Kemble', icao: 'EGBP', runwayLabel: '08/26', heading: 80),
  AirfieldRunway(airfieldName: 'Leeds Bradford', icao: 'EGNM', runwayLabel: '14/32', heading: 140),
  AirfieldRunway(airfieldName: 'Old Sarum', icao: 'EGLS', runwayLabel: '06/24', heading: 60),
  AirfieldRunway(airfieldName: 'Oxford', icao: 'EGTK', runwayLabel: '01/19', heading: 10),
  AirfieldRunway(airfieldName: 'Shobdon', icao: 'EGBS', runwayLabel: '09/27', heading: 90),
  AirfieldRunway(airfieldName: 'Shoreham', icao: 'EGKA', runwayLabel: '02/20', heading: 20),
  AirfieldRunway(airfieldName: 'Stapleford', icao: 'EGSG', runwayLabel: '04/22', heading: 40),
  AirfieldRunway(airfieldName: 'Thruxton', icao: 'EGHO', runwayLabel: '07/25', heading: 70),
  AirfieldRunway(airfieldName: 'White Waltham', icao: 'EGLM', runwayLabel: '03/21', heading: 30),
  AirfieldRunway(airfieldName: 'Wycombe Air Park', icao: 'EGTB', runwayLabel: '06/24', heading: 60),
];

// ---------------------------------------------------------------------------
// Weather service
// ---------------------------------------------------------------------------

/// Retrieves current weather data via the `getWeather` Firebase Cloud Function.
///
/// The Cloud Function proxies the OpenWeatherMap API so that the API key is
/// never shipped inside the app binary.
class WeatherService {
  /// Cloud Function instance targeting the `europe-west2` region where
  /// `getWeather` is deployed.
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );

  /// Client-side rate limit: minimum interval between weather Cloud Function calls.
  DateTime? _lastCallTime;
  static const _minCallInterval = Duration(seconds: 10);

  /// Fetches current weather for [icaoCode] (e.g. "EGLL") by invoking the
  /// `getWeather` Cloud Function.
  ///
  /// Throws [WeatherServiceException] on network, auth, or parsing failure.
  Future<WeatherData> getWeatherForAirfield(String icaoCode) async {
    // --- Client-side rate limit ---
    final now = DateTime.now();
    if (_lastCallTime != null &&
        now.difference(_lastCallTime!) < _minCallInterval) {
      throw const WeatherServiceException(
        'Please wait a moment before checking the weather again.',
      );
    }
    _lastCallTime = now;

    // --- Validate ICAO code format (4 alpha chars) before sending ---
    final sanitisedCode = icaoCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{4}$').hasMatch(sanitisedCode)) {
      throw const WeatherServiceException(
        'Invalid ICAO code. Must be exactly 4 letters (e.g. EGHH).',
      );
    }

    late HttpsCallableResult result;
    try {
      final callable = _functions.httpsCallable(
        'getWeather',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      result = await callable.call({'icaoCode': sanitisedCode});
    } on FirebaseFunctionsException catch (e) {
      throw WeatherServiceException(
        _mapFunctionsError(e, sanitisedCode),
      );
    } catch (e) {
      throw WeatherServiceException(
        'Network error fetching weather for "$sanitisedCode": $e',
      );
    }

    // The Cloud Function returns the raw OpenWeatherMap JSON object.
    final data = result.data;
    if (data == null) {
      throw const WeatherServiceException(
        'Weather service returned an empty response.',
      );
    }

    try {
      return WeatherData.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      throw WeatherServiceException(
        'Failed to map weather response to WeatherData: $e',
      );
    }
  }

  /// Translates a [FirebaseFunctionsException] into a user-readable message.
  String _mapFunctionsError(
    FirebaseFunctionsException e,
    String icaoCode,
  ) {
    switch (e.code) {
      case 'unauthenticated':
        return 'You must be signed in to fetch weather data.';
      case 'not-found':
        return 'No weather data found for "$icaoCode". '
            'Check the ICAO code is correct and try again.';
      case 'invalid-argument':
        return e.message ?? 'Invalid ICAO code supplied.';
      case 'unavailable':
        return 'Weather service is temporarily unavailable. '
            'Please try again shortly.';
      case 'resource-exhausted':
        return 'Weather service is busy. Please try again in a moment.';
      default:
        return 'Failed to retrieve weather for "$icaoCode" '
            '(${e.code}). Please try again.';
    }
  }
}
