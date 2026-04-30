// Static data for the Memory Drills tool.
// Three categories: speeds (aircraft-specific), mnemonics, circuit.

class MemoryDrillCategory {
  final String title;
  final List<MemoryDrillCard> cards;

  const MemoryDrillCategory({required this.title, required this.cards});
}

class MemoryDrillCard {
  final String front;
  final String back;

  const MemoryDrillCard({required this.front, required this.back});
}

class AircraftSpeedData {
  final String aircraftType;
  final String displayName;
  final List<MemoryDrillCard> speeds;

  const AircraftSpeedData({
    required this.aircraftType,
    required this.displayName,
    required this.speeds,
  });
}

const List<AircraftSpeedData> kAircraftSpeedData = [
  // ── PA-28-161 Warrior II ──────────────────────────────────────────────────
  // Source: aircraft_data.dart (PA-28-161 POH, Lycoming O-320-D3G)
  AircraftSpeedData(
    aircraftType: 'pa28',
    displayName: 'PA-28-161 Warrior II',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '44 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '50 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '63 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '79 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '113 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '129 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '160 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended (25°)', back: '103 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '63 kt'),
    ],
  ),

  // ── PA-28-181 Archer III ──────────────────────────────────────────────────
  // Source: aircraft_data.dart (PA-28-181 POH, Lycoming O-360-A4M)
  AircraftSpeedData(
    aircraftType: 'pa28_181',
    displayName: 'PA-28-181 Archer III',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '44 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '50 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '63 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '76 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '118 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '125 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '160 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended (25°)', back: '103 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '67 kt'),
    ],
  ),

  // ── Piper PA-38 Tomahawk ──────────────────────────────────────────────────
  // Source: aircraft_data.dart (PA-38-112 POH, Lycoming O-235-L2C)
  AircraftSpeedData(
    aircraftType: 'pa38',
    displayName: 'Piper PA-38 Tomahawk',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '44 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '52 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '56 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '65 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '104 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '117 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '152 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended (1st notch)', back: '100 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '61 kt'),
    ],
  ),

  // ── Cessna 152 ────────────────────────────────────────────────────────────
  // Source: aircraft_data.dart (Cessna 152 POH, Lycoming O-235-L2C)
  AircraftSpeedData(
    aircraftType: 'cessna_152',
    displayName: 'Cessna 152',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '40 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '48 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '54 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '67 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '104 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '111 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '149 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended', back: '85 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '54 kt'),
    ],
  ),

  // ── Cessna 172S Skyhawk ───────────────────────────────────────────────────
  // Source: aircraft_data.dart (Cessna 172S POH, Lycoming IO-360-L2A)
  AircraftSpeedData(
    aircraftType: 'cessna_172',
    displayName: 'Cessna 172S Skyhawk',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '40 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '54 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '62 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '76 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '105 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '129 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '163 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended', back: '85 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '61 kt'),
    ],
  ),

  // ── Diamond DA20-C1 Eclipse ───────────────────────────────────────────────
  // Source: aircraft_data.dart (DA20-C1 POH, Continental IO-240-B)
  AircraftSpeedData(
    aircraftType: 'da20',
    displayName: 'Diamond DA20-C1 Eclipse',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '44 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '47 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '62 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '76 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '113 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '135 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '163 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended', back: '97 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '62 kt'),
    ],
  ),

  // ── Diamond DA40 Diamond Star ─────────────────────────────────────────────
  // Source: aircraft_data.dart (DA40-180 AFM, Lycoming IO-360-M1A)
  AircraftSpeedData(
    aircraftType: 'da40',
    displayName: 'Diamond DA40 Diamond Star',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '46 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '52 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '68 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '79 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '119 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '140 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '178 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended', back: '106 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '65 kt'),
    ],
  ),

  // ── Robin DR400/160 ───────────────────────────────────────────────────────
  // Source: aircraft_data.dart (Robin DR400-160 POH, Lycoming O-320-D2A)
  AircraftSpeedData(
    aircraftType: 'robin_dr400',
    displayName: 'Robin DR400/160',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '46 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '52 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '67 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '76 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed', back: '108 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '129 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '172 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended', back: '100 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '65 kt'),
    ],
  ),

  // ── Grob G115E Tutor ─────────────────────────────────────────────────────
  // Source: aircraft_data.dart (Grob G115E Flight Manual, Lycoming AEIO-360-B1F)
  AircraftSpeedData(
    aircraftType: 'grob_g115',
    displayName: 'Grob G115E Tutor',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '49 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '54 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '66 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '78 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '119 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '135 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '163 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended', back: '100 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '70 kt'),
    ],
  ),

  // ── Tecnam P2002 Sierra ───────────────────────────────────────────────────
  // Source: aircraft_data.dart (Tecnam P2002 Sierra POH, Rotax 912 ULS2)
  AircraftSpeedData(
    aircraftType: 'tecnam_p2002',
    displayName: 'Tecnam P2002 Sierra',
    speeds: [
      MemoryDrillCard(front: 'Vs0 — stall, landing config', back: '38 kt'),
      MemoryDrillCard(front: 'Vs1 — stall, clean', back: '43 kt'),
      MemoryDrillCard(front: 'Vx — best angle of climb', back: '55 kt'),
      MemoryDrillCard(front: 'Vy — best rate of climb', back: '68 kt'),
      MemoryDrillCard(front: 'Va — manoeuvring speed (MTOW)', back: '92 kt'),
      MemoryDrillCard(front: 'Vno — max structural cruise', back: '108 kt'),
      MemoryDrillCard(front: 'Vne — never exceed', back: '140 kt'),
      MemoryDrillCard(front: 'Vfe — max flap extended', back: '87 kt'),
      MemoryDrillCard(front: 'Vapp — normal approach (full flap)', back: '55 kt'),
    ],
  ),
];

