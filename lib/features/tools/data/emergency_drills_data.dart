// Static data for the Emergency Drills tool.
// Four categories: Engine Failures, Fires, Emergencies, Checks.

class EmergencyDrillCategory {
  final String title;
  final List<EmergencyDrillCard> cards;

  const EmergencyDrillCategory({required this.title, required this.cards});
}

class EmergencyDrillCard {
  final String situation;
  final String action;

  const EmergencyDrillCard({required this.situation, required this.action});
}

const List<EmergencyDrillCategory> kEmergencyDrillCategories = [
  EmergencyDrillCategory(
    title: 'Engine Failures',
    cards: [
      EmergencyDrillCard(
        situation: 'Engine failure after take-off (EFATO) — below 500 ft',
        action: 'Lower nose immediately — maintain flying speed.\n'
            'Land ahead, minor deviations only, no turns back.\n'
            'Select best field.\n'
            'Master off  •  Mixture cut-off  •  Fuel off\n'
            'Flaps as required  •  Brace',
      ),
      EmergencyDrillCard(
        situation: 'Engine failure after take-off — above 500 ft',
        action: 'If runway still reachable — return.\n'
            'Otherwise: HASELL area + PFL.\n'
            'Carb heat on  •  Fuel on fullest tank  •  Mixture rich\n'
            'Primer in and locked  •  Magnetos — check both',
      ),
      EmergencyDrillCard(
        situation: 'Engine failure in cruise',
        action: 'HASELL check + PFL.\n'
            'Carb heat on → airspeed 73 kt glide.\n'
            'Select field  •  Mayday call.\n'
            'Fuel on fullest tank  •  Mixture rich  •  Magnetos  •  Primer.\n'
            'Attempt restart.\n'
            'If no restart: fuel off, mixture cut-off, master off on short final, flaps, brace.',
      ),
      EmergencyDrillCard(
        situation: 'Engine rough running',
        action: 'Carb heat on (expect slight drop then recovery).\n'
            'Check fuel — fullest tank, boost pump on, mixture rich.\n'
            'Check temperatures/pressures.\n'
            'Lean if too rich at altitude.',
      ),
    ],
  ),
  EmergencyDrillCategory(
    title: 'Fires',
    cards: [
      EmergencyDrillCard(
        situation: 'Engine fire on start',
        action: 'Fuel off  •  Mixture cut-off.\n'
            'Starter on — draw fire back into engine.\n'
            'Evacuate.',
      ),
      EmergencyDrillCard(
        situation: 'Engine fire in flight',
        action: 'Fuel off  •  Mixture cut-off  •  Heater off  •  Cabin heat off.\n'
            'Air vents open (clear smoke).\n'
            'Best glide  •  PAN PAN  •  Land ASAP.',
      ),
      EmergencyDrillCard(
        situation: 'Cockpit / electrical fire',
        action: 'Master off (kill electrical).\n'
            'Cabin heat off  •  Air vents open.\n'
            'Handheld extinguisher if available.\n'
            'PAN PAN  •  Land ASAP.',
      ),
      EmergencyDrillCard(
        situation: 'Smoke in cockpit — unknown source',
        action: 'Master off  •  Vents open.\n'
            'Fresh air mask if available.\n'
            'Identify source.\n'
            'PAN PAN  •  Land ASAP.',
      ),
    ],
  ),
  EmergencyDrillCategory(
    title: 'Emergencies',
    cards: [
      EmergencyDrillCard(
        situation: 'Total electrical failure',
        action: 'Maintain VFR. Navigate by map and landmarks.\n'
            'Squawk 7600.\n'
            'Land at nearest suitable airfield. Join overhead if controlled.\n'
            'Light signals: steady green = clear to land  •  flashing green = return for landing\n'
            'Steady red = give way  •  flashing red = do not land.',
      ),
      EmergencyDrillCard(
        situation: 'Partial panel — vacuum failure',
        action: 'Ignore AI and DI.\n'
            'Use turn coordinator, altimeter, ASI, VSI for attitude.\n'
            'Wings level = balanced ball + constant altimeter.',
      ),
      EmergencyDrillCard(
        situation: 'Lost / uncertain of position (PALSU)',
        action: 'Preserve fuel and height.\n'
            'Ascertain position — map read, landmarks, VOR/NDB if available.\n'
            'Locate — climb for better view.\n'
            'Squawk 7000.\n'
            'Contact ATC on 121.5 if unable to establish position.\n'
            'Fly towards known feature (coast, river, motorway).',
      ),
      EmergencyDrillCard(
        situation: 'PAN PAN call format',
        action: '"PAN PAN PAN, [callsign], [nature of urgency], [position],\n'
            '[heading/altitude], [persons on board], [intentions]"',
      ),
      EmergencyDrillCard(
        situation: 'MAYDAY call format',
        action: '"MAYDAY MAYDAY MAYDAY, [callsign], [nature of emergency], [position],\n'
            '[heading/altitude], [persons on board], [intentions]"\n'
            'Squawk 7700.',
      ),
      EmergencyDrillCard(
        situation: 'Transponder codes',
        action: '7000 — conspicuity (VFR)\n'
            '7700 — emergency\n'
            '7600 — radio failure\n'
            '7500 — hijack',
      ),
    ],
  ),
  EmergencyDrillCategory(
    title: 'Checks',
    cards: [
      EmergencyDrillCard(
        situation: 'HASELL',
        action: 'Height (sufficient for recovery)\n'
            'Airframe (flaps/gear as required)\n'
            'Security (harness secure, hatches closed, no loose articles)\n'
            'Engine (temps/pressures, fuel on fullest, carb heat check, primer in)\n'
            'Location (clear airspace, away from built-up areas, suitable field below)\n'
            'Lookout (clearing turns left and right)',
      ),
      EmergencyDrillCard(
        situation: 'FREDA',
        action: 'Fuel (sufficient, on correct tank, boost pump)\n'
            'Radio (correct frequency, squawking)\n'
            'Engine (temps/pressures normal, carb heat check)\n'
            'DI (aligned to compass)\n'
            'Airspace/Altimeter (correct QNH/QFE, clear of controlled airspace)',
      ),
      EmergencyDrillCard(
        situation: 'Pre-landing BUMFICH',
        action: 'Brakes (tested)\n'
            'Undercarriage (down — fixed, check)\n'
            'Mixture (rich)\n'
            'Fuel (on fullest, sufficient, boost pump on)\n'
            'Instruments (altimeter set QFE)\n'
            'Carb heat (hot for approach)\n'
            'Hatches and Harnesses (secure)',
      ),
    ],
  ),
];
