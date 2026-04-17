// Airfield data model — used by the Airfield Info tool screen.
// All fields are final; the [hasData] flag controls whether detail is shown.

/// A single runway designator with basic physical properties.
class AirfieldRunway {
  final String designator; // e.g. "03/21"
  final int lengthMetres;
  final String surface; // "Grass" / "Asphalt" / "Concrete"

  const AirfieldRunway({
    required this.designator,
    required this.lengthMetres,
    required this.surface,
  });
}

/// A named radio frequency at an airfield.
class AirfieldFrequency {
  final String name; // e.g. "Cranfield Radio"
  final String frequency; // e.g. "122.850"
  final String usage; // e.g. "AGCS — all calls"

  const AirfieldFrequency({
    required this.name,
    required this.frequency,
    required this.usage,
  });
}

/// Full airfield record.
///
/// When [hasData] is false the detail view renders a "coming soon" placeholder
/// and the data fields below should be treated as empty/zero.
class Airfield {
  final String icao;
  final String name;
  final String location; // e.g. "Cranfield, Bedfordshire"
  final int elevation; // feet AMSL
  final String atzDescription; // e.g. "2nm radius, surface to 2000ft QFE"
  final List<AirfieldRunway> runways;
  final List<AirfieldFrequency> frequencies;
  final String circuitDirection; // "Left hand" / "Right hand" / "See notes"
  final int circuitAltitude; // feet QFE
  final String localRules; // free text — notable local procedures
  final String commonStudentMistakes; // free text
  final bool hasData; // false = coming soon placeholder

  const Airfield({
    required this.icao,
    required this.name,
    required this.location,
    required this.elevation,
    required this.atzDescription,
    required this.runways,
    required this.frequencies,
    required this.circuitDirection,
    required this.circuitAltitude,
    required this.localRules,
    required this.commonStudentMistakes,
    required this.hasData,
  });
}
