// Pure-Dart navigation maths for PLOG (navigation log) route planning.
// No Flutter dependencies — keep this file framework-agnostic for easy unit testing.
import 'dart:math' as math;

/// Result record returned by [PlogCalculator.calculate].
typedef PlogResult = ({
  int heading,
  int groundspeed,
  double etaMinutes,
  double wca,
});

/// Static utility class that performs the velocity-triangle calculations
/// required for Exercise 18A (Navigation) route leg planning.
///
/// All angle inputs are in degrees. Internal trig uses radians.
class PlogCalculator {
  PlogCalculator._();

  /// Calculate heading, groundspeed, ETA and wind correction angle for a
  /// single route leg.
  ///
  /// - [track]     Track to make good (°M, 0–360)
  /// - [distance]  Leg distance (nm, >0)
  /// - [tas]       True airspeed (kt, >0)
  /// - [windFrom]  Wind direction FROM (°M, 0–360)
  /// - [windSpeed] Wind speed (kt, ≥0)
  static PlogResult calculate({
    required int track,
    required double distance,
    required int tas,
    required int windFrom,
    required int windSpeed,
  }) {
    const toRad = math.pi / 180.0;

    // Wind direction = where the wind is blowing TO (reciprocal of "from").
    final double windAngle = (windFrom + 180.0) % 360.0;

    // Angle between the wind vector and the intended track.
    final double relativeAngle = windAngle - track;

    // Wind correction angle (positive = wind from right = steer right).
    final double wcaRad =
        math.asin((windSpeed / tas.toDouble()) * math.sin(relativeAngle * toRad));
    final double wcaDeg = wcaRad * 180.0 / math.pi;

    // Heading = track adjusted by WCA.
    final double headingRaw = (track + wcaDeg + 360.0) % 360.0;
    final int heading = headingRaw.round() % 360;

    // Groundspeed via cosine rule on the velocity triangle.
    final double headingToWindAngle = windAngle - headingRaw;
    double gs = math.sqrt(
      tas * tas +
          windSpeed * windSpeed -
          2.0 * tas * windSpeed * math.cos(headingToWindAngle * toRad),
    );
    gs = gs.clamp(1.0, 999.0);

    final int groundspeed = gs.round();

    // ETA in minutes.
    final double etaMinutes = (distance / gs) * 60.0;

    return (
      heading: heading,
      groundspeed: groundspeed,
      etaMinutes: etaMinutes,
      wca: wcaDeg,
    );
  }
}