// Mnemonics and Circuit categories apply to all aircraft types.
const List<MemoryDrillCategory> kMemoryDrillCategories = [
  MemoryDrillCategory(
    title: 'Mnemonics',
    cards: [
      MemoryDrillCard(
        front: 'HASELL',
        back: 'Height (sufficient for recovery)\n'
            'Airframe (flaps/gear as required)\n'
            'Security (harness, hatches, no loose articles)\n'
            'Engine (temps/pressures, fuel, carb heat)\n'
            'Location (clear of controlled airspace, away from built-up areas)\n'
            'Lookout (clear turns left and right)',
      ),
      MemoryDrillCard(
        front: 'FREDA',
        back: 'Fuel (sufficient, on correct tank, pump if required)\n'
            'Radio (set and squawking)\n'
            'Engine (temps/pressures normal)\n'
            'DI (aligned with compass)\n'
            'Airspace/Altimeter (correct setting, clear of airspace)',
      ),
      MemoryDrillCard(
        front: 'BUMF',
        back: 'Brakes (tested)\n'
            'Undercarriage (down and locked — or N/A for fixed)\n'
            'Mixture (rich for take-off)\n'
            'Fuel (selected, sufficient, pump on)',
      ),
      MemoryDrillCard(
        front: 'PRICE',
        back: 'Petrol (fuel on, sufficient)\n'
            'Radio (on, set)\n'
            'Instruments (checked and set)\n'
            'Contacts (with ATC)\n'
            'Emergencies (briefed)',
      ),
      MemoryDrillCard(
        front: 'CALL',
        back: 'Carb heat (cold for take-off)\n'
            'Altimeter (set QNH/QFE)\n'
            'Location (clear of obstructions)\n'
            'Lookout (final check)',
      ),
      MemoryDrillCard(
        front: 'PAST',
        back: 'Position (known)\n'
            'Altitude (safe)\n'
            'Speed (within limits)\n'
            'Time/Track (on plan)',
      ),
    ],
  ),
  MemoryDrillCategory(
    title: 'Circuit',
    cards: [
      MemoryDrillCard(front: 'Circuit height', back: '1000 ft QFE'),
      MemoryDrillCard(
        front: 'Crosswind turn',
        back: 'After 500 ft — track crosswind',
      ),
      MemoryDrillCard(
        front: 'Downwind actions',
        back: 'Abeam runway threshold — reduce power, first stage flap',
      ),
      MemoryDrillCard(
        front: 'Base turn actions',
        back: 'Abeam runway end — second stage flap',
      ),
      MemoryDrillCard(
        front: 'Final',
        back: 'Full flap  •  Vapp per aircraft type',
      ),
      MemoryDrillCard(front: 'Flare height', back: '~30 ft'),
      MemoryDrillCard(
        front: 'Transponder codes',
        back: '7000 conspicuity\n7700 emergency\n7600 comms failure',
      ),
    ],
  ),
];
