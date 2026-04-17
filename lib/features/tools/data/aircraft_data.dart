// Static performance data for common UK PPL training aircraft.
//
// All figures are typical published values drawn from manufacturer POH/AFM
// documents and are for reference and study purposes only. They are NOT a
// substitute for the aircraft-specific POH/AFM — always use the correct
// document for the actual aircraft you are flying.
//
// Sources: Piper PA-28 POH (various), Cessna 152/172 POH (various),
// Robin DR400-160 POH, Grob G115E Flight Manual, Tecnam P2002 Sierra POH,
// Diamond DA20-C1 POH, Diamond DA40-180 AFM, Slingsby T67C POH.

/// Performance data for a single aircraft type.
class AircraftData {
  /// Key matching [AppConstants.aircraftTypes] — used to look up by profile type.
  final String type;

  /// Human-readable aircraft name, e.g. "PA-28-161 Warrior II".
  final String displayName;

  /// Engine description, e.g. "Lycoming O-320-D3G, 160 hp".
  final String engine;

  // ── Speeds (KIAS unless noted) ──────────────────────────────────────────

  /// VNE — never exceed speed.
  final int vne;

  /// VNO — maximum structural cruising speed.
  final int vno;

  /// VA — manoeuvring speed at MTOW.
  final int va;

  /// VFE — maximum speed with flaps extended.
  final int vfe;

  /// VY — best rate of climb.
  final int vy;

  /// VX — best angle of climb.
  final int vx;

  /// VS1 — stall speed in clean configuration.
  final int vs1;

  /// VS0 — stall speed in landing configuration.
  final int vs0;

  /// Normal approach speed (full flap).
  final int approachSpeed;

  /// Best glide speed (engine out).
  final int bestGlide;

  // ── Performance ─────────────────────────────────────────────────────────

  /// Typical cruise TAS at 75 % power, ft, ISA.
  final int cruiseTas;

  /// Typical cruise fuel burn in US gal/hr at 75 % power.
  final double fuelBurnGph;

  /// Service ceiling in feet.
  final int serviceCeiling;

  /// Rate of climb at sea level, MTOW, ISA (fpm).
  final int climbRate;

  // ── Field performance (ISA, sea level, MTOW) — metres ───────────────────

  /// Takeoff ground roll (metres).
  final int takeoffGroundRoll;

  /// Takeoff distance to clear 50 ft obstacle (metres).
  final int takeoffOver50ft;

  /// Landing ground roll (metres).
  final int landingGroundRoll;

  /// Landing distance over 50 ft obstacle (metres).
  final int landingOver50ft;

  // ── Weights ─────────────────────────────────────────────────────────────

  /// Maximum take-off weight (kg).
  final int mtow;

  /// Useful load (kg) — MTOW minus basic empty weight.
  final int usefulLoad;

  // ── Type-specific notes ──────────────────────────────────────────────────

  /// Any important type-specific notes or handling quirks.
  final String notes;

  const AircraftData({
    required this.type,
    required this.displayName,
    required this.engine,
    required this.vne,
    required this.vno,
    required this.va,
    required this.vfe,
    required this.vy,
    required this.vx,
    required this.vs1,
    required this.vs0,
    required this.approachSpeed,
    required this.bestGlide,
    required this.cruiseTas,
    required this.fuelBurnGph,
    required this.serviceCeiling,
    required this.climbRate,
    required this.takeoffGroundRoll,
    required this.takeoffOver50ft,
    required this.landingGroundRoll,
    required this.landingOver50ft,
    required this.mtow,
    required this.usefulLoad,
    required this.notes,
  });

  /// Fuel burn converted to litres per hour (1 US gal = 3.785 L).
  double get fuelBurnLph => fuelBurnGph * 3.785;
}

/// Disclaimer that must be shown prominently on every data sheet.
const String kAircraftDataDisclaimer =
    'Performance figures are typical published values for reference only. '
    'Always use your aircraft\'s specific POH/AFM for flight planning. '
    'Figures vary by aircraft registration, condition, and configuration.';

