/**
 * FlightPath — Firestore flashcard seed script
 *
 * Writes operational flashcards for all 22 exercise slots (19 exercises
 * + sub-exercises 10a, 10b, 18a, 18b, 18c) to the `flashcards` Firestore
 * collection. Cards are keyed by ID (e.g. 'ex_01_fc_0').
 *
 * Document schema matches Flashcard.fromFirestore() in the Flutter app:
 *   id          : String  — document ID (e.g. 'ex_01_fc_0')
 *   exercise_id : String  — parent exercise or sub-exercise ID
 *   front       : String  — question shown on the card face
 *   back        : String  — answer shown after flip
 *
 * PREREQUISITES:
 *   cd functions && npm install
 *   Place a serviceAccountKey.json in this directory (git-ignored):
 *     Firebase Console → Project Settings → Service Accounts → Generate New Private Key
 *
 * USAGE:
 *   node seed_flashcards.js              — writes all cards to Firestore
 *   node seed_flashcards.js --dry-run    — prints what would be written, no writes
 *   node seed_flashcards.js --exercise ex_01  — seed one exercise only
 *
 * NOTES:
 *   - Safe to re-run: uses set() (not create()), so existing docs are overwritten.
 *   - Firestore batches are capped at 500 ops; this script chunks at 400.
 *   - Run from the functions/ directory so the relative require path resolves.
 *   - exercise_id for sub-exercises uses the parent ID (e.g. 'ex_10') because
 *     that is how the app queries them — the sub-exercise is implicit in the ID.
 *     If the app queries by sub-exercise separately, update exercise_id accordingly.
 *
 * Content philosophy: operational training, NOT exam theory.
 * Cards cover key speeds, checklists, radio calls, airmanship decisions,
 * and instructor checkpoints for each exercise.
 */

'use strict';

const path = require('path');
const admin = require('firebase-admin');

// ---------------------------------------------------------------------------
// Parse CLI flags
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const exerciseFilter = (() => {
  const idx = args.indexOf('--exercise');
  return idx !== -1 ? args[idx + 1] : null;
})();

// ---------------------------------------------------------------------------
// Initialise Firebase Admin SDK
// ---------------------------------------------------------------------------

const serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.json');
try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('Firebase Admin initialised with service account key.');
} catch (_) {
  // Fall back to application default credentials (works in Cloud Shell / CI)
  admin.initializeApp();
  console.log('Firebase Admin initialised with application default credentials.');
}

const db = admin.firestore();
const COLLECTION = 'flashcards';
const BATCH_SIZE = 400;

// ---------------------------------------------------------------------------
// Flashcard data
// Note on exercise_id field: for sub-exercises (10a, 10b, 18a, 18b, 18c) we
// store the full compound key as the exercise_id so the app can fetch them
// with a single where('exercise_id', '==', 'ex_10_10a') query. Check your
// Dart flashcard provider query — adjust if it uses the parent ex_10 ID.
// ---------------------------------------------------------------------------

