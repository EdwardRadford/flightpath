/// CAA PPL(A) Skills Test Standards
///
/// Static map of examiner criteria for each exercise, keyed by composite
/// exercise ID (matching [AppConstants.allExerciseIds]).
///
/// Sources: CAA CAP 1779 (PPL Skills Test Standards) and CAA CAP 1298
/// (PPL Syllabus). These reflect what the examiner expects to see during
/// the PPL(A) skills test. Exercises not assessed in the skills test
/// (ex_01–ex_05, ex_14, ex_19) do not have an entry.
const Map<String, String> skillsTestStandards = {
  // ── Ex 06: Straight and Level Flight ──────────────────────────────────────
  'ex_06':
      'Maintain straight and level flight within ±150 ft of the selected altitude '
      'and ±10° of the selected heading. Airspeed should be held within ±15 kt. '
      'Demonstrate smooth, coordinated use of controls with proper lookout and '
      'scanning technique. Use trim correctly to relieve all control pressure.',

  // ── Ex 07: Climbing ───────────────────────────────────────────────────────
  'ex_07':
      'Establish a climb at the correct attitude and airspeed (+15 / −5 kt of '
      'best rate or best angle as appropriate). Maintain coordinated flight '
      'throughout. Level off at a pre-selected altitude within ±150 ft using a '
      'timely attitude change. Apply carburettor heat correctly and complete '
      'after-climb checks.',

  // ── Ex 08: Descending ─────────────────────────────────────────────────────
  'ex_08':
      'Establish a descent (powered and glide) with airspeed controlled within '
      '+15 / −5 kt of the selected speed. Maintain coordinated flight and appropriate '
      'lookout. Level off at the cleared altitude within ±150 ft. Apply '
      'carburettor heat as required and complete the relevant checks.',

  // ── Ex 09: Turning ────────────────────────────────────────────────────────
  'ex_09':
      'Perform medium turns maintaining altitude within ±150 ft and airspeed '
      'within ±15 kt. Roll out on pre-selected headings within ±10°. Demonstrate '
      'coordinated use of all controls throughout; no skid or slip evident. '
      'Complete clearing turns before commencing any manoeuvre.',

  // ── Ex 10A: Slow Flight ───────────────────────────────────────────────────
  'ex_10_10a':
      'Demonstrate controlled flight at airspeeds close to the stall '
      '(approximately 1.2 Vs). Maintain heading within ±10° and altitude within '
      '±150 ft. Show effective use of power and positive control inputs. '
      'Correctly identify the onset of pre-stall buffet and transition to recovery '
      'before a full stall develops.',

  // ── Ex 10B: Stalling ──────────────────────────────────────────────────────
  'ex_10_10b':
      'Demonstrate stalls in clean and approach configuration and recover '
      'promptly at the first indication of the stall (buffet, stick force change, '
      'or break). Recovery: simultaneously lower the nose to the horizon, apply '
      'full power, and level the wings — minimum height loss throughout. '
      'The examiner assesses prompt recognition, correct recovery technique, '
      'and height lost during recovery.',

  // ── Ex 11: Spin Awareness and Recovery ───────────────────────────────────
  'ex_11':
      'Demonstrate recognition and recovery from incipient spin entry (full '
      'developed spins are not required for PPL). At the first sign of rotation, '
      'apply full opposite rudder, push the control column forward to unstall '
      'the wing, and centralise controls once rotation stops. Pull out of the '
      'dive smoothly. The examiner expects confident and timely application of '
      'PARE (Power off, Ailerons neutral, Rudder full opposite, Elevator forward).',

  // ── Ex 12: Take-off and Climb to Downwind ────────────────────────────────
  'ex_12':
      'Conduct take-offs (normal and crosswind) using correct technique: complete '
      'pre-take-off checks, apply power smoothly, maintain directional control on '
      'the runway, and rotate at Vr. Establish a positive climb at Vx or Vy as '
      'appropriate. Track the extended runway centreline and maintain climb '
      'heading within ±5°. Complete after-take-off checks and level off at '
      'circuit height. In the event of a rejected take-off or EFATO, immediately close the throttle, apply maximum braking, and maintain directional control; if airborne, maintain climb attitude and complete drills before turning back.',

  // ── Ex 13: Circuit, Approach and Landing ─────────────────────────────────
  'ex_13':
      'Fly a well-shaped circuit at the correct altitude (±150 ft) and position. '
      'Fly a stabilised approach at the target speed (±5 kt) on the correct '
      'glide path. Use flap in accordance with the checklist. Touch down in the '
      'designated touchdown zone on the main wheels, within the first third of '
      'the runway. Execute a go-around promptly if instructed or if the approach '
      'becomes unstable. Demonstrate a crosswind landing if conditions allow.',

  // ── Ex 15: Advanced Turning ───────────────────────────────────────────────
  'ex_15':
      'Perform steep turns through at least 360° at 45° bank angle, maintaining altitude within ±150 ft '
      'and airspeed within ±15 kt. Roll out on the entry heading within ±10°. '
      'Demonstrate awareness of increased load factor and the accelerated stall '
      'speed. Show smooth, coordinated control throughout with effective lookout.',

  // ── Ex 16: Forced Landing Without Power ──────────────────────────────────
  'ex_16':
      'On a simulated engine failure, immediately adopt the best glide attitude '
      'and airspeed (+15 / −5 kt), select a suitable field (considering size, '
      'surface, slope, obstacles, and wind), and complete engine failure drills '
      'systematically. Fly a circuit to arrive over the field threshold at the '
      'correct height to land within the first third. Announce the go-around at '
      'a safe height as required. The examiner assesses field selection, use of '
      'available height, and systematic emergency drill completion.',

  // ── Ex 17: Precautionary Landing ─────────────────────────────────────────
  'ex_17':
      'Select a suitable field for a precautionary landing (deteriorating weather '
      'or simulated technical problem). Conduct a low-level inspection at a safe '
      'height (typically 500 ft AGL), assess the field for surface, slope, and '
      'obstacles, then fly an accurate circuit to land within the first third. '
      'Demonstrate correct lookout and use of the appropriate checklist. The '
      'examiner assesses aeronautical decision-making, field assessment technique, '
      'and approach accuracy.',

  // ── Ex 18A: Navigation ────────────────────────────────────────────────────
  'ex_18_18a':
      'Plan and execute a cross-country flight (minimum 150 nm total, at least '
      '3 legs, with two full-stop landings at different aerodromes from departure). '
      'Maintain heading within ±5°, altitude within '
      '±150 ft, and accurate time tracking. Use a 1:500,000 topographic chart '
      'and dead reckoning to identify turning points. Arrive at destination '
      'within 3 minutes of ETA. Demonstrate FREDA checks, correct radio '
      'communication, and appropriate lost-procedure if disorientated.',

  // ── Ex 18B: Navigation at Lower Levels ───────────────────────────────────
  'ex_18_18b':
      'Demonstrate safe navigation at low level (below 1,000 ft AGL) in '
      'simulated reduced visibility. Maintain controlled flight, effective '
      'lookout for terrain, obstacles, and other traffic, and continuous '
      'awareness of escape routes. Show sound aeronautical decision-making '
      'and the ability to climb to a safe altitude promptly if the situation '
      'deteriorates.',

  // ── Ex 18C: Radio Navigation ──────────────────────────────────────────────
  'ex_18_18c':
      'Demonstrate use of at least one radio navigation aid (VOR, NDB, or GPS) '
      'to track to or from a beacon and establish position. Correctly tune and '
      'identify the aid, apply drift corrections, and maintain track within ±5°. '
      'Show correct interpretation of instrument indications and awareness of '
      'the aid\'s range and accuracy limitations.',

  // ── Ex 18E: Navigation Emergencies ────────────────────────────────────────
  'ex_18_18e':
      'When given a simulated navigation emergency, respond promptly and systematically. '
      'For diversions: select a suitable alternate, measure the new track, calculate a heading '
      'and ETA, and navigate to the alternate without getting behind the aircraft. '
      'For lost procedure: climb if safe, identify landmarks, call ATC (121.5 MHz or nearest '
      'ATSU), squawk 7700 if emergency. For radio failure: try all frequencies, squawk 7600, '
      'proceed to destination VFR, comply with light signals at the aerodrome. '
      'The examiner assesses decision-making quality and systematic application of procedures.',
};