/// Full catalogue of supported aircraft types.
///
/// Keys match [AppConstants.aircraftTypes]. Add new types here and the
/// [AircraftDataScreen] will pick them up automatically.
const List<AircraftData> kAircraftDataList = [
  // ── Cessna 152 ────────────────────────────────────────────────────────────
  // Source: Cessna 152 POH (1979 baseline, Lycoming O-235-L2C variant)
  AircraftData(
    type: 'cessna_152',
    displayName: 'Cessna 152',
    engine: 'Lycoming O-235-L2C, 110 hp',
    vne: 149,
    vno: 111,
    va: 104, // at 757 kg MTOW
    vfe: 85,
    vy: 67,
    vx: 54,
    vs1: 48,
    vs0: 40,
    approachSpeed: 54, // Vref full flap per Cessna 152 POH
    bestGlide: 60,
    cruiseTas: 90,
    fuelBurnGph: 6.1,
    serviceCeiling: 14700,
    climbRate: 715,
    takeoffGroundRoll: 198,
    takeoffOver50ft: 335,
    landingGroundRoll: 152,
    landingOver50ft: 327,
    mtow: 757,
    usefulLoad: 272,
    notes:
        'Carburettor heat essential in cruise descent and during power reductions. '
        'Mixture lean above ~3,000 ft density altitude. '
        'Full-span flaps — use 10° for short-field takeoff. '
        'Climb performance noticeably reduced on hot/high days.',
  ),

  // ── Cessna 172S Skyhawk ───────────────────────────────────────────────────
  // Source: Cessna 172S POH (Lycoming IO-360-L2A, 180 hp, 1998+)
  AircraftData(
    type: 'cessna_172',
    displayName: 'Cessna 172S Skyhawk',
    engine: 'Lycoming IO-360-L2A, 180 hp',
    vne: 163,
    vno: 129,
    va: 105, // at 1111 kg MTOW
    vfe: 85, // 10° flap; full-flap limit 85 kt too
    vy: 76,
    vx: 62,
    vs1: 54,
    vs0: 40,
    approachSpeed: 61, // Vref full flap MTOW per POH
    bestGlide: 68,
    cruiseTas: 122,
    fuelBurnGph: 8.4,
    serviceCeiling: 14000,
    climbRate: 730,
    takeoffGroundRoll: 266,
    takeoffOver50ft: 465,
    landingGroundRoll: 174,
    landingOver50ft: 396,
    mtow: 1111,
    usefulLoad: 397,
    notes:
        'Fuel-injected engine — no carburettor heat, but prime before cold starts. '
        'Electric flaps: check position indicator. '
        'Widely used for PPL training; forgiving handling and stable platform. '
        'G1000 avionics suite fitted to most modern 172S examples.',
  ),

  // ── Piper PA-28-161 Warrior II ────────────────────────────────────────────
  // Source: PA-28-161 POH (Lycoming O-320-D3G)
  AircraftData(
    type: 'pa28',
    displayName: 'PA-28-161 Warrior II',
    engine: 'Lycoming O-320-D3G, 160 hp',
    vne: 160,
    vno: 125,
    va: 113, // at 1055 kg MTOW
    vfe: 103, // 10° and 25°; 88 kt for 40°
    vy: 79,
    vx: 63,
    vs1: 50,
    vs0: 44,
    approachSpeed: 63, // POH recommends 73 kt on final with flap, 63 kt over threshold
    bestGlide: 76,
    cruiseTas: 110,
    fuelBurnGph: 8.5,
    serviceCeiling: 13000,
    climbRate: 710,
    takeoffGroundRoll: 229,
    takeoffOver50ft: 427,
    landingGroundRoll: 234,
    landingOver50ft: 503,
    mtow: 1055,
    usefulLoad: 394,
    notes:
        'Semi-tapered wing gives docile stall characteristics. '
        'Carburettor heat required — apply before power reduction and monitor during cruise. '
        'Fuel selector has L / R / OFF — no both position; switch tanks every 30 min. '
        'Flap lever: three notches (10°, 25°, 40°). 40° flap significantly increases drag.',
  ),

  // ── Piper PA-28-181 Archer III ────────────────────────────────────────────
  // Source: PA-28-181 POH (Lycoming O-360-A4M)
  AircraftData(
    type: 'pa28_181',
    displayName: 'PA-28-181 Archer III',
    engine: 'Lycoming O-360-A4M, 180 hp',
    vne: 160,
    vno: 125,
    va: 118, // at 1157 kg MTOW
    vfe: 103, // up to 25°; 88 kt for 40°
    vy: 76,
    vx: 63,
    vs1: 50,
    vs0: 44,
    approachSpeed: 67,
    bestGlide: 76,
    cruiseTas: 124,
    fuelBurnGph: 9.5,
    serviceCeiling: 13650,
    climbRate: 750,
    takeoffGroundRoll: 213,
    takeoffOver50ft: 396,
    landingGroundRoll: 213,
    landingOver50ft: 470,
    mtow: 1157,
    usefulLoad: 426,
    notes:
        'Same airframe as Warrior II but with the O-360 engine giving noticeably better climb. '
        'Handling identical to PA-28-161; same fuel selector caution applies. '
        'Greater useful load makes this popular for cross-country training. '
        'Carburettor heat: same discipline as Warrior — apply before power reduction.',
  ),

  // ── Piper PA-38 Tomahawk ──────────────────────────────────────────────────
  // Source: PA-38-112 POH (Lycoming O-235-L2C)
  AircraftData(
    type: 'pa38',
    displayName: 'Piper PA-38 Tomahawk',
    engine: 'Lycoming O-235-L2C, 112 hp',
    vne: 152,
    vno: 117,
    va: 104, // at 757 kg MTOW
    vfe: 100, // first notch; 87 kt second notch
    vy: 65,
    vx: 56,
    vs1: 52,
    vs0: 44,
    approachSpeed: 61,
    bestGlide: 63,
    cruiseTas: 96,
    fuelBurnGph: 6.4,
    serviceCeiling: 13000,
    climbRate: 718,
    takeoffGroundRoll: 213,
    takeoffOver50ft: 411,
    landingGroundRoll: 183,
    landingOver50ft: 381,
    mtow: 757,
    usefulLoad: 263,
    notes:
        'T-tail design: elevator authority reduced at low speeds — do not rotate early on takeoff. '
        'Known for honest stall / spin behaviour: widely used for stall training. '
        'Side-by-side seating on a narrow fuselage. '
        'Carburettor heat required. Limited baggage capacity (54 kg).',
  ),

  // ── Diamond DA20-C1 Eclipse ───────────────────────────────────────────────
  // Source: DA20-C1 POH (Continental IO-240-B)
  AircraftData(
    type: 'da20',
    displayName: 'Diamond DA20-C1 Eclipse',
    engine: 'Continental IO-240-B, 125 hp',
    vne: 163,
    vno: 135,
    va: 113, // at 750 kg MTOW
    vfe: 97,
    vy: 76,
    vx: 62,
    vs1: 47,
    vs0: 44,
    approachSpeed: 62,
    bestGlide: 76,
    cruiseTas: 120,
    fuelBurnGph: 5.8,
    serviceCeiling: 13600,
    climbRate: 830,
    takeoffGroundRoll: 265,
    takeoffOver50ft: 415,
    landingGroundRoll: 270,
    landingOver50ft: 427,
    mtow: 750,
    usefulLoad: 243,
    notes:
        'Composite construction; canopy entry — pre-flight canopy latch carefully. '
        'Fuel-injected Continental: prime using fuel pump before cold starts. '
        'Side-stick controls: initially unfamiliar but precise. '
        'Very light — pronounced pitch change with power; trim frequently. '
        'Excellent visibility from bubble canopy.',
  ),

  // ── Diamond DA40 Diamond Star ─────────────────────────────────────────────
  // Source: DA40-180 AFM (Lycoming IO-360-M1A)
  AircraftData(
    type: 'da40',
    displayName: 'Diamond DA40 Diamond Star',
    engine: 'Lycoming IO-360-M1A, 180 hp',
    vne: 178,
    vno: 140,
    va: 119, // at 1150 kg MTOW
    vfe: 106,
    vy: 79,
    vx: 68,
    vs1: 52,
    vs0: 46,
    approachSpeed: 65,
    bestGlide: 76,
    cruiseTas: 130,
    fuelBurnGph: 8.5,
    serviceCeiling: 16400,
    climbRate: 1070,
    takeoffGroundRoll: 305,
    takeoffOver50ft: 503,
    landingGroundRoll: 274,
    landingOver50ft: 503,
    mtow: 1150,
    usefulLoad: 390,
    notes:
        'Diesel DA40 NG variant (Austro AE300) has significantly different performance figures. '
        'Electric Fowler flaps: pre-select before approach. '
        'Castering nosewheel: differential braking for ground steering — no rudder authority on ground. '
        'Composite airframe: inspect for delamination around leading edges.',
  ),

  // ── Robin DR400/160 ───────────────────────────────────────────────────────
  // Source: Robin DR400-160 POH (Lycoming O-320-D2A)
  AircraftData(
    type: 'robin_dr400',
    displayName: 'Robin DR400/160',
    engine: 'Lycoming O-320-D2A, 160 hp',
    vne: 172,
    vno: 129,
    va: 108,
    vfe: 100,
    vy: 76,
    vx: 67,
    vs1: 52,
    vs0: 46,
    approachSpeed: 65,
    bestGlide: 73,
    cruiseTas: 119,
    fuelBurnGph: 8.7,
    serviceCeiling: 12800,
    climbRate: 750,
    takeoffGroundRoll: 200,
    takeoffOver50ft: 380,
    landingGroundRoll: 200,
    landingOver50ft: 400,
    mtow: 1000,
    usefulLoad: 370,
    notes:
        'Wooden composite wing: no freezing flight — not certified for flight into known icing. '
        'Sliding canopy: close before takeoff; check latch security. '
        'Three-seat tandem layout in the cockpit on some variants. '
        'Carburettor heat: apply well before power reductions. '
        'Popular at French and some UK flying clubs.',
  ),

  // ── Grob G115E Tutor ─────────────────────────────────────────────────────
  // Source: Grob G115E Flight Manual (Lycoming AEIO-360-B1F)
  AircraftData(
    type: 'grob_g115',
    displayName: 'Grob G115E Tutor',
    engine: 'Lycoming AEIO-360-B1F, 180 hp',
    vne: 163,
    vno: 135,
    va: 119, // at 950 kg MTOW
    vfe: 100,
    vy: 78,
    vx: 66,
    vs1: 54,
    vs0: 49,
    approachSpeed: 70,
    bestGlide: 70,
    cruiseTas: 120,
    fuelBurnGph: 9.0,
    serviceCeiling: 14000,
    climbRate: 840,
    takeoffGroundRoll: 240,
    takeoffOver50ft: 430,
    landingGroundRoll: 220,
    landingOver50ft: 460,
    mtow: 950,
    usefulLoad: 310,
    notes:
        'Acrobatic variant (AEIO engine with inverted oil system): used extensively by the RAF UAS. '
        'Smoke system may be fitted on military examples. '
        'Inverted fuel/oil system allows sustained inverted flight. '
        'Composite construction — fibreglass fuselage; inspect skin carefully. '
        'Side-by-side seating; dual controls standard.',
  ),

  // ── Tecnam P2002 Sierra ───────────────────────────────────────────────────
  // Source: Tecnam P2002 Sierra POH (Rotax 912 ULS2, 100 hp)
  AircraftData(
    type: 'tecnam_p2002',
    displayName: 'Tecnam P2002 Sierra',
    engine: 'Rotax 912 ULS2, 100 hp',
    vne: 140,
    vno: 108,
    va: 92, // at 600 kg MTOW
    vfe: 87,
    vy: 68,
    vx: 55,
    vs1: 43,
    vs0: 38,
    approachSpeed: 55,
    bestGlide: 65,
    cruiseTas: 107,
    fuelBurnGph: 5.0,
    serviceCeiling: 14000,
    climbRate: 885,
    takeoffGroundRoll: 170,
    takeoffOver50ft: 300,
    landingGroundRoll: 170,
    landingOver50ft: 340,
    mtow: 600,
    usefulLoad: 200,
    notes:
        'Rotax 912 engine: warm-up at 2,000 rpm until oil reaches 50°C before power checks. '
        'Uses Mogas (unleaded 95) or Avgas 100LL; preferred fuel is Mogas — check POH. '
        'Very light — sensitive to crosswind and turbulence. '
        'Electric flaps; limited useful load means careful weight-and-balance needed with two occupants. '
        'Liquid-cooled engine: monitor coolant temperature as well as oil temp.',
  ),
];

/// Look up aircraft data by [AppConstants.aircraftTypes] key.
/// Returns null if the type is not in the catalogue.
AircraftData? aircraftDataForType(String type) {
  try {
    return kAircraftDataList.firstWhere((a) => a.type == type);
  } catch (_) {
    return null;
  }
}