const flashcards = [

  // -------------------------------------------------------------------------
  // Exercise 1 — Familiarisation with the Aeroplane
  // -------------------------------------------------------------------------
  {
    id: 'ex_01_fc_0',
    exercise_id: 'ex_01',
    front: 'What are the four main flight controls on the PA-28 Warrior?',
    back: 'Ailerons (roll), elevator (pitch), rudder (yaw), and throttle (power). The rudder pedals also operate the nose-wheel steering on the ground.',
  },
  {
    id: 'ex_01_fc_1',
    exercise_id: 'ex_01',
    front: 'Which way does the PA-28 propeller rotate when viewed from the cockpit?',
    back: 'Clockwise. This produces a left-turning tendency on take-off (torque + slipstream effect), corrected with right rudder.',
  },
  {
    id: 'ex_01_fc_2',
    exercise_id: 'ex_01',
    front: 'Where is the fuel selector on the PA-28 and what are its positions?',
    back: 'On the lower-left side of the cockpit (between the seats / left side wall, depending on variant). Positions on the PA-28-161 Warrior II: LEFT, RIGHT, OFF — there is NO BOTH position. Switch tanks per the school SOP (typically every 30 minutes) and always confirm the selected tank has sufficient fuel before flight.',
  },
  {
    id: 'ex_01_fc_3',
    exercise_id: 'ex_01',
    front: 'Name the three primary flight instruments and the three engine instruments you should locate during familiarisation.',
    back: 'Flight: ASI, Altimeter, VSI. Engine: RPM gauge, oil temp/pressure, fuel gauges. Also locate the compass and turn coordinator.',
  },
  {
    id: 'ex_01_fc_4',
    exercise_id: 'ex_01',
    front: 'What does the instructor want to see during Ex 1?',
    back: 'That you can locate every control and instrument before touching them. Demonstrate a slow, deliberate scan of the cockpit — not random pointing.',
  },
  {
    id: 'ex_01_fc_5',
    exercise_id: 'ex_01',
    front: 'What is the PA-28-161 Warrior\'s MAUW (maximum all-up weight)?',
    back: '2,440 lb (1,107 kg). Check the weight and balance before every flight — loading affects both CG and performance figures.',
  },

  // -------------------------------------------------------------------------
  // Exercise 2 — Preparation for and Action after Flight
  // -------------------------------------------------------------------------
  {
    id: 'ex_02_fc_0',
    exercise_id: 'ex_02',
    front: 'What does the mnemonic WSTOMF cover in the external walk-round?',
    back: 'Wheels, Structure, Top (fuel caps, vents), Oil, Magnetos/electrics, Fuel. Use it as a memory jogger — walk the aircraft in a consistent direction every time.',
  },
  {
    id: 'ex_02_fc_1',
    exercise_id: 'ex_02',
    front: 'How do you check fuel quantity and quality during the external check?',
    back: 'Visually confirm level in both tanks matches gauge. Use a sampler cup: drain from the sump drain under each wing and the gascolator. Check for water (separates to the bottom, appears blue or colourless).',
  },
  {
    id: 'ex_02_fc_2',
    exercise_id: 'ex_02',
    front: 'What is the PA-28 oil quantity operating range, and what is the minimum for a solo flight?',
    back: 'Normal range: 6–8 quarts. Minimum before flight: 6 quarts. Do not depart with less than 6 qt.',
  },
  {
    id: 'ex_02_fc_3',
    exercise_id: 'ex_02',
    front: 'What do you check on the control surfaces during the walk-round?',
    back: 'Full and free movement, correct sense of deflection, no obstructions, hinges and pushrods secure, no damage. Check flaps for correct operation before engine start.',
  },
  {
    id: 'ex_02_fc_4',
    exercise_id: 'ex_02',
    front: 'What is the post-flight sequence after engine shutdown?',
    back: 'Throttle to idle, mags off, avionics off, fuel selector off, master off. Complete the flight log, refuel if required, secure the aircraft (chocks, tie-downs, pitot cover).',
  },
  {
    id: 'ex_02_fc_5',
    exercise_id: 'ex_02',
    front: 'What does the instructor want to see during the pre-flight check?',
    back: 'A methodical walk-round with physical contact on each item — not a glance. Any unserviceability must be reported immediately, not worked around.',
  },
  {
    id: 'ex_02_fc_6',
    exercise_id: 'ex_02',
    front: 'What checks must be completed before engine start?',
    back: 'Aircraft documents (C-ATOW: Certificate of Airworthiness, ARC, Noise cert., Tech log entry, Operating limits). Fuel caps secure, control locks removed, seat adjusted and locked, harness fastened.',
  },

  // -------------------------------------------------------------------------
  // Exercise 3 — Air Experience
  // -------------------------------------------------------------------------
  {
    id: 'ex_03_fc_0',
    exercise_id: 'ex_03',
    front: 'What is the normal cruising speed range for the PA-28-161?',
    back: 'Around 105–115 kt IAS at 75% power. At typical training altitudes (2,000–3,000 ft), power setting is approximately 2,300 RPM.',
  },
  {
    id: 'ex_03_fc_1',
    exercise_id: 'ex_03',
    front: 'Which altimeter subscale setting do you use below the transition altitude in the UK?',
    back: 'QNH — the local altimeter setting that makes the altimeter read altitude above mean sea level. QFE reads height above the airfield.',
  },
  {
    id: 'ex_03_fc_2',
    exercise_id: 'ex_03',
    front: 'What are the three axes of rotation and which control moves the aircraft around each?',
    back: 'Longitudinal axis (roll) — ailerons. Lateral axis (pitch) — elevator. Normal axis (yaw) — rudder.',
  },
  {
    id: 'ex_03_fc_3',
    exercise_id: 'ex_03',
    front: 'What is the lookout sequence you should use in straight and level cruise?',
    back: 'Systematic scan: left to right across the horizon in overlapping sectors, then check instruments, then repeat. Spend more time looking out than looking in.',
  },
  {
    id: 'ex_03_fc_4',
    exercise_id: 'ex_03',
    front: 'What does the instructor want from you on the first flight?',
    back: 'Light hands on the controls, lookout habit established, and the ability to follow through without fighting. You do not need to fly accurately yet — just feel the aeroplane.',
  },
  {
    id: 'ex_03_fc_5',
    exercise_id: 'ex_03',
    front: 'What is "following through" on the controls?',
    back: 'Resting your hands and feet on the controls while the instructor flies, feeling the inputs without applying your own force. Do not grip — rest.',
  },

  // -------------------------------------------------------------------------
  // Exercise 4 — Effects of Controls
  // -------------------------------------------------------------------------
  {
    id: 'ex_04_fc_0',
    exercise_id: 'ex_04',
    front: 'What happens to effectiveness of controls as airspeed increases?',
    back: 'Control effectiveness increases with speed — the same deflection produces a greater response. In the circuit at low speed, larger inputs are needed for the same effect.',
  },
  {
    id: 'ex_04_fc_1',
    exercise_id: 'ex_04',
    front: 'What is adverse yaw and when is it most noticeable?',
    back: 'When ailerons are applied, the down-going aileron creates more drag than the up-going one, yawing the nose toward the raised wing. Most noticeable at low speeds — corrected with co-ordinated rudder.',
  },
  {
    id: 'ex_04_fc_2',
    exercise_id: 'ex_04',
    front: 'What is the effect of power on pitch attitude on the PA-28?',
    back: 'Increasing power causes a pitch-up tendency (slipstream effect + torque). Reducing power causes a pitch-down. Always re-trim after a power change.',
  },
  {
    id: 'ex_04_fc_3',
    exercise_id: 'ex_04',
    front: 'What is the secondary effect of rudder?',
    back: 'Yaw causes the outer wing to travel faster, generating more lift, which rolls the aircraft in the direction of the yaw. Rudder → yaw → roll.',
  },
  {
    id: 'ex_04_fc_4',
    exercise_id: 'ex_04',
    front: 'What is trim and why is it used?',
    back: 'Trim removes residual control pressure so the pilot can fly hands-off at a desired attitude. Trim does not steer the aircraft — use controls to establish the attitude, then trim off the load.',
  },
  {
    id: 'ex_04_fc_5',
    exercise_id: 'ex_04',
    front: 'What does the instructor want to see during Ex 4?',
    back: 'Deliberate, single-axis inputs — one control at a time. Observe the effect fully, then return to neutral. No blended inputs yet. Clean reversal when asked.',
  },

  // -------------------------------------------------------------------------
  // Exercise 5 — Taxiing
  // -------------------------------------------------------------------------
  {
    id: 'ex_05_fc_0',
    exercise_id: 'ex_05',
    front: 'How do you steer the PA-28 during taxiing?',
    back: 'Differential braking and rudder pedals, which connect to the nose-wheel steering. Gentle pressure on the appropriate pedal to turn. Avoid riding the brakes.',
  },
  {
    id: 'ex_05_fc_1',
    exercise_id: 'ex_05',
    front: 'What is the maximum safe taxi speed?',
    back: 'Slow walking pace — roughly 5–10 kt. You should be able to stop within the cleared area at all times.',
  },
  {
    id: 'ex_05_fc_2',
    exercise_id: 'ex_05',
    front: 'What checks do you do during the power check (run-up)?',
    back: 'Run-up checklist: RPM to 2,000, check oil temp/pressure in green, test each magneto (RPM drop less than 150 rpm, no more than 75 rpm differential), check carb heat (slight RPM drop expected), check engine instruments. Return throttle to idle.',
  },
  {
    id: 'ex_05_fc_3',
    exercise_id: 'ex_05',
    front: 'What flight instruments do you check during taxi for correct operation?',
    back: 'Compass: changes direction correctly as you turn. Turn coordinator: ball and needle respond to turns. ASI: near zero. Altimeter: set to QNH and reads field elevation.',
  },
  {
    id: 'ex_05_fc_4',
    exercise_id: 'ex_05',
    front: 'What should you do before crossing any runway?',
    back: 'Stop, look both ways along the full runway length, confirm ATC clearance, then cross promptly. Never assume the runway is clear — always look.',
  },
  {
    id: 'ex_05_fc_5',
    exercise_id: 'ex_05',
    front: 'What control positions do you use taxiing into a headwind vs. a tailwind?',
    back: 'Headwind: stick back (to keep elevator neutral or slightly up — prevents nose from pitching in gusts). Tailwind: stick forward. Crosswind from left: aileron into wind (stick left). Crosswind from right: stick right.',
  },

  // -------------------------------------------------------------------------
  // Exercise 6 — Straight and Level Flight
  // -------------------------------------------------------------------------
  {
    id: 'ex_06_fc_0',
    exercise_id: 'ex_06',
    front: 'What is the PA-28 typical cruise attitude for straight and level at 2,000 ft?',
    back: 'Cowling approximately one to two finger-widths below the horizon. The exact picture changes with weight and density altitude — set power, then adjust attitude to achieve target speed, then trim.',
  },
  {
    id: 'ex_06_fc_1',
    exercise_id: 'ex_06',
    front: 'What is the attitude-power-trim sequence for establishing straight and level?',
    back: '1. Set attitude visually (horizon reference). 2. Set power (typically 2,300 RPM for cruise). 3. Let speed stabilise. 4. Trim off residual back-pressure. Check and adjust until no force is needed.',
  },
  {
    id: 'ex_06_fc_2',
    exercise_id: 'ex_06',
    front: 'How do you maintain a constant altitude during straight and level?',
    back: 'Primary reference is the horizon — not the altimeter. The altimeter is used to verify, not to fly from. If altitude drifts, make a small attitude correction, do not chase the altimeter needle.',
  },
  {
    id: 'ex_06_fc_3',
    exercise_id: 'ex_06',
    front: 'What is the scan pattern for maintaining straight and level?',
    back: '80% outside on the horizon. Instrument scan: ASI, altimeter, heading indicator, VSI. Return outside. Never fixate on one instrument.',
  },
  {
    id: 'ex_06_fc_4',
    exercise_id: 'ex_06',
    front: 'What RPM setting gives approximately 65 kt (slow cruise) on the PA-28?',
    back: 'Approximately 1,900–2,000 RPM. Exact figure varies with altitude and weight — use the POH performance tables for precise numbers.',
  },
  {
    id: 'ex_06_fc_5',
    exercise_id: 'ex_06',
    front: 'What does the instructor want to see during Ex 6?',
    back: 'Steady altitude (+/- 100 ft), steady heading (+/- 5 degrees), correct lookout priority, and smooth trim technique. Hands-off after trimming to confirm balance.',
  },

  // -------------------------------------------------------------------------
  // Exercise 7 — Climbing
  // -------------------------------------------------------------------------
  {
    id: 'ex_07_fc_0',
    exercise_id: 'ex_07',
    front: 'What is the PA-28-161 best rate of climb speed (Vy)?',
    back: 'Vy = 79 kt IAS. Used when you need the most altitude gained in the shortest time (e.g., after take-off to clear obstacles).',
  },
  {
    id: 'ex_07_fc_1',
    exercise_id: 'ex_07',
    front: 'What is the PA-28-161 best angle of climb speed (Vx)?',
    back: 'Vx = 63 kt IAS. Used to clear an obstacle in the shortest horizontal distance. Not used in the cruise climb — use Vy for normal training climbs.',
  },
  {
    id: 'ex_07_fc_2',
    exercise_id: 'ex_07',
    front: 'What is the sequence for entering a climb from straight and level?',
    back: '1. Look out (HASELL not required here, but check clear). 2. Apply full power. 3. Raise nose to climb attitude. 4. Trim. 5. Check engine temps and pressures are in the green.',
  },
  {
    id: 'ex_07_fc_3',
    exercise_id: 'ex_07',
    front: 'Why must you use carb heat before reducing power after a prolonged climb?',
    back: 'Engine cooling during descent can cause carburettor icing. Apply carb heat before throttling back to prevent ice forming in the venturi. Return to cold air once clear of the icing risk band.',
  },
  {
    id: 'ex_07_fc_4',
    exercise_id: 'ex_07',
    front: 'What is the sequence for levelling off from a climb?',
    back: '1. Lower nose to cruise attitude (horizon reference) at approximately 50 ft before target altitude. 2. Allow speed to increase to cruise speed. 3. Reduce power to cruise setting. 4. Trim.',
  },
  {
    id: 'ex_07_fc_5',
    exercise_id: 'ex_07',
    front: 'What does the instructor want to see during climbing?',
    back: 'Lookout priority increased (nose-high attitude blocks the view ahead — S-turns may be needed). Correct Vy attitude held, engine temps monitored, accurate levelling off.',
  },

  // -------------------------------------------------------------------------
  // Exercise 8 — Descending
  // -------------------------------------------------------------------------
  {
    id: 'ex_08_fc_0',
    exercise_id: 'ex_08',
    front: 'What is the typical glide descent speed for the PA-28 and what is the approximate glide ratio?',
    back: 'Best glide speed: approximately 73 kt IAS. Glide ratio approximately 9:1 (about 1.5 nm per 1,000 ft lost in still air).',
  },
  {
    id: 'ex_08_fc_1',
    exercise_id: 'ex_08',
    front: 'What is the sequence for entering a powered descent?',
    back: '1. Reduce power to the desired setting. 2. Lower nose to descent attitude. 3. Trim. 4. Apply carb heat if power is low (below approximately 1,500 RPM).',
  },
  {
    id: 'ex_08_fc_2',
    exercise_id: 'ex_08',
    front: 'What is the sequence for levelling off from a descent?',
    back: '1. Approximately 50–100 ft before target altitude, increase power. 2. Raise nose to level attitude. 3. Remove carb heat when power is back to cruise. 4. Trim.',
  },
  {
    id: 'ex_08_fc_3',
    exercise_id: 'ex_08',
    front: 'Why does the nose need to be raised when power is applied during level-off from a glide?',
    back: 'Increasing power creates a pitch-up tendency (slipstream effect). If you apply power without adjusting attitude, you will climb instead of level off. Anticipate and control the pitch change.',
  },
  {
    id: 'ex_08_fc_4',
    exercise_id: 'ex_08',
    front: 'During a glide descent, what do you use carb heat for and when?',
    back: 'Carb heat prevents icing in the carburettor venturi when running at low power. Apply hot air when below approximately 1,500 RPM. Remember: carb heat reduces engine power slightly — expect a small RPM drop.',
  },
  {
    id: 'ex_08_fc_5',
    exercise_id: 'ex_08',
    front: 'What does the instructor want to see during Ex 8?',
    back: 'Smooth power reduction, correct attitude for the chosen descent speed, hands-off trim check, and an accurate level-off without chasing the altimeter.',
  },

  // -------------------------------------------------------------------------
  // Exercise 9 — Turning
  // -------------------------------------------------------------------------
  {
    id: 'ex_09_fc_0',
    exercise_id: 'ex_09',
    front: 'What bank angle is used for a medium level turn in training?',
    back: '30 degrees angle of bank. Steeper than 30 degrees is considered a steep turn (Ex 15). In the circuit, use 15–20 degrees.',
  },
  {
    id: 'ex_09_fc_1',
    exercise_id: 'ex_09',
    front: 'Why does the nose tend to drop during a turn, and how do you prevent it?',
    back: 'The horizontal lift component of the banked wing no longer fully supports the aircraft weight, so vertical lift decreases. Maintain altitude by applying small back-pressure to increase angle of attack.',
  },
  {
    id: 'ex_09_fc_2',
    exercise_id: 'ex_09',
    front: 'What is the sequence for rolling into a medium level turn?',
    back: '1. Lookout in the direction of turn. 2. Apply aileron to desired bank angle. 3. Apply co-ordinated rudder (same direction). 4. Apply back-pressure to maintain altitude. 5. Trim. 6. Level lookout ahead.',
  },
  {
    id: 'ex_09_fc_3',
    exercise_id: 'ex_09',
    front: 'How many degrees before the target heading do you start to roll out of a turn?',
    back: 'Start rollout approximately half the bank angle before the target heading. At 30 degrees bank, begin rolling out approximately 15 degrees early.',
  },
  {
    id: 'ex_09_fc_4',
    exercise_id: 'ex_09',
    front: 'What does a correctly balanced turn look and feel like?',
    back: 'Ball centred in the balance indicator, no skid or slip sensation, altitude maintained. An unbalanced turn is inefficient and, at low speed, increases stall risk.',
  },
  {
    id: 'ex_09_fc_5',
    exercise_id: 'ex_09',
    front: 'What does the instructor want to see during Ex 9?',
    back: 'Lookout before every turn, co-ordinated entry and exit, altitude maintained throughout (+/- 100 ft), and rollout on the correct heading (+/- 5 degrees).',
  },

  // -------------------------------------------------------------------------
  // Exercise 10A — Slow Flight
  // -------------------------------------------------------------------------
  {
    id: 'ex_10_10a_fc_0',
    exercise_id: 'ex_10_10a',
    front: 'What is the target speed for slow flight on the PA-28?',
    back: 'Approximately 1.2 x Vs1 — around 80 kt, or as briefed by your instructor. The aim is to fly at the minimum speed where the aircraft remains controllable and manoeuvrable.',
  },
  {
    id: 'ex_10_10a_fc_1',
    exercise_id: 'ex_10_10a',
    front: 'What is the sequence for entering slow flight?',
    back: '1. HASELL check. 2. Note the attitude. 3. Gradually reduce power while raising the nose to maintain altitude. 4. As speed reduces, add flap in stages (10° then 25°). 5. Increase power to maintain altitude at the target speed.',
  },
  {
    id: 'ex_10_10a_fc_2',
    exercise_id: 'ex_10_10a',
    front: 'Why is the throttle the primary altitude control in slow flight?',
    back: 'At high angles of attack, raising the nose further will stall the wing rather than climb. Power controls height; attitude controls speed. This is reversed from normal cruise.',
  },
  {
    id: 'ex_10_10a_fc_3',
    exercise_id: 'ex_10_10a',
    front: 'What aural and physical cues indicate you are approaching the stall during slow flight?',
    back: 'Stall warning horn (typically 5–10 kt above stall speed), sloppy control feel, airframe buffet, and the nose wanting to drop. React before the horn becomes continuous.',
  },
  {
    id: 'ex_10_10a_fc_4',
    exercise_id: 'ex_10_10a',
    front: 'What is HASELL and when must you do it?',
    back: 'Height (sufficient to recover), Airframe (set for exercise: flaps, gear), Security (harness tight, hatches closed, no loose items), Engine (temps and pressures green, carb heat as required), Location (clear of cloud, built-up areas, controlled airspace), Lookout (clearing turns, 180 degrees each side).',
  },
  {
    id: 'ex_10_10a_fc_5',
    exercise_id: 'ex_10_10a',
    front: 'What does the instructor want to see during slow flight?',
    back: 'Controlled flight at low speed with balance maintained, heading within 10 degrees, altitude within 100 ft. Prompt recovery to normal cruise when asked.',
  },

  // -------------------------------------------------------------------------
  // Exercise 10B — Stalling
  // -------------------------------------------------------------------------
  {
    id: 'ex_10_10b_fc_0',
    exercise_id: 'ex_10_10b',
    front: 'What is the PA-28-161 stall speed clean (Vs1)?',
    back: 'Vs1 = 66 kt IAS (flaps up, wings level, at MAUW). This is the clean configuration stall. With full flap (Vs0), it is approximately 54 kt.',
  },
  {
    id: 'ex_10_10b_fc_1',
    exercise_id: 'ex_10_10b',
    front: 'What is the immediate action on recognising a stall?',
    back: '1. Reduce angle of attack — apply positive forward pressure on the stick (do not snatch). 2. Apply full power. 3. Level the wings with co-ordinated rudder. 4. Retract flap in stages as speed allows. 5. Recover to straight and level.',
  },
  {
    id: 'ex_10_10b_fc_2',
    exercise_id: 'ex_10_10b',
    front: 'What is the minimum height for carrying out stalling exercises?',
    back: 'Typically 3,000 ft AGL or as briefed by your instructor. Recovery from a stall can take 300–500 ft. Always check your HASELL before stalling.',
  },
  {
    id: 'ex_10_10b_fc_3',
    exercise_id: 'ex_10_10b',
    front: 'Why is a stall in the turn more dangerous than a stall in straight and level?',
    back: 'In a banked turn, the inner wing is slower and stalls first, causing an uncommanded roll. If the rudder is misapplied the aircraft can enter an incipient spin. Maintain co-ordination throughout.',
  },
  {
    id: 'ex_10_10b_fc_4',
    exercise_id: 'ex_10_10b',
    front: 'What power setting do you use to approach the stall in a clean stall exercise?',
    back: 'Power off (throttle to idle). In the approach-to-land stall (flaps extended), power is also at idle. In some exercises partial power is used to demonstrate stall at higher speed — follow the briefing.',
  },
  {
    id: 'ex_10_10b_fc_5',
    exercise_id: 'ex_10_10b',
    front: 'What does the instructor want to see during stalling practice?',
    back: 'Recognition early (horn, buffet), clean recovery action with no height loss beyond approximately 200 ft, no secondary stall, and a composed re-establishment of straight and level.',
  },
  {
    id: 'ex_10_10b_fc_6',
    exercise_id: 'ex_10_10b',
    front: 'What is an incipient spin and how is it prevented?',
    back: 'The first one to one-and-a-half turns of an unintentional spin entry — the aircraft yaws and rolls rapidly at or beyond the stall. Prevent by maintaining co-ordinated flight (ball centred) when flying at low speed.',
  },

  // -------------------------------------------------------------------------
  // Exercise 11 — Spin Awareness and Recovery
  // -------------------------------------------------------------------------
  {
    id: 'ex_11_fc_0',
    exercise_id: 'ex_11',
    front: 'What is the PARE recovery sequence for a spin?',
    back: 'Power off. Ailerons neutral. Rudder — full opposite to direction of rotation. Elevator — forward to unstall the wing. Hold until rotation stops, then centralise rudder and recover from the dive.',
  },
  {
    id: 'ex_11_fc_1',
    exercise_id: 'ex_11',
    front: 'What two conditions must exist simultaneously for a spin to develop?',
    back: 'The aircraft must be stalled AND yawing (one wing stalls before the other due to asymmetric airflow). Either condition alone will not produce a spin.',
  },
  {
    id: 'ex_11_fc_2',
    exercise_id: 'ex_11',
    front: 'Why is opposite rudder applied in the PARE sequence before forward elevator?',
    back: 'The spinning motion must first be arrested — applying forward elevator before stopping the yaw will drive the nose down in the turn, increasing the dive rate without stopping the spin.',
  },
  {
    id: 'ex_11_fc_3',
    exercise_id: 'ex_11',
    front: 'What is the minimum safe height for intentional spinning exercises?',
    back: 'As per your instructor\'s brief — typically 5,000 ft AGL. Recovery can take 1,000+ ft and must be completed well before the minimum recovery height.',
  },
  {
    id: 'ex_11_fc_4',
    exercise_id: 'ex_11',
    front: 'What does the instructor want to see during spin awareness exercises?',
    back: 'Recognition of the spin entry (autorotation onset), prompt and correct PARE application, clean recovery without secondary stall, and accurate height reporting at each stage.',
  },
  {
    id: 'ex_11_fc_5',
    exercise_id: 'ex_11',
    front: 'What are the common situations that lead to an accidental spin in circuit flying?',
    back: 'Overshooting the final turn and tightening the turn at low speed with base-to-final cross-controlling (inside rudder + opposite aileron). Causes an asymmetric stall. Stay co-ordinated at all times below 500 ft.',
  },

  // -------------------------------------------------------------------------
  // Exercise 12 — Take-off and Climb to Downwind
  // -------------------------------------------------------------------------
  {
    id: 'ex_12_fc_0',
    exercise_id: 'ex_12',
    front: 'What is the PA-28-161 rotate speed (Vr) for a normal take-off?',
    back: 'Vr is approximately 60–65 kt. Hold the nose on the centreline, apply gentle back-pressure at 60 kt and the aircraft will fly off naturally. Do not haul the nose up.',
  },
  {
    id: 'ex_12_fc_1',
    exercise_id: 'ex_12',
    front: 'What is the PA-28 Vx and Vy for obstacle clearance and normal climb after take-off?',
    back: 'Vx = 63 kt (best angle — use only if there is an obstacle). Vy = 79 kt (best rate — use for all normal climbs). Transition from Vx to Vy once clear of any obstacle.',
  },
  {
    id: 'ex_12_fc_2',
    exercise_id: 'ex_12',
    front: 'What are the pre-take-off checks (FREDA + TCIN sequence)?',
    back: 'FREDA: Fuel (on BOTH, sufficient, caps secure), Radio (correct frequency, ATIS obtained), Engine (temps and pressures green, carb heat off), DI (aligned with compass), Altimeter (QNH set). Then TCIN: Transponder, Carb heat off, Instruments checked, Notify ATC.',
  },
  {
    id: 'ex_12_fc_3',
    exercise_id: 'ex_12',
    front: 'What do you do if the engine fails at 200 ft on take-off?',
    back: 'Do not attempt to turn back. Lower the nose to maintain flying speed. Land ahead or within 30 degrees either side. Aim for the best available surface. Declare emergency if time allows.',
  },
  {
    id: 'ex_12_fc_4',
    exercise_id: 'ex_12',
    front: 'What is the flap setting for a normal take-off on the PA-28?',
    back: 'Flaps up for a normal take-off on a paved runway of adequate length. 10 degrees flap may be used for a short-field take-off — check the POH for the appropriate setting.',
  },
  {
    id: 'ex_12_fc_5',
    exercise_id: 'ex_12',
    front: 'What does the instructor want to see on take-off?',
    back: 'Positive application of right rudder to maintain centreline during the take-off roll, smooth rotation at Vr, climb at Vy, and lookout for other circuit traffic as soon as airborne.',
  },

  // -------------------------------------------------------------------------
  // Exercise 13 — Circuit, Approach and Landing
  // -------------------------------------------------------------------------
  {
    id: 'ex_13_fc_0',
    exercise_id: 'ex_13',
    front: 'What are the five legs of the circuit and their approximate altitudes/speeds?',
    back: 'Upwind: climb to 500 ft. Crosswind: turn at 500 ft, climb to circuit height (usually 1,000 ft QFE). Downwind: 1,000 ft, ~90 kt. Base: descend, 75 kt, flap 25°. Final: 65–70 kt, full flap, established 3-degree glideslope.',
  },
  {
    id: 'ex_13_fc_1',
    exercise_id: 'ex_13',
    front: 'What is the BUMFICH downwind checks mnemonic?',
    back: 'Brakes (off/tested), Undercarriage (down and locked — fixed on PA-28, verify visually), Mixture (rich), Fuel (selected to fuller tank — PA-28-161 has LEFT/RIGHT/OFF only, no BOTH; sufficient quantity), Instruments (pressures and temps in green, altimeter QFE), Carb heat (on), Hatches/Harness (secure).',
  },
  {
    id: 'ex_13_fc_2',
    exercise_id: 'ex_13',
    front: 'What is the target threshold crossing speed and attitude on final?',
    back: 'Approximately 65 kt over the threshold in the PA-28-161 with full flap. Aim for a constant-angle approach — if high, close throttle; if low, add power.',
  },
  {
    id: 'ex_13_fc_3',
    exercise_id: 'ex_13',
    front: 'What is the flare technique on the PA-28?',
    back: 'At approximately 15–20 ft, progressively raise the nose to reduce the rate of descent while slowly closing the throttle. Aim to reach the two-point attitude (main wheels first) as forward speed diminishes to walking pace.',
  },
  {
    id: 'ex_13_fc_4',
    exercise_id: 'ex_13',
    front: 'What is a go-around (missed approach) initiation sequence?',
    back: '1. Full power immediately. 2. Attitude — climb attitude. 3. Carb heat off once power is applied. 4. Flap to 25° (if full flap selected). 5. Positive rate of climb — retract remaining flap in stages. 6. Notify ATC.',
  },
  {
    id: 'ex_13_fc_5',
    exercise_id: 'ex_13',
    front: 'What radio call do you make joining the circuit at an AFIS/A2A airfield?',
    back: '"[Callsign] joining [leg] for runway [number], [field] radio." e.g. "G-ABCD joining downwind runway 23, Turweston radio." Listen for any conflicting traffic before and after.',
  },
  {
    id: 'ex_13_fc_6',
    exercise_id: 'ex_13',
    front: 'What does the instructor want to see in Ex 13?',
    back: 'Stable approach by 500 ft on final, correct glidepath, clear go-around decision made early if not stabilised, consistent touchdowns within the target zone, and radio calls made without losing aircraft control.',
  },

  // -------------------------------------------------------------------------
  // Exercise 14 — First Solo
  // -------------------------------------------------------------------------
  {
    id: 'ex_14_fc_0',
    exercise_id: 'ex_14',
    front: 'Before your first solo, what criteria does your instructor assess?',
    back: 'Consistent circuit pattern, stable approaches, safe landings without assistance, correct radio calls, and the ability to execute a go-around without prompting.',
  },
  {
    id: 'ex_14_fc_1',
    exercise_id: 'ex_14',
    front: 'What is the most common mental error on first solo?',
    back: 'Rushing. Without the instructor next to you, it is easy to speed up the pre-take-off checks or compress the downwind. Fly the same rhythm as dual — slower if anything.',
  },
  {
    id: 'ex_14_fc_2',
    exercise_id: 'ex_14',
    front: 'What should you do if you are not happy with an approach?',
    back: 'Go around — immediately and without hesitation. On solo, there is no pressure to land. A go-around is always the right decision if there is any doubt.',
  },
  {
    id: 'ex_14_fc_3',
    exercise_id: 'ex_14',
    front: 'What documentation does your instructor complete before releasing you to solo?',
    back: 'A supervised solo endorsement in your student pilot logbook or equivalent training record, and verbal confirmation that the aircraft is in limits for solo flight (weight within solo CG envelope).',
  },
  {
    id: 'ex_14_fc_4',
    exercise_id: 'ex_14',
    front: 'What does "sole occupant" mean for aircraft handling on your first solo?',
    back: 'The aircraft is lighter. With one person instead of two, the stall speed and rotate speed are slightly lower. Rotation and flare will happen at a slightly lower IAS and the aircraft will feel more responsive.',
  },
  {
    id: 'ex_14_fc_5',
    exercise_id: 'ex_14',
    front: 'What is the correct response if you have a problem airborne on your first solo?',
    back: 'Declare a MAYDAY or PAN immediately on the current frequency. Do not feel embarrassed. ATC and your instructor would rather you call early than try to handle it silently.',
  },

  // -------------------------------------------------------------------------
  // Exercise 15 — Advanced Turning
  // -------------------------------------------------------------------------
  {
    id: 'ex_15_fc_0',
    exercise_id: 'ex_15',
    front: 'What bank angle defines a steep turn in training?',
    back: '45 degrees angle of bank. At 45 degrees the load factor is 1.41 g (the cosine rule: 1/cos 45° = 1.41). The stall speed increases by approximately 20%.',
  },
  {
    id: 'ex_15_fc_1',
    exercise_id: 'ex_15',
    front: 'What is the load factor at 45 degrees bank and how does it affect stall speed?',
    back: 'Load factor = 1.41 g. Stall speed in the turn = Vs (straight and level) x √1.41 = approximately 1.19 x Vs1. For the PA-28 (Vs1 = 66 kt), stall speed in a 45-degree turn is approximately 78 kt.',
  },
  {
    id: 'ex_15_fc_2',
    exercise_id: 'ex_15',
    front: 'Why does more back-pressure and power become necessary in a steep turn?',
    back: 'The vertical component of lift is reduced (more lift is directed inward). Additional back-pressure increases the angle of attack to compensate. Additional power counters the drag increase at higher angle of attack.',
  },
  {
    id: 'ex_15_fc_3',
    exercise_id: 'ex_15',
    front: 'What are the symptoms of a spiral dive and how do you recover?',
    back: 'Rapidly increasing airspeed in a steep turn, increasing rate of descent, high bank angle. Recovery: reduce power, level the wings, gently pull out of the dive. Do not pull before wings are level — the g-loading will increase.',
  },
  {
    id: 'ex_15_fc_4',
    exercise_id: 'ex_15',
    front: 'What HASELL items are particularly important before advanced turning?',
    back: 'Height: sufficient for recovery (minimum 3,000 ft AGL). Lookout: full clearing turns — steep turns obscure the sky above. Location: away from controlled airspace and built-up areas.',
  },
  {
    id: 'ex_15_fc_5',
    exercise_id: 'ex_15',
    front: 'What does the instructor want to see in a steep turn?',
    back: 'Entry at 45 degrees bank held throughout, altitude maintained +/- 100 ft, airspeed within +/- 10 kt, and a clean rollout onto the target heading.',
  },

  // -------------------------------------------------------------------------
  // Exercise 16 — Forced Landing Without Power (PFL)
  // -------------------------------------------------------------------------
  {
    id: 'ex_16_fc_0',
    exercise_id: 'ex_16',
    front: 'What is the first action following an unexpected engine failure in flight?',
    back: 'Maintain flying speed — lower the nose to best glide speed (approximately 73 kt on the PA-28) immediately. Do not pull back. Speed gives you options.',
  },
  {
    id: 'ex_16_fc_1',
    exercise_id: 'ex_16',
    front: 'What is the standard PFL sequence once the nose is lowered?',
    back: '1. Best glide speed. 2. Select a field. 3. EFATO drill: Fuel (switch tanks / check on), Ignition (both mags), Throttle (full). 4. Mayday call. 5. Squawk 7700. 6. Fly the forced landing pattern.',
  },
  {
    id: 'ex_16_fc_2',
    exercise_id: 'ex_16',
    front: 'What makes a good forced landing field?',
    back: 'Large, flat, no obstacles on approach, firm surface (avoid crops in summer, snow, wet plough). Wind direction: land into wind if possible. Avoid power lines — they are nearly invisible from the air.',
  },
  {
    id: 'ex_16_fc_3',
    exercise_id: 'ex_16',
    front: 'Where do you aim to be at the "high key" and "low key" points?',
    back: 'High key: overhead the selected field at 1,000 ft AGL, positioned to set up a circuit. Low key: abeam the landing threshold at 500–600 ft AGL, similar to a normal downwind position.',
  },
  {
    id: 'ex_16_fc_4',
    exercise_id: 'ex_16',
    front: 'What HASELL items apply before practising PFLs?',
    back: 'Height: minimum 3,000 ft. Lookout: clear below — you will be descending steeply. Location: suitable fields beneath you and not over populated areas. Brief instructor before reducing power unexpectedly.',
  },
  {
    id: 'ex_16_fc_5',
    exercise_id: 'ex_16',
    front: 'What does the instructor want to see in a PFL exercise?',
    back: 'Immediate speed control, a decisive field selection within 30 seconds, correct key positions, a stable final approach, and a planned go-around at or above 300 ft.',
  },

  // -------------------------------------------------------------------------
  // Exercise 17 — Precautionary Landing
  // -------------------------------------------------------------------------
  {
    id: 'ex_17_fc_0',
    exercise_id: 'ex_17',
    front: 'What is the difference between a precautionary landing and a forced landing?',
    back: 'A precautionary landing is planned — the engine is still running, but continuing flight is inadvisable (weather, fuel state, illness, lost). A forced landing is an emergency — the engine has stopped or is about to stop.',
  },
  {
    id: 'ex_17_fc_1',
    exercise_id: 'ex_17',
    front: 'What is the survey pass sequence for a precautionary landing?',
    back: '1. High survey at 500 ft AGL to assess the field size, surface, slope, and obstacles. 2. Low survey at 200 ft over the field boundary to confirm surface condition. 3. Land on the third pass if satisfied.',
  },
  {
    id: 'ex_17_fc_2',
    exercise_id: 'ex_17',
    front: 'What speed is used for the low-level survey pass?',
    back: 'Approximately 75 kt with partial flap (25 degrees) — slow enough to observe detail but not so slow that the aircraft is difficult to control if a missed approach is required.',
  },
  {
    id: 'ex_17_fc_3',
    exercise_id: 'ex_17',
    front: 'What radio calls should be made before a precautionary landing?',
    back: 'Declare a PAN PAN on 121.5 MHz or the last ATC frequency used. State callsign, aircraft type, position, nature of the problem, intentions, and number of persons on board.',
  },
  {
    id: 'ex_17_fc_4',
    exercise_id: 'ex_17',
    front: 'What does the instructor want to see during Ex 17?',
    back: 'Airmanship: a decisive, systematic assessment before committing. Correct survey heights and speeds. Readiness to go-around at any point. Radio call completed without neglecting aircraft control.',
  },
  {
    id: 'ex_17_fc_5',
    exercise_id: 'ex_17',
    front: 'What does the 1-in-60 rule tell you during the precautionary landing pattern?',
    back: '1 degree of heading error produces 1 nm track error at 60 nm. For a short survey pass this matters less than position awareness — but it reinforces the need to keep an eye on the field position throughout.',
  },

  // -------------------------------------------------------------------------
  // Exercise 18A — Navigation
  // -------------------------------------------------------------------------
  {
    id: 'ex_18_18a_fc_0',
    exercise_id: 'ex_18_18a',
    front: 'What is the PLOG and what goes on it?',
    back: 'Pilot\'s Log — the written navigation plan. Contains: waypoints, tracks (True and Magnetic), distances, wind correction angles, headings (M), groundspeeds, ETIs (elapsed time intervals), and ETAs. Prepared before departure.',
  },
  {
    id: 'ex_18_18a_fc_1',
    exercise_id: 'ex_18_18a',
    front: 'What is the formula for calculating wind correction angle (WCA)?',
    back: 'WCA = (Wind speed / TAS) x sin(wind angle off track). For mental DR use the 1-in-60 rule: if the wind is blowing X kt off the track at an angle of Y degrees, the drift is approximately X/TAS x Y/60 in minutes per nm.',
  },
  {
    id: 'ex_18_18a_fc_2',
    exercise_id: 'ex_18_18a',
    front: 'What are the "Three Ts" when passing a waypoint?',
    back: 'Time — note the actual time over the fix. Turn — turn onto the next heading. Talk — make any required radio call. Do them in that order.',
  },
  {
    id: 'ex_18_18a_fc_3',
    exercise_id: 'ex_18_18a',
    front: 'What is a pinpoint and when do you use it?',
    back: 'A pinpoint is positive identification of a ground feature that confirms your position. Use pinpoints to check planned groundspeed and revise your ETA. If you cannot confirm your position, go to the lost procedure immediately — do not guess.',
  },
  {
    id: 'ex_18_18a_fc_4',
    exercise_id: 'ex_18_18a',
    front: 'What is the FREDA check and when should it be performed en route?',
    back: 'Fuel, Radio, Engine, DI (aligned to compass), Altimeter. Complete every 15–20 minutes during the cruise. Set a timer — do not wait until you notice something is wrong.',
  },
  {
    id: 'ex_18_18a_fc_5',
    exercise_id: 'ex_18_18a',
    front: 'What does the instructor want to see during a navigation exercise?',
    back: 'Planning complete before departure, confident map reading at waypoints, Three Ts at each fix, FREDA checks done without prompting, and good lookout maintained throughout — navigation does not reduce collision risk.',
  },
  {
    id: 'ex_18_18a_fc_6',
    exercise_id: 'ex_18_18a',
    front: 'What variation applies over the UK and which way do you apply it?',
    back: 'Currently approximately 0–2 degrees West in most of England (check your chart for the specific area). Variation West — Magnetic Best (True to Magnetic, add Westerly variation). Variation East — Magnetic Least (subtract).',
  },

  // -------------------------------------------------------------------------
  // Exercise 18B — Navigation at Lower Levels
  // -------------------------------------------------------------------------
  {
    id: 'ex_18_18b_fc_0',
    exercise_id: 'ex_18_18b',
    front: 'Why does low-level navigation require a faster map-reading rate?',
    back: 'Features pass beneath you much faster at low level. At 100 kt and 500 ft, you have seconds to identify each feature before it disappears. You must read ahead on the map — not identify what you just passed over.',
  },
  {
    id: 'ex_18_18b_fc_1',
    exercise_id: 'ex_18_18b',
    front: 'What are the minimum safe altitudes for flying over populated areas in the UK?',
    back: 'Under the Rules of the Air: not below 1,000 ft above the highest fixed object within 600 m horizontally. Over open country: at least 500 ft AGL unless landing or taking off.',
  },
  {
    id: 'ex_18_18b_fc_2',
    exercise_id: 'ex_18_18b',
    front: 'What additional hazards are significant at low level that are less critical at altitude?',
    back: 'Power lines (nearly invisible from ahead), mast and aerials (unmarked or undermarked on charts), bird strike risk, reduced reaction time for emergency landing, and microclimate turbulence.',
  },
  {
    id: 'ex_18_18b_fc_3',
    exercise_id: 'ex_18_18b',
    front: 'What is the difference in map scale use between high-level and low-level navigation?',
    back: 'At altitude you tend to work on the 1:500,000 ICAO chart. At low level, the 1:250,000 topographic chart gives more ground detail and is preferred. Features are smaller in scale on the map but pass faster below you.',
  },
  {
    id: 'ex_18_18b_fc_4',
    exercise_id: 'ex_18_18b',
    front: 'What does the instructor want to see during low-level navigation?',
    back: 'Positive track following (not wandering), feature identification 1–2 miles ahead (not behind), prompt action when uncertain, and maintained lookout for traffic and obstacles.',
  },
  {
    id: 'ex_18_18b_fc_5',
    exercise_id: 'ex_18_18b',
    front: 'If you become unsure of your position at low level, what is the first action?',
    back: 'Climb — to improve visibility, extend radio range, and give yourself more time. Do not continue low when uncertain of position. Identify a large distinctive feature from height, then re-orientate.',
  },

  // -------------------------------------------------------------------------
  // Exercise 18C — Radio Navigation
  // -------------------------------------------------------------------------
  {
    id: 'ex_18_18c_fc_0',
    exercise_id: 'ex_18_18c',
    front: 'What does VOR stand for and what does it provide?',
    back: 'VHF Omnidirectional Range. Provides a magnetic bearing TO or FROM the ground station. Used to track a specific radial or to take a position fix when crossing two VOR radials.',
  },
  {
    id: 'ex_18_18c_fc_1',
    exercise_id: 'ex_18_18c',
    front: 'What is the CDI and how do you interpret a full-scale deflection?',
    back: 'Course Deviation Indicator — the needle on the VOR/HSI that shows your displacement from the selected radial. On a standard VOR, full-scale deflection = 10 degrees off the selected radial (approximately).',
  },
  {
    id: 'ex_18_18c_fc_2',
    exercise_id: 'ex_18_18c',
    front: 'What does the TO/FROM flag on the VOR indicator tell you?',
    back: 'TO: the selected radial will take you toward the station. FROM: you are on the selected radial heading away from the station. If the flag reads FROM and you are flying TO the station, you are tracking the reciprocal and the CDI sense is reversed.',
  },
  {
    id: 'ex_18_18c_fc_3',
    exercise_id: 'ex_18_18c',
    front: 'What is the NDB/ADF and how do you use it for tracking?',
    back: 'Non-Directional Beacon / Automatic Direction Finder. The ADF needle points toward the station. To track inbound, turn until the needle points to the 0 position (top of the indicator). Apply drift correction as needed.',
  },
  {
    id: 'ex_18_18c_fc_4',
    exercise_id: 'ex_18_18c',
    front: 'What is a VOR radial?',
    back: 'A specific magnetic bearing FROM the VOR station. The 090 radial is the bearing of 090 degrees FROM the station. An aircraft on the 090 radial is due east of the station.',
  },
  {
    id: 'ex_18_18c_fc_5',
    exercise_id: 'ex_18_18c',
    front: 'What does the instructor want to see during radio navigation?',
    back: 'Correct identification of the beacon (Morse ID), sensible OBS selection, logical interception of the track, maintaining heading to stay on radial with drift correction applied, and regular cross-checks against visual position.',
  },

  // -------------------------------------------------------------------------
  // Exercise 19 — Night Flying (if applicable)
  // -------------------------------------------------------------------------
  {
    id: 'ex_19_fc_0',
    exercise_id: 'ex_19',
    front: 'What additional lighting equipment must be confirmed serviceable before a night flight?',
    back: 'Navigation lights (red left, green right, white tail), landing light, instrument lighting, and a serviceable torch in the cockpit as a backup. The aircraft must display nav lights from sunset to sunrise.',
  },
  {
    id: 'ex_19_fc_1',
    exercise_id: 'ex_19',
    front: 'How does the horizon reference change at night?',
    back: 'On a dark night or over unlit terrain there may be no visible horizon. Transition to partial panel instrument flying — attitude indicator and altimeter become primary references for pitch control.',
  },
  {
    id: 'ex_19_fc_2',
    exercise_id: 'ex_19',
    front: 'What is the dark adaptation period for human night vision and what spoils it?',
    back: 'Full dark adaptation takes approximately 30 minutes. Even a brief exposure to bright white light (cabin lights, phone screen) destroys dark adaptation. Use red cockpit lighting to preserve it.',
  },
  {
    id: 'ex_19_fc_3',
    exercise_id: 'ex_19',
    front: 'What is the threshold lighting colour sequence on an ICAO runway?',
    back: 'Runway edge lights: white (blue for taxiway). Threshold: green from the approach side, red from the runway looking out (the last portion is red to warn of short runway). TDZ lights if present: white.',
  },
  {
    id: 'ex_19_fc_4',
    exercise_id: 'ex_19',
    front: 'What does the instructor want to see on your first night circuit?',
    back: 'Accurate instrument cross-check, stable approach using runway lighting as glidepath reference, correct radio calls, and a positive go-around decision if the sight picture is not as expected.',
  },
  {
    id: 'ex_19_fc_5',
    exercise_id: 'ex_19',
    front: 'What are the main spatial disorientation risks at night?',
    back: 'Leans (misread of bank due to gradual roll), graveyard spiral, and false horizon (lights on hills mistaken for the horizon). If confused, trust the instruments — your senses will lie at night.',
  },
];

