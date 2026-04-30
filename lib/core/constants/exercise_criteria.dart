// Per-exercise assessment criteria aligned with CAA Standards Document 19(A)
// PPL(A) competency standards. Each exercise lists the specific competencies
// an instructor must assess before signing off.

/// A single criterion that an instructor assesses for an exercise.
class ExerciseCriterion {
  final String key;
  final String label;
  final String description;

  const ExerciseCriterion({
    required this.key,
    required this.label,
    required this.description,
  });
}

/// CAA PPL(A) exercise assessment criteria keyed by composite exercise ID.
/// Based on UK CAA Standards Document 19(A) — PPL(A) training syllabus.
class ExerciseCriteria {
  ExerciseCriteria._();

  static const Map<String, List<ExerciseCriterion>> exerciseCriteria = {
    // ── Ex 1: Familiarisation with the Aeroplane ────────────────────────
    'ex_01': [
      ExerciseCriterion(
        key: 'aircraft_components',
        label: 'Aircraft Components',
        description:
            'Identifies main structural components: fuselage, wings, empennage, undercarriage, engine, propeller',
      ),
      ExerciseCriterion(
        key: 'flight_controls',
        label: 'Flight Controls',
        description:
            'Identifies and explains function of ailerons, elevator/stabilator, rudder, trim, and flaps',
      ),
      ExerciseCriterion(
        key: 'cockpit_layout',
        label: 'Cockpit Layout',
        description:
            'Locates and names all flight instruments, engine instruments, switches, and circuit breakers',
      ),
      ExerciseCriterion(
        key: 'safety_equipment',
        label: 'Safety Equipment',
        description:
            'Knows location and operation of fire extinguisher, first aid kit, ELT, and emergency exits',
      ),
      ExerciseCriterion(
        key: 'aircraft_documents',
        label: 'Aircraft Documents',
        description:
            'Identifies required documents: C of A, C of R, insurance, weight schedule, Tech Log, POH/FM',
      ),
    ],

    // ── Ex 2: Preparation for and Action after Flight ───────────────────
    'ex_02': [
      ExerciseCriterion(
        key: 'preflight_inspection',
        label: 'Pre-flight Inspection',
        description:
            'Completes systematic walk-round inspection per POH checklist; identifies and reports defects',
      ),
      ExerciseCriterion(
        key: 'internal_checks',
        label: 'Internal Checks',
        description:
            'Completes pre-start, after-start, and pre-taxi checks in correct sequence',
      ),
      ExerciseCriterion(
        key: 'engine_handling',
        label: 'Engine Starting and Handling',
        description:
            'Starts engine safely; checks oil pressure rise, suction, charging; performs run-up checks',
      ),
      ExerciseCriterion(
        key: 'passenger_brief',
        label: 'Passenger Briefing',
        description:
            'Delivers correct passenger safety briefing: seatbelts, doors, fire extinguisher, emergency exit',
      ),
      ExerciseCriterion(
        key: 'post_flight',
        label: 'Post-flight Actions',
        description:
            'Shuts down per checklist, secures aircraft, completes Tech Log entries, reports defects',
      ),
    ],

    // ── Ex 3: Air Experience ────────────────────────────────────────────
    'ex_03': [
      ExerciseCriterion(
        key: 'sensations',
        label: 'Sensations of Flight',
        description:
            'Experiences and discusses sensations of flight: speed, noise, attitude changes, G-loading',
      ),
      ExerciseCriterion(
        key: 'visual_attitude',
        label: 'Visual Attitude Reference',
        description:
            'Begins to relate aircraft attitude to the natural horizon in pitch, roll, and yaw',
      ),
      ExerciseCriterion(
        key: 'local_area',
        label: 'Local Area Orientation',
        description:
            'Identifies aerodrome, local landmarks, and general geography from the air',
      ),
    ],

    // ── Ex 4: Effects of Controls ───────────────────────────────────────
    'ex_04': [
      ExerciseCriterion(
        key: 'primary_effects',
        label: 'Primary Effects of Controls',
        description:
            'Demonstrates primary effect of each control: aileron (roll), elevator (pitch), rudder (yaw)',
      ),
      ExerciseCriterion(
        key: 'further_effects',
        label: 'Further Effects of Controls',
        description:
            'Demonstrates further/secondary effects: aileron (adverse yaw), rudder (further roll/pitch)',
      ),
      ExerciseCriterion(
        key: 'effect_of_airspeed',
        label: 'Effect of Airspeed on Controls',
        description:
            'Demonstrates that control effectiveness varies with airspeed; greater force needed at low speed',
      ),
      ExerciseCriterion(
        key: 'effect_of_power',
        label: 'Effect of Power Changes',
        description:
            'Demonstrates pitch/yaw changes with power application; slipstream effect on controls',
      ),
      ExerciseCriterion(
        key: 'effect_of_flap',
        label: 'Effect of Flap',
        description:
            'Demonstrates flap effect on lift, drag, pitch trim change, and approach speed',
      ),
      ExerciseCriterion(
        key: 'trimming',
        label: 'Use of Trim',
        description:
            'Trims correctly to relieve control forces; re-trims after each configuration or speed change',
      ),
    ],

    // ── Ex 5: Taxiing ───────────────────────────────────────────────────
    'ex_05': [
      ExerciseCriterion(
        key: 'starting_moving_stopping',
        label: 'Starting, Moving Off, and Stopping',
        description:
            'Controls power to start moving; maintains safe speed; stops accurately using brakes',
      ),
      ExerciseCriterion(
        key: 'steering',
        label: 'Steering and Directional Control',
        description:
            'Maintains directional control using nosewheel steering and differential braking; follows taxy routes',
      ),
      ExerciseCriterion(
        key: 'into_wind_taxi',
        label: 'Into-wind Taxi Technique',
        description:
            'Applies correct control deflections for wind direction: stick into wind, elevator as appropriate',
      ),
      ExerciseCriterion(
        key: 'marshalling',
        label: 'Marshalling and ATC',
        description:
            'Responds correctly to marshalling signals; follows ATC taxi instructions; holds at holding points',
      ),
      ExerciseCriterion(
        key: 'engine_checks',
        label: 'Power Checks',
        description:
            'Positions aircraft correctly for power/engine checks; completes checks per checklist',
      ),
    ],

    // ── Ex 6: Straight and Level Flight ─────────────────────────────────
    'ex_06': [
      ExerciseCriterion(
        key: 'level_flight_attitude',
        label: 'Level Flight by Attitude',
        description:
            'Selects and maintains level flight attitude by visual reference to the natural horizon',
      ),
      ExerciseCriterion(
        key: 'maintaining_heading',
        label: 'Maintaining Heading',
        description:
            'Maintains heading within ±10° using visual references confirmed by DI; applies balance',
      ),
      ExerciseCriterion(
        key: 'maintaining_altitude',
        label: 'Maintaining Altitude',
        description:
            'Maintains altitude within ±150 ft using attitude and power adjustments',
      ),
      ExerciseCriterion(
        key: 'cruise_speed_changes',
        label: 'Airspeed Changes in Level Flight',
        description:
            'Transitions between cruise, slow cruise, and fast cruise maintaining level flight',
      ),
      ExerciseCriterion(
        key: 'lookout_scan',
        label: 'Lookout Scan',
        description:
            'Maintains effective systematic lookout scan; divides attention between outside and instruments',
      ),
      ExerciseCriterion(
        key: 'instrument_appreciation',
        label: 'Instrument Appreciation',
        description:
            'Cross-refers to ASI, altimeter, DI, and slip ball to confirm visual attitude is correct',
      ),
    ],

    // ── Ex 7: Climbing ──────────────────────────────────────────────────
    'ex_07': [
      ExerciseCriterion(
        key: 'entry',
        label: 'Entry to Climb',
        description:
            'Enters climb using correct sequence: Power–Attitude–Trim (PAT); achieves climbing attitude promptly',
      ),
      ExerciseCriterion(
        key: 'normal_climb',
        label: 'Normal Climb (Vy)',
        description:
            'Maintains best rate of climb speed (Vy) +15/−5 kt and heading ±10° throughout the climb',
      ),
      ExerciseCriterion(
        key: 'best_angle_climb',
        label: 'Best Angle Climb (Vx)',
        description:
            'Understands and can fly best angle of climb (Vx) for obstacle clearance after take-off',
      ),
      ExerciseCriterion(
        key: 'levelling_off',
        label: 'Levelling Off',
        description:
            'Anticipates target altitude; lowers nose smoothly at the correct lead (10% of rate of climb)',
      ),
      ExerciseCriterion(
        key: 'climbing_turns',
        label: 'Climbing Turns',
        description:
            'Executes gentle climbing turns maintaining climb speed with correct bank angle (max 20°)',
      ),
    ],

    // ── Ex 8: Descending ────────────────────────────────────────────────
    'ex_08': [
      ExerciseCriterion(
        key: 'glide_descent',
        label: 'Glide Descent',
        description:
            'Enters and maintains a glide at the recommended glide speed +15/−5 kt; applies carb heat',
      ),
      ExerciseCriterion(
        key: 'powered_descent',
        label: 'Powered Descent',
        description:
            'Sets target rate of descent using power; maintains speed +15/−5 kt and heading ±10°',
      ),
      ExerciseCriterion(
        key: 'levelling_off',
        label: 'Levelling Off from Descent',
        description:
            'Anticipates target altitude; applies power and raises nose to resume level flight smoothly',
      ),
      ExerciseCriterion(
        key: 'descending_turns',
        label: 'Descending Turns',
        description:
            'Executes descending turns maintaining target speed and descent rate with correct bank',
      ),
      ExerciseCriterion(
        key: 'use_of_flap',
        label: 'Use of Flap in Descent',
        description:
            'Uses flap stages correctly to increase descent angle while controlling speed',
      ),
      ExerciseCriterion(
        key: 'sideslipping',
        label: 'Sideslipping',
        description:
            'Demonstrates sideslip entry and maintenance: bank into wind, opposite rudder; uses sideslip to steepen descent angle without increasing speed; recovers cleanly to straight flight',
      ),
    ],

    // ── Ex 9: Turning ───────────────────────────────────────────────────
    'ex_09': [
      ExerciseCriterion(
        key: 'medium_level_turns',
        label: 'Medium Level Turns (30°)',
        description:
            'Enters, maintains, and rolls out of 30° bank turns; maintains altitude ±150 ft and speed ±5kt',
      ),
      ExerciseCriterion(
        key: 'coordination',
        label: 'Coordination (Balance)',
        description:
            'Applies correct rudder throughout: slip ball centred; no skid or slip',
      ),
      ExerciseCriterion(
        key: 'lookout',
        label: 'Lookout and Clearing Turns',
        description:
            'Completes clearing turn or lookout before all manoeuvres; scans in direction of turn',
      ),
      ExerciseCriterion(
        key: 'rollout_accuracy',
        label: 'Roll-out on Heading',
        description:
            'Anticipates roll-out; levels wings on desired heading ±10°; resumes straight and level',
      ),
      ExerciseCriterion(
        key: 'climbing_descending_turns',
        label: 'Climbing and Descending Turns',
        description:
            'Combines turns with climbs/descents maintaining appropriate speed and bank angle',
      ),
    ],

    // ── Ex 10A: Slow Flight ─────────────────────────────────────────────
    'ex_10_10a': [
      ExerciseCriterion(
        key: 'approach_to_slow',
        label: 'Approach to Slow Flight',
        description:
            'Reduces speed progressively with correct power/attitude; recognises increasing control forces',
      ),
      ExerciseCriterion(
        key: 'flight_at_critically_low',
        label: 'Flight at Critically Low Airspeed',
        description:
            'Maintains controlled flight at minimum safe speed; recognises pre-stall buffet and handling changes',
      ),
      ExerciseCriterion(
        key: 'recognition_of_onset',
        label: 'Recognition of Stall Onset',
        description:
            'Recognises natural stall warnings: buffet, sloppy controls, high nose attitude, stall warner',
      ),
      ExerciseCriterion(
        key: 'recovery_technique',
        label: 'Recovery Technique',
        description:
            'Recovers with minimum height loss: lower nose to unstall wings, apply full power, level wings',
      ),
    ],

    // ── Ex 10B: Stalling ────────────────────────────────────────────────
    'ex_10_10b': [
      ExerciseCriterion(
        key: 'stall_symptoms',
        label: 'Stall Symptoms and Recognition',
        description:
            'Identifies pre-stall symptoms: decreasing speed, buffet, high nose, mushy controls, stall warning',
      ),
      ExerciseCriterion(
        key: 'clean_stall',
        label: 'Stall and Recovery — Clean Configuration',
        description:
            'Performs full stall and standard recovery in clean configuration with minimum height loss',
      ),
      ExerciseCriterion(
        key: 'approach_config_stall',
        label: 'Stall and Recovery — Approach Configuration',
        description:
            'Performs stall and recovery with flap extended and approach power; no secondary stall',
      ),
      ExerciseCriterion(
        key: 'incipient_stall',
        label: 'Incipient Stall Recovery',
        description:
            'Recovers at the incipient stage (first indication) before the stall fully develops',
      ),
      ExerciseCriterion(
        key: 'stall_in_turn',
        label: 'Stall During a Turn',
        description:
            'Demonstrates awareness that stall speed increases in a turn; recovers wings-level first',
      ),
    ],

    // ── Ex 11: Spin Awareness and Recovery ──────────────────────────────
    'ex_11': [
      ExerciseCriterion(
        key: 'spin_theory',
        label: 'Spin Theory and Cause',
        description:
            'Explains that a spin requires a stall plus yaw; understands autorotation',
      ),
      ExerciseCriterion(
        key: 'spin_recognition',
        label: 'Spin Recognition',
        description:
            'Recognises the entry into a spin: wing drop, rapid yaw, nose-down pitch, high rotation rate',
      ),
      ExerciseCriterion(
        key: 'recovery_procedure',
        label: 'Standard Recovery Procedure',
        description:
            'Full opposite rudder, pause, ease stick forward to unstall, centralise rudder, recover from dive',
      ),
      ExerciseCriterion(
        key: 'avoidance',
        label: 'Spin Avoidance',
        description:
            'Understands critical situations: uncoordinated stall, base-to-final turn, low-speed flight',
      ),
    ],

    // ── Ex 12: Take-off and Climb to Downwind ───────────────────────────
    'ex_12': [
      ExerciseCriterion(
        key: 'pre_takeoff_checks',
        label: 'Pre-take-off Vital Actions',
        description:
            'Completes pre-take-off checks (TMPFFGH or equivalent mnemonic) before entering the runway',
      ),
      ExerciseCriterion(
        key: 'normal_takeoff',
        label: 'Normal Take-off',
        description:
            'Applies full power smoothly; maintains centreline with rudder; rotates at correct speed',
      ),
      ExerciseCriterion(
        key: 'initial_climb',
        label: 'Initial Climb-out',
        description:
            'Achieves and maintains Vy ±5kt; makes appropriate after-take-off checks',
      ),
      ExerciseCriterion(
        key: 'crosswind_takeoff',
        label: 'Crosswind Take-off',
        description:
            'Applies into-wind aileron and opposite rudder; lifts off cleanly without drift',
      ),
      ExerciseCriterion(
        key: 'departure_procedure',
        label: 'Departure and Circuit Join',
        description:
            'Follows published departure route; makes correct R/T calls; joins circuit at correct height',
      ),
      ExerciseCriterion(
        key: 'efato_rto',
        label: 'EFATO and Rejected Take-off',
        description:
            'Knows the EFATO decision point (typically 500 ft AGL or Vr); if engine fails before decision: close throttle, brake, maintain directional control; if airborne: maintain climb attitude, complete drills, do not turn back below 1000 ft AAL',
      ),
    ],

    // ── Ex 13: Circuit, Approach and Landing ────────────────────────────
    'ex_13': [
      ExerciseCriterion(
        key: 'circuit_pattern',
        label: 'Circuit Pattern Accuracy',
        description:
            'Flies accurate rectangular circuit: correct height (typically 1000ft QFE), spacing, and speed per leg',
      ),
      ExerciseCriterion(
        key: 'downwind_checks',
        label: 'Downwind Checks and Calls',
        description:
            'Completes downwind checks (BUMPFFICH or equivalent); makes downwind R/T call',
      ),
      ExerciseCriterion(
        key: 'approach',
        label: 'Final Approach Management',
        description:
            'Establishes stable approach: correct speed (1.3 Vs), descent angle, and configuration',
      ),
      ExerciseCriterion(
        key: 'landing',
        label: 'Landing Technique',
        description:
            'Executes round-out, hold-off, and touchdown: main wheels first, on centreline, within the first third of the runway',
      ),
      ExerciseCriterion(
        key: 'crosswind_landing',
        label: 'Crosswind Approach and Landing',
        description:
            'Applies crab or wing-low technique; maintains centreline throughout approach and touchdown',
      ),
      ExerciseCriterion(
        key: 'go_around',
        label: 'Go-around Procedure',
        description:
            'Executes go-around promptly on decision: full power, carb heat cold, climb attitude, flaps incrementally',
      ),
    ],

    // ── Ex 14: First Solo ───────────────────────────────────────────────
    'ex_14': [
      ExerciseCriterion(
        key: 'consistent_circuits',
        label: 'Consistent Circuit Standard',
        description:
            'Demonstrated safe and consistent circuits over preceding lessons; no major faults',
      ),
      ExerciseCriterion(
        key: 'go_around_judgement',
        label: 'Go-around Judgement',
        description:
            'Demonstrates ability to recognise when to go around and executes correctly without instructor prompting',
      ),
      ExerciseCriterion(
        key: 'situational_awareness',
        label: 'Situational Awareness',
        description:
            'Maintains awareness of other traffic, wind changes, and circuit position without instructor input',
      ),
      ExerciseCriterion(
        key: 'composure',
        label: 'Composure and Airmanship',
        description:
            'Demonstrates calm, confident manner and good airmanship; safe decision-making throughout',
      ),
      ExerciseCriterion(
        key: 'rt_proficiency',
        label: 'RT Proficiency',
        description:
            'Demonstrates satisfactory RT proficiency: correct call-sign use, proper readback of ATC instructions, accurate position and intentions. CAP 1298 requires RT competency to be confirmed before first solo authorisation',
      ),
      ExerciseCriterion(
        key: 'post_solo_consolidation',
        label: 'Post-solo Consolidation Content',
        description:
            'After first solo, revisit: leaving the circuit, local area procedures, map reading, use of the compass, use of radio navigation aids for homing, re-joining the circuit. CAP 1298 lists these as required content during the solo consolidation phase',
      ),
    ],

    // ── Ex 15: Advanced Turning ─────────────────────────────────────────
    'ex_15': [
      ExerciseCriterion(
        key: 'steep_level_turns',
        label: 'Steep Level Turns (45°)',
        description:
            'Enters, maintains, and rolls out of 45° bank turns; altitude ±150 ft, speed ±15 kt, bank ±5°',
      ),
      ExerciseCriterion(
        key: 'back_pressure_power',
        label: 'Back Pressure and Power',
        description:
            'Applies increased back pressure and power to maintain altitude in steep turns',
      ),
      ExerciseCriterion(
        key: 'recovery_steep_turn',
        label: 'Recovery from Steep Turn',
        description:
            'Recognises and recovers from nose dropping in a steep turn without exceeding Vne or stalling',
      ),
      ExerciseCriterion(
        key: 'unusual_attitudes',
        label: 'Recovery from Unusual Attitudes',
        description:
            'Recovers from nose-high (lower nose, apply power, level wings) and nose-low (reduce power, level wings, ease out of dive)',
      ),
    ],

    // ── Ex 16: Forced Landing Without Power ─────────────────────────────
    'ex_16': [
      ExerciseCriterion(
        key: 'immediate_actions',
        label: 'Immediate Actions',
        description:
            'Adopts best glide speed promptly; selects nearest suitable field with wind assessment',
      ),
      ExerciseCriterion(
        key: 'field_selection',
        label: 'Field Selection (5 S\'s)',
        description:
            'Selects field using Size, Shape, Surface, Slope, Surroundings; checks for power lines and obstacles',
      ),
      ExerciseCriterion(
        key: 'approach_pattern',
        label: 'Glide Approach Pattern',
        description:
            'Plans and flies a workable approach (high key, low key) to reach the selected field at the correct point',
      ),
      ExerciseCriterion(
        key: 'cause_check',
        label: 'Engine Failure Cause Check',
        description:
            'Completes systematic cause check and attempts restart: fuel, mixture, carb heat, mags, primer',
      ),
      ExerciseCriterion(
        key: 'mayday_call',
        label: 'Mayday Call and Squawk 7700',
        description:
            'Transmits correct MAYDAY call (Mayday x3, callsign, nature, position, intentions, POB); sets 7700',
      ),
      ExerciseCriterion(
        key: 'securing_actions',
        label: 'Securing Actions',
        description:
            'Completes pre-landing actions: fuel OFF, mags OFF, master OFF, doors unlatched, harness tight',
      ),
    ],

    // ── Ex 17: Precautionary Landing ────────────────────────────────────
    'ex_17': [
      ExerciseCriterion(
        key: 'decision_to_divert',
        label: 'Decision to Divert or Land',
        description:
            'Makes timely decision to divert or make precautionary landing based on fuel, weather, or daylight',
      ),
      ExerciseCriterion(
        key: 'field_inspection',
        label: 'Low-level Field Inspection',
        description:
            'Conducts inspection pass(es) at safe height to assess surface, obstacles, wind direction, and approach path',
      ),
      ExerciseCriterion(
        key: 'powered_approach',
        label: 'Powered Approach to Field',
        description:
            'Flies a safe power-on approach with full flap to the selected field; maintains safe speed',
      ),
      ExerciseCriterion(
        key: 'pan_call',
        label: 'PAN PAN Call',
        description:
            'Transmits correct PAN PAN call with position, intentions, and POB; considers squawk 7700',
      ),
    ],

    // ── Ex 18A: Navigation ──────────────────────────────────────────────
    'ex_18_18a': [
      ExerciseCriterion(
        key: 'flight_planning',
        label: 'Pre-flight Planning (PLOG)',
        description:
            'Prepares navigation log: tracks, distances, headings (W/V applied), timings, fuel plan, safety altitude',
      ),
      ExerciseCriterion(
        key: 'weather_notams',
        label: 'Weather and NOTAMs',
        description:
            'Obtains and interprets Met Form 214/215, TAFs, METARs, and relevant NOTAMs for the route',
      ),
      ExerciseCriterion(
        key: 'departure_set_heading',
        label: 'Departure and Set Heading',
        description:
            'Departs overhead or from a known point; sets heading accurately at planned time and altitude',
      ),
      ExerciseCriterion(
        key: 'en_route_navigation',
        label: 'En-route Navigation',
        description:
            'Maintains track using map reading (1:500,000); identifies features; records times at waypoints',
      ),
      ExerciseCriterion(
        key: 'revised_eta',
        label: 'Revised ETA and Groundspeed',
        description:
            'Calculates actual groundspeed from time/distance; revises ETAs and fuel endurance',
      ),
      ExerciseCriterion(
        key: 'diversion',
        label: 'Diversion',
        description:
            'Plans and executes in-flight diversion: new track, distance (ruler/thumb), heading, time, fuel check',
      ),
    ],

    // ── Ex 18B: Navigation at Lower Levels ──────────────────────────────
    'ex_18_18b': [
      ExerciseCriterion(
        key: 'low_level_technique',
        label: 'Low-level Navigation Technique',
        description:
            'Adapts navigation technique for reduced altitude: shorter legs, more frequent map references',
      ),
      ExerciseCriterion(
        key: 'terrain_clearance',
        label: 'Terrain and Obstacle Clearance',
        description:
            'Maintains safe altitude above terrain and known obstacles; checks for power lines, masts',
      ),
      ExerciseCriterion(
        key: 'weather_deterioration',
        label: 'Deteriorating Weather Decision',
        description:
            'Recognises deteriorating visibility or cloud base; makes timely decision to turn back, divert, or land',
      ),
      ExerciseCriterion(
        key: 'airspace_awareness',
        label: 'Airspace Awareness',
        description:
            'Maintains awareness of controlled airspace boundaries, MATZ, ATZ, and danger areas at low level',
      ),
    ],

    // ── Ex 18C: Radio Navigation ────────────────────────────────────────
    'ex_18_18c': [
      ExerciseCriterion(
        key: 'vor_tracking',
        label: 'VOR — Tracking and Interception',
        description:
            'Tunes, identifies (Morse), and tracks TO/FROM a VOR radial; intercepts a specified radial',
      ),
      ExerciseCriterion(
        key: 'ndb_adf',
        label: 'NDB/ADF — Homing and Tracking',
        description:
            'Tunes, identifies NDB; uses ADF for homing to a beacon and tracking with wind correction',
      ),
      ExerciseCriterion(
        key: 'position_fixing',
        label: 'Position Fixing',
        description:
            'Obtains a position fix using two or more radio aids (VOR/VOR, VOR/DME, NDB cross-cut)',
      ),
      ExerciseCriterion(
        key: 'gps_awareness',
        label: 'GPS Awareness',
        description:
            'Understands GPS as a supplementary aid; aware of limitations (RAIM, database currency)',
      ),
      ExerciseCriterion(
        key: 'integration',
        label: 'Integration with Visual Nav',
        description:
            'Uses radio nav to confirm visual navigation; does not rely solely on radio aids',
      ),
    ],

    // ── Ex 18D: Cross-Country Navigation ───────────────────────────────────
    'ex_18_18d': [
      ExerciseCriterion(
        key: 'solo_planning',
        label: 'Solo Route Planning',
        description:
            'Plans a cross-country route without instructor assistance: selects turning points, measures tracks and distances from 1:500,000 chart, calculates headings (W/V applied), ETAs, and fuel required for all legs plus reserves',
      ),
      ExerciseCriterion(
        key: 'self_briefing',
        label: 'Self-briefing',
        description:
            'Obtains and interprets own weather forecast (TAF/METAR), NOTAMs, and ATIS for all aerodromes. Identifies any airspace conflicts on the planned route and considers need for a VFR flight plan',
      ),
      ExerciseCriterion(
        key: 'nav_tolerance',
        label: 'Navigation to Tolerance',
        description:
            'Arrives at each turning point within 3 nm and within 3 minutes of planned ETA. Heading held within +/- 5 degrees; altitude within +/- 150 ft of planned cruise level throughout',
      ),
      ExerciseCriterion(
        key: 'unfamiliar_aerodromes',
        label: 'Arrival at Unfamiliar Aerodromes',
        description:
            'Identifies and joins the circuit at each intermediate aerodrome correctly. Obtains ATIS or listens out before joining; makes correct radio calls; completes full-stop landing and logs arrival time',
      ),
      ExerciseCriterion(
        key: 'fuel_management',
        label: 'Fuel and Endurance Management',
        description:
            'Checks fuel state at each turning point and confirms endurance to next destination. Remains aware of fuel remaining vs planned consumption; decides to refuel en route if required',
      ),
      ExerciseCriterion(
        key: 'postflight_review',
        label: 'Post-flight Review',
        description:
            'Completes pilot logbook entry with route, times, and flight conditions. Compares planned vs actual ETAs and groundspeed; identifies cause of any discrepancies for future flights',
      ),
    ],

    // ── Ex 18E: Navigation Emergencies ─────────────────────────────────────
    'ex_18_18e': [
      ExerciseCriterion(
        key: 'diversion',
        label: 'In-flight Diversion',
        description:
            'Plans and executes diversion to alternate: selects alternate, measures new track with finger/ruler, estimates heading allowing for wind, calculates time and fuel, navigates to alternate without getting behind the aircraft',
      ),
      ExerciseCriterion(
        key: 'lost_procedure',
        label: 'Lost Procedure (LDST)',
        description:
            'Follows LDST when uncertain of position: Look (identify landmarks, check fuel/time), Decide (orbit if needed, climb if safe), Squawk (7700 if emergency, or request VDF/QDM), Talk (call ATC — position uncertain, request assistance)',
      ),
      ExerciseCriterion(
        key: 'radio_failure',
        label: 'Radio Failure Procedure',
        description:
            'Follows radio failure procedure: check volume/squelch/frequency, try alternative frequency (121.5 MHz), try alternative radio if fitted, squawk 7600, proceed to destination VFR, comply with light signals, land and report to ATC',
      ),
      ExerciseCriterion(
        key: 'instrument_failure',
        label: 'Partial Panel — Instrument Failure',
        description:
            'Identifies a failed instrument and continues to navigate using remaining instruments. Knows typical failure modes: static system blockage (altimeter, ASI, VSI all fail together), vacuum pump failure (AI, DI fail). Maintains control using standby instruments and cross-check',
      ),
      ExerciseCriterion(
        key: 'fuel_emergency',
        label: 'Fuel Emergency Decision-making',
        description:
            'Calculates fuel remaining and time to destination; declares PAN PAN or MAYDAY as appropriate if fuel becomes critical (minimum 30-minute VFR reserve). Diverts to nearest suitable aerodrome rather than pressing on',
      ),
      ExerciseCriterion(
        key: 'weather_deterioration',
        label: 'Unexpected Weather Deterioration',
        description:
            'Makes timely go/no-go decision when conditions deteriorate below planned minima. Options: climb above cloud (if SVFR/IMC rated and authorised), turn back, divert to aerodrome with better conditions, make precautionary landing. Never continues VFR flight into IMC',
      ),
    ],

    // ── Ex 19: Basic Instrument Flying / Night Rating ────────────────────
    'ex_19': [
      ExerciseCriterion(
        key: 'basic_instrument_context',
        label: 'Basic Instrument Flight Context',
        description:
            'CAP 1298 Exercise 19 covers Basic Instrument Flight: straight and level, climbs, descents, and 180° turns by sole reference to instruments (simulated IMC). The UK PPL Skills Test includes a 180° instrument turn (Standards Document 19(A) s3f). The Night Rating is a separate qualification requiring additional dual and solo hours; it is not the same as Exercise 19 and may be completed alongside or after the base PPL',
      ),
      ExerciseCriterion(
        key: 'night_preparation',
        label: 'Night Flying Preparation',
        description:
            'Completes night-specific preparation: torch, cockpit lighting, night vision adaptation (20-30 min)',
      ),
      ExerciseCriterion(
        key: 'night_taxi',
        label: 'Night Taxiing',
        description:
            'Taxis safely at night using taxy lights, centreline lighting, and reduced speed',
      ),
      ExerciseCriterion(
        key: 'night_takeoff_climb',
        label: 'Night Take-off and Climb',
        description:
            'Performs take-off transitioning to instruments immediately after rotation; maintains runway heading',
      ),
      ExerciseCriterion(
        key: 'night_circuit',
        label: 'Night Circuit',
        description:
            'Flies accurate night circuit using aerodrome and runway lighting references with instrument cross-check',
      ),
      ExerciseCriterion(
        key: 'night_approach_landing',
        label: 'Night Approach and Landing',
        description:
            'Uses VASI/PAPI for glide path; touches down in the lit runway area with correct technique',
      ),
      ExerciseCriterion(
        key: 'instrument_scan',
        label: 'Instrument Scan',
        description:
            'Maintains disciplined instrument scan (AI, ASI, Alt, DI, VSI) supplementing limited visual cues',
      ),
    ],
  };

  /// Returns criteria for the given exercise ID, or an empty list if none are defined.
  static List<ExerciseCriterion> forExercise(String exerciseId) {
    return exerciseCriteria[exerciseId] ?? const [];
  }
}