// ---------------------------------------------------------------------------
// Filter by exercise if flag provided
// ---------------------------------------------------------------------------

const data = exerciseFilter
  ? flashcards.filter(fc => fc.exercise_id.startsWith(exerciseFilter))
  : flashcards;

if (data.length === 0) {
  console.error(`No flashcards found for exercise filter: ${exerciseFilter}`);
  process.exit(1);
}

console.log(`${DRY_RUN ? '[DRY RUN] ' : ''}Preparing to write ${data.length} flashcard(s)...`);

// ---------------------------------------------------------------------------
// Dry-run: print and exit
// ---------------------------------------------------------------------------

if (DRY_RUN) {
  for (const fc of data) {
    console.log(`\n--- ${fc.id} [${fc.exercise_id}] ---`);
    console.log(`  FRONT: ${fc.front}`);
    console.log(`  BACK:  ${fc.back}`);
  }
  console.log(`\n[DRY RUN] ${data.length} flashcard(s) would be written. No Firestore writes performed.`);
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Batch write to Firestore
// ---------------------------------------------------------------------------

async function seed() {
  let written = 0;

  // Chunk into batches of BATCH_SIZE (Firestore max is 500 ops per batch)
  for (let i = 0; i < data.length; i += BATCH_SIZE) {
    const chunk = data.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const fc of chunk) {
      const ref = db.collection(COLLECTION).doc(fc.id);
      batch.set(ref, {
        id: fc.id,
        exercise_id: fc.exercise_id,
        front: fc.front,
        back: fc.back,
      });
    }

    await batch.commit();
    written += chunk.length;
    console.log(`  Written ${written} / ${data.length} flashcard(s)...`);
  }

  console.log(`\nDone. ${written} flashcard(s) written to Firestore collection '${COLLECTION}'.`);
  process.exit(0);
}

seed().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
