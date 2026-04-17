// Flashcard content for UK PPL(A) exercises — 5–8 cards per exercise/sub-exercise
// covering key concepts from the CAA CAP 1298 syllabus.
import 'package:flight_path/shared/models/flashcard.dart';

export 'package:flight_path/shared/models/flashcard.dart' show Flashcard;

/// All flashcards grouped by composite exercise ID.
final Map<String, List<Flashcard>> flashcardsByExercise = {
  // ── Exercise 1: Familiarisation with the Aeroplane ──────────────────────
  'ex_01': [
    Flashcard(
      front: 'What are the three axes of an aeroplane?',
      back:
          'Longitudinal (roll), lateral (pitch), and normal/vertical (yaw). Each passes through the centre of gravity.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'What are the four forces acting on an aeroplane in flight?',
      back:
          'Lift, weight (gravity), thrust, and drag. In straight and level unaccelerated flight, lift equals weight and thrust equals drag.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'What is the purpose of the pre-flight walk-around?',
      back:
          'To check the aircraft for damage, security of panels, correct fluid levels, tyre condition, control surface freedom, and removal of tie-downs and covers.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'What does ATIS stand for and what information does it provide?',
      back:
          'Automatic Terminal Information Service. It provides current weather, runway in use, QNH, QFE, and any NOTAMs for the aerodrome.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'Where is the centre of gravity (CG) typically located on a training aircraft?',
      back:
          'Forward of the centre of pressure, within the CG envelope specified in the aircraft POH. Incorrect CG position affects stability and control.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'What is the difference between indicated airspeed (IAS) and true airspeed (TAS)?',
      back:
          'IAS is the speed shown on the ASI, uncorrected for air density. TAS is IAS corrected for altitude and temperature — TAS increases with altitude for the same IAS.',
      exerciseId: 'ex_01',
    ),

    Flashcard(
      front: 'What does SOAP stand for (aircraft documents)?',
      back: 'Service sheets, Operating limitations, Aircraft log, Permits/C of A. All must be current and on board before flight.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'PA-28-161 Warrior II — key speeds: VNE, VNO, VA, VFE',
      back: 'VNE 160 KIAS (red line), VNO 129 KIAS (top of green arc), VA 113 KIAS (manoeuvring speed), VFE 111 KIAS (max flap extended). Never exceed VNE under any circumstances.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'PA-28-161 Warrior II — key climb/stall speeds',
      back: 'VY 79 KIAS (best rate of climb), VX 73 KIAS (best angle of climb), VS1 57 KIAS (stall clean), VS0 49 KIAS (stall full flap), best glide 65 KIAS.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'What do the ASI colour arcs mean?',
      back: 'White arc = flap operating range (VSO to VFE). Green arc = normal operating range (VS1 to VNO). Yellow arc = caution/structural cruise (VNO to VNE). Red radial = VNE.',
      exerciseId: 'ex_01',
    ),
    Flashcard(
      front: 'PA-28-161 engine and fuel selector',
      back: 'Lycoming O-320-D3G, 160hp. Fuel selector: LEFT / RIGHT / OFF — no BOTH position. Always confirm which tank is selected before flight and switch per school SOP.',
      exerciseId: 'ex_01',
    ),
  ],

  // ── Exercise 2: Preparation for and Action after Flight ─────────────────
  'ex_02': [
    Flashcard(
      front: 'What documents must be carried on board a UK-registered aircraft?',
      back:
          'Certificate of Registration, Certificate of Airworthiness, Insurance certificate, Aircraft Radio Licence, and the Technical Log or equivalent.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'What does the mnemonic IMSAFE stand for?',
      back:
          'Illness, Medication, Stress, Alcohol, Fatigue, Eating/Emotion. It is a personal fitness-to-fly checklist.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'What is the minimum fuel reserve for a VFR flight in the UK?',
      back:
          'The CAA regulatory minimum final reserve for VFR day flight is 30 minutes. Most operators and instructors plan for 45 minutes as a conservative margin — know the difference.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'What checks should be performed after engine start?',
      back:
          'Oil pressure rising, engine instruments in the green, suction/voltage normal, radios set, altimeter set to QFE or QNH, DI aligned with compass.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'What is the purpose of the after-landing checklist?',
      back:
          'To reconfigure the aircraft after landing: raise flaps, set carb heat cold, set transponder to standby, and contact ground frequency if required.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'What personal documents must a pilot carry?',
      back:
          'A valid pilot licence with a current medical certificate, a valid photo ID, and a personal flying logbook (not legally required to carry but recommended).',
      exerciseId: 'ex_02',
    ),

    Flashcard(
      front: 'What is the legal minimum VFR visibility below FL100 in Class G airspace?',
      back: '5 km flight visibility, 1,500 m horizontal from cloud, 1,000 ft vertical from cloud. Below 3,000 ft AMSL/1,000 ft AGL at ≤140 kt: 1,500 m visibility, clear of cloud, in sight of surface.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'What is the minimum fuel reserve for UK day VFR flight (legal minimum)?',
      back: '30 minutes at normal cruise consumption after landing at destination (Part-NCO.OP.125). Night VFR is 45 min. Most instructors plan to 45 min as a training standard.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'PA-28-161 cruise performance at 75% power',
      back: 'Approximately 108 kt TAS, fuel burn ~8.0 USG/hr. Total fuel 48 USG (all usable). Maximum endurance approximately 6 hr tanks-full — plan to around 5.5 hr with reserve.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'What does the IMSAFE checklist cover?',
      back: 'Illness, Medication, Stress, Alcohol (8-hour rule minimum), Fatigue, Eating/Emotion. Personal fitness-to-fly check completed before every flight.',
      exerciseId: 'ex_02',
    ),
    Flashcard(
      front: 'Colour of AVGAS 100LL and why does it matter?',
      back: 'Blue. Prevents misfuelling with Jet A-1 (clear/straw), MOGAS (clear), or incorrect grade. Always drain a fuel sample and confirm blue colour with no water before flight.',
      exerciseId: 'ex_02',
    ),
  ],

  // ── Exercise 3: Air Experience ──────────────────────────────────────────
  'ex_03': [
    Flashcard(
      front: 'What is the primary purpose of the air experience flight?',
      back:
          'To introduce the student to the general handling of the aircraft in flight, the local area, and the sensations of flying. It builds confidence and interest.',
      exerciseId: 'ex_03',
    ),
    Flashcard(
      front: 'What is the correct lookout technique?',
      back:
          'Systematic scanning: divide the sky into sectors, pause briefly in each sector to allow the eyes to focus, and check above and below the horizon. Spend 80% of time looking outside.',
      exerciseId: 'ex_03',
    ),
    Flashcard(
      front: 'What does QNH mean and what does it give you?',
      back:
          'QNH is the pressure setting that gives altitude above mean sea level (AMSL) when set on the altimeter subscale.',
      exerciseId: 'ex_03',
    ),
    Flashcard(
      front: 'What does QFE mean and what does it give you?',
      back:
          'QFE is the pressure setting that gives height above the aerodrome reference point. The altimeter reads zero on the ground at that airfield.',
      exerciseId: 'ex_03',
    ),
    Flashcard(
      front: 'What is the standard circuit height at most UK aerodromes?',
      back:
          '1,000 feet above aerodrome level (AAL), unless otherwise published in the aerodrome information.',
      exerciseId: 'ex_03',
    ),

    Flashcard(
      front: 'What is the "leans" illusion?',
      back: 'After a prolonged bank, the vestibular system adapts. When wings are levelled the pilot feels banked the other way and leans their body to feel "upright". Trust the instruments — not sensations.',
      exerciseId: 'ex_03',
    ),
    Flashcard(
      front: 'What is the somatogravic illusion?',
      back: 'Forward acceleration is perceived as a nose-high pitch attitude. The pilot pushes the nose down to correct a false climb. Most dangerous during take-off in IMC or at night. Trust the AI.',
      exerciseId: 'ex_03',
    ),
    Flashcard(
      front: 'Carbon monoxide in aircraft — symptoms and action',
      back: 'CO is colourless, odourless, tasteless. Symptoms: headache, drowsiness, confusion. Action: close the heater, open fresh air vents, land as soon as practicable. Fit a CO detector.',
      exerciseId: 'ex_03',
    ),
    Flashcard(
      front: 'Correct lookout scanning technique',
      back: 'Divide sky into 10-15 degree sectors. Pause 1-2 seconds in each (eyes must be stationary to focus). Cover above and below horizon. 80% of time should be outside the aircraft.',
      exerciseId: 'ex_03',
    ),
    Flashcard(
      front: 'Standard training area altitude in the UK',
      back: 'Typically 1,500 to 4,000 ft AMSL, above circuit height, below any local airspace restrictions. Exact limits depend on local airspace and cloud base.',
      exerciseId: 'ex_03',
    ),
  ],

  // ── Exercise 4: Effects of Controls ─────────────────────────────────────
  'ex_04': [
    Flashcard(
      front: 'What is the purpose of ailerons?',
      back:
          'Ailerons control roll (bank) around the longitudinal axis. They work differentially — one goes up while the other goes down.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'What is the purpose of the elevator?',
      back:
          'The elevator controls pitch around the lateral axis, changing the nose attitude and therefore the angle of attack.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'What is the purpose of the rudder?',
      back:
          'The rudder controls yaw around the normal (vertical) axis. It is used to maintain balanced flight, coordinate turns, and counteract adverse yaw.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'What is adverse yaw?',
      back:
          'When ailerons are applied, the descending aileron creates more drag than the rising one, causing the nose to yaw opposite to the direction of turn. Rudder is used to counteract it.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'What is the effect of applying power (throttle)?',
      back:
          'Increasing power causes the nose to pitch up and yaw left (in most single-engine aircraft) due to torque, slipstream, and gyroscopic effects. Opposite occurs when reducing power.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'What is the purpose of trim?',
      back:
          'Trim relieves the pilot of sustained control pressure. The trim tab moves opposite to the desired elevator direction, holding the elevator in the trimmed position.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'What is the effect of flaps on pitch?',
      back:
          'Lowering flaps generally causes a pitch change (nose up then nose down in most types) and increases both lift and drag. The aircraft must be re-trimmed after flap changes.',
      exerciseId: 'ex_04',
    ),

    Flashcard(
      front: 'Four propeller effects causing left-yaw tendency at high power',
      back: '1. Slipstream (corkscrew hitting left side of fin). 2. Torque (reaction to clockwise prop rotation rolls aircraft left). 3. P-factor (descending blade produces more thrust). 4. Gyroscopic precession (tail raise yaws nose left). All corrected with right rudder.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'Primary and secondary effects of rudder',
      back: 'Primary: yaw (right rudder = yaw right). Secondary: roll in the same direction as the yaw (yaw right → roll right). The secondary effect is due to differential lift between the inner and outer wings.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'What is gyroscopic precession in aircraft terms?',
      back: 'A force applied to a spinning gyroscope (propeller) acts 90 degrees ahead in the direction of rotation. When the tail is raised on take-off, the prop reacts by yawing the nose left.',
      exerciseId: 'ex_04',
    ),
    Flashcard(
      front: 'Effect of first stage of flap (0-10 degrees) vs full flap',
      back: 'First stage: large lift increase, small drag increase. Full flap: large drag increase, moderate lift increase. First stage useful for short-field take-off. Full flap for steep landing approach.',
      exerciseId: 'ex_04',
    ),
  ],

  // ── Exercise 5: Taxiing ─────────────────────────────────────────────────
  'ex_05': [
    Flashcard(
      front: 'What is the maximum recommended taxi speed?',
      back:
          'A fast walking pace — typically no more than 15–20 knots in the open and much slower in confined areas. You should be able to stop promptly at any time.',
      exerciseId: 'ex_05',
    ),
    Flashcard(
      front: 'How do you steer on the ground in a nosewheel aircraft?',
      back:
          'Primarily with rudder pedals (connected to the nosewheel) and differential braking. At low speed, nosewheel steering is more effective; at higher speed, rudder aerodynamic effect increases.',
      exerciseId: 'ex_05',
    ),
    Flashcard(
      front: 'What control positions should you use when taxiing in a headwind?',
      back:
          'Stick/yoke neutral or slightly back to prevent the wind lifting the tail. Keep ailerons neutral in a direct headwind.',
      exerciseId: 'ex_05',
    ),
    Flashcard(
      front: 'What control positions when taxiing with a tailwind?',
      back:
          'Stick/yoke forward to prevent the tail being lifted. This is the opposite of headwind positioning.',
      exerciseId: 'ex_05',
    ),
    Flashcard(
      front: 'What are the standard light signals from ATC to aircraft on the ground?',
      back:
          'Steady green = cleared to take off. Steady red = stop. Flashing green = cleared to taxi. Flashing red = taxi clear of runway. Flashing white = return to starting point.',
      exerciseId: 'ex_05',
    ),
    Flashcard(
      front: 'What checks should be performed at the holding point before takeoff?',
      back:
          'Power checks (magnetos, carb heat), engine temperatures and pressures in the green, flight instruments set, controls full and free, hatches and harnesses secure, brakes checked.',
      exerciseId: 'ex_05',
    ),

    Flashcard(
      front: 'ATC light signals to airborne aircraft',
      back: 'Steady green: cleared to land. Flashing green: return to land. Steady red: give way, continue circling. Flashing red: aerodrome unsafe, do not land. Alternating R/G: exercise extreme caution.',
      exerciseId: 'ex_05',
    ),
    Flashcard(
      front: 'CAT I holding point markings',
      back: 'Two solid yellow lines + two dashed yellow lines across taxiway. Hold on the SOLID side (facing runway). You may cross from the dashed side without ATC clearance.',
      exerciseId: 'ex_05',
    ),
    Flashcard(
      front: 'Carb heat during run-up — what does RPM drop then recovery mean?',
      back: 'Normal RPM drop = hot air is less dense. If RPM subsequently rises above the initial hot-air RPM: ice was present and has melted. Carb heat is working correctly.',
      exerciseId: 'ex_05',
    ),
    Flashcard(
      front: 'Crosswind aileron position while taxiing',
      back: 'INTO wind: apply aileron into wind to keep upwind wing down. With tailwind component: forward stick. With headwind component: back stick. Memory aid: "turn into the wind" for aileron.',
      exerciseId: 'ex_05',
    ),
  ],

  // ── Exercise 6: Straight and Level Flight ───────────────────────────────
  'ex_06': [
    Flashcard(
      front: 'What is the primary reference for maintaining straight and level flight?',
      back:
          'The natural horizon — the position of the nose (or cowling reference point) relative to the horizon determines pitch attitude.',
      exerciseId: 'ex_06',
    ),
    Flashcard(
      front: 'How do you maintain altitude in straight and level flight?',
      back:
          'Set the correct power and attitude. Use the attitude indicator and external horizon as primary reference, cross-check with the altimeter. Trim to remove control pressure.',
      exerciseId: 'ex_06',
    ),
    Flashcard(
      front: 'What is the relationship between power and airspeed in level flight?',
      back:
          'More power = higher airspeed (at constant altitude). Power controls airspeed in level flight. Attitude controls altitude.',
      exerciseId: 'ex_06',
    ),
    Flashcard(
      front: 'What is the PAT sequence?',
      back:
          'Power, Attitude, Trim. When changing speed in level flight: set the new power, adjust attitude to maintain altitude, then trim off the control pressure.',
      exerciseId: 'ex_06',
    ),
    Flashcard(
      front: 'How can you tell if the aircraft is in balanced flight?',
      back:
          'The balance ball (slip indicator) is centred. If the ball is displaced, apply rudder pressure towards the ball to coordinate — "step on the ball".',
      exerciseId: 'ex_06',
    ),
    Flashcard(
      front: 'What is the cruise checklist mnemonic FREDA?',
      back:
          'Fuel (contents, selection, pressure), Radio (correct frequency, next report), Engine (temperatures, pressures, mixture), Direction indicator (aligned with compass), Altitude (correct QNH/QFE).',
      exerciseId: 'ex_06',
    ),

    Flashcard(
      front: 'PA-28-161 cruise figures at 75% power',
      back: '108 kt TAS, ~8.0 USG/hr fuel burn. VNO 129 KIAS (top of green arc). VA 113 KIAS (manoeuvring speed — reduce to this in turbulence).',
      exerciseId: 'ex_06',
    ),
    Flashcard(
      front: 'Why must the DI be aligned with the compass in straight and level flight?',
      back: 'The magnetic compass is most accurate in straight, level, unaccelerated flight. During turns it has northerly turning error; during acceleration it has acceleration error. Only align in straight/level flight.',
      exerciseId: 'ex_06',
    ),
    Flashcard(
      front: 'PAT sequence for changing cruise speed',
      back: 'Power (set new power), Attitude (adjust to maintain altitude at new speed), Trim (remove control pressure). Used for all speed changes in level flight.',
      exerciseId: 'ex_06',
    ),
    Flashcard(
      front: 'FREDA — frequency and what each letter covers',
      back: 'Every 10-15 minutes. Fuel (correct tank, sufficient, pump), Radio (correct frequency, squawk), Engine (temps/pressures in green), DI (aligned with compass), Altitude (correct QNH/QFE set).',
      exerciseId: 'ex_06',
    ),
  ],

  // ── Exercise 7: Climbing ────────────────────────────────────────────────
  'ex_07': [
    Flashcard(
      front: 'What is the difference between Vy and Vx?',
      back:
          'Vy is best rate of climb speed (most altitude gained per unit time). Vx is best angle of climb speed (most altitude gained per unit distance). Vx is always lower than Vy.',
      exerciseId: 'ex_07',
    ),
    Flashcard(
      front: 'What happens to the climb rate as altitude increases?',
      back:
          'Climb rate decreases because the engine produces less power in thinner air. At the absolute ceiling, climb rate is zero.',
      exerciseId: 'ex_07',
    ),
    Flashcard(
      front: 'What is the correct procedure to enter a climb?',
      back:
          'Apply full power, simultaneously raise the nose to the climb attitude, maintain balance with rudder (counter yaw from increased power), allow speed to settle, then trim.',
      exerciseId: 'ex_07',
    ),
    Flashcard(
      front: 'What is the correct procedure to level off from a climb?',
      back:
          'Lower the nose to the cruise attitude, allow the speed to build to cruise speed, then reduce power to cruise setting. Trim. Remember: Attitude, Airspeed, Power, Trim.',
      exerciseId: 'ex_07',
    ),
    Flashcard(
      front: 'Why is a climbing turn at a lower angle of bank than a level turn?',
      back:
          'In a climb, the aircraft is already at a high angle of attack with limited excess power. Steep bank would increase stall speed, reduce climb rate, and risk a stall.',
      exerciseId: 'ex_07',
    ),
    Flashcard(
      front: 'What is the typical maximum bank angle for a climbing turn?',
      back:
          'Normally limited to 15-20 degrees of bank to maintain a safe margin above stall speed and an acceptable rate of climb.',
      exerciseId: 'ex_07',
    ),

    Flashcard(
      front: 'PA-28-161 VY and VX',
      back: 'VY = 79 KIAS (best rate of climb — most altitude per minute). VX = 73 KIAS (best angle of climb — most altitude per unit of distance). Use VX for obstacle clearance, then transition to VY.',
      exerciseId: 'ex_07',
    ),
    Flashcard(
      front: 'Levelling off from a climb — technique and lead',
      back: 'Lead the level-off by 10% of ROC (e.g., 500 fpm → lead by 50 ft). Lower nose to cruise attitude, allow speed to accelerate to cruise, then reduce power, then trim.',
      exerciseId: 'ex_07',
    ),
    Flashcard(
      front: 'Why is engine cooling a concern during a prolonged climb?',
      back: 'Engine at full power (high heat) + reduced airspeed (reduced cooling airflow) = elevated CHT. Monitor CHT. Ensure climbing at VY not slower to maximise cooling airflow.',
      exerciseId: 'ex_07',
    ),
    Flashcard(
      front: 'Maximum bank angle in a climbing turn',
      back: '15-20 degrees maximum. Steep bank in a climb: increases load factor, raises stall speed, reduces the already-limited excess power available for the climb.',
      exerciseId: 'ex_07',
    ),
  ],

  // ── Exercise 8: Descending ──────────────────────────────────────────────
  'ex_08': [
    Flashcard(
      front: 'What is a glide descent?',
      back:
          'A descent at idle power at the best glide speed. This gives the maximum range (distance) for height lost. Used in engine failure scenarios.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'What is a powered descent?',
      back:
          'A descent with some power set, allowing a controlled rate of descent and a specific airspeed to be maintained. Used for normal circuit approaches.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'Why must carburettor heat be applied before reducing power for a descent?',
      back:
          'Reducing power reduces manifold pressure and temperature, making carburettor icing more likely. Applying carb heat before or during power reduction prevents ice formation in the carburettor.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'What is the correct procedure to level off from a descent?',
      back:
          'Increase power to cruise setting, raise the nose to the cruise attitude, allow speed to settle, then trim. Start levelling off about 10% of the rate of descent before reaching the target altitude.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'What are the effects of wind on a glide?',
      back:
          'A headwind reduces ground distance covered in the glide but does not change the rate of descent or the time airborne. A tailwind increases ground distance covered.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'What is a side-slip used for?',
      back:
          'Correcting drift in a crosswind landing. Apply bank into wind to remove drift, use into-wind rudder to keep the aircraft aligned with the runway centreline. Into-wind aileron + into-wind rudder = side-slip.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'What is a forward slip used for?',
      back:
          'Increasing the rate of descent without increasing airspeed, typically on final approach. Apply bank one way, opposite rudder to prevent turn (crossed controls). Creates maximum drag.',
      exerciseId: 'ex_08',
    ),

    Flashcard(
      front: 'PA-28-161 best glide speed and glide ratio',
      back: 'Best glide: 73 KIAS. Glide ratio approximately 9:1. From 3,000 ft: 9 × 3,000 = 27,000 ft ≈ 4.5 nm range. From 3,500 ft: approx 5.3 nm.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'PA-28-161 normal approach speed with full flap',
      back: '75-80 KIAS with full flap. Vso = 49 KIAS. 1.3 × Vso = 64 KIAS minimum, but 75-80 kt allows gust margin. Always check school SOP.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'Why clear the engine during a prolonged descent?',
      back: 'Extended idle causes spark plug fouling from carbon deposits and uneven engine cooling. Apply a few seconds of power every few minutes to keep the engine warm and plugs clean.',
      exerciseId: 'ex_08',
    ),
    Flashcard(
      front: 'Levelling off from a descent — correct sequence',
      back: 'Power first (anticipate drag from nose-up attitude), then raise nose to level attitude, allow speed to stabilise, then trim. Opposite of levelling from a climb (where nose comes down first).',
      exerciseId: 'ex_08',
    ),
  ],

  // ── Exercise 9: Turning ─────────────────────────────────────────────────
  'ex_09': [
    Flashcard(
      front: 'What causes an aircraft to turn?',
      back:
          'The horizontal component of lift. When the aircraft is banked, lift is tilted, creating a horizontal force that pulls the aircraft into the turn.',
      exerciseId: 'ex_09',
    ),
    Flashcard(
      front: 'What is the load factor in a 60-degree banked turn?',
      back:
          '2g. Load factor = 1 / cos(bank angle). At 60 degrees the aircraft and occupants experience twice the force of gravity.',
      exerciseId: 'ex_09',
    ),
    Flashcard(
      front: 'Why does stall speed increase in a turn?',
      back:
          'The increased load factor means the wings must produce more lift to support the aircraft. The higher angle of attack needed to produce this lift is reached at a higher speed.',
      exerciseId: 'ex_09',
    ),
    Flashcard(
      front: 'What is the standard rate turn and how is it indicated?',
      back:
          'A rate one turn = 3 degrees per second (360 degrees in 2 minutes). It is shown by the turn coordinator or turn-and-slip indicator needle aligned with the reference mark.',
      exerciseId: 'ex_09',
    ),
    Flashcard(
      front: 'What back pressure is needed on the control column in a turn?',
      back:
          'Increasing back pressure is needed to maintain altitude because some of the total lift is acting horizontally. The steeper the bank, the more back pressure is required.',
      exerciseId: 'ex_09',
    ),
    Flashcard(
      front: 'How do you roll out of a turn onto a specific heading?',
      back:
          'Begin the roll-out approximately half the bank angle before the desired heading (e.g., in a 30-degree bank turn, start rolling out 15 degrees before). Reduce back pressure as wings level.',
      exerciseId: 'ex_09',
    ),

    Flashcard(
      front: 'Load factors at key bank angles',
      back: '0°: 1.0G. 30°: 1.15G. 45°: 1.41G. 60°: 2.0G. Formula: LF = 1/cos(bank angle). Stall speed increases by √LF at each bank angle.',
      exerciseId: 'ex_09',
    ),
    Flashcard(
      front: 'Rate 1 turn — definition and bank angle formula',
      back: 'Rate 1 = 3°/second, 360° in 2 minutes. Bank angle ≈ airspeed ÷ 10 + 7. At 90 kt: 90÷10+7 = 16°. At 108 kt: 108÷10+7 ≈ 18°.',
      exerciseId: 'ex_09',
    ),
    Flashcard(
      front: 'Roll-out lead for turns',
      back: 'Begin roll-out approximately half the bank angle before the desired heading. At 30° bank: start rolling out 15° before target heading. At 45°: start 22-23° before.',
      exerciseId: 'ex_09',
    ),
    Flashcard(
      front: '"Step on the ball" — what does it mean?',
      back: 'If the slip/skid ball is displaced, apply rudder on the side the ball has moved to. Ball left = apply left rudder. Ball right = apply right rudder. Centres the ball and coordinates flight.',
      exerciseId: 'ex_09',
    ),
  ],

  // ── Exercise 10A: Slow Flight ───────────────────────────────────────────
  'ex_10_10a': [
    Flashcard(
      front: 'What is the purpose of practising slow flight?',
      back:
          'To develop the ability to recognise and control the aircraft at speeds near the stall, improving awareness of handling characteristics in the approach and landing phase.',
      exerciseId: 'ex_10_10a',
    ),
    Flashcard(
      front: 'How does the aircraft handle differently at slow speed?',
      back:
          'Controls feel mushy/less effective due to reduced airflow. Higher angle of attack is needed. More rudder is required to maintain coordination. Stall buffet may be present.',
      exerciseId: 'ex_10_10a',
    ),
    Flashcard(
      front: 'What happens to drag at slow flight speeds?',
      back:
          'Induced drag increases significantly at slow speeds (it varies inversely with speed squared). The aircraft is operating on the "back side of the drag curve" where slowing down requires more power.',
      exerciseId: 'ex_10_10a',
    ),
    Flashcard(
      front: 'What is the minimum speed for slow flight practice?',
      back:
          'Typically 1.1 to 1.2 times the stall speed (Vs). This provides a small safety margin above the stall while demonstrating slow flight characteristics.',
      exerciseId: 'ex_10_10a',
    ),
    Flashcard(
      front: 'What is the "region of reversed command"?',
      back:
          'At speeds below the minimum drag speed, reducing speed actually requires more power (due to rising induced drag). Also called the "back side of the power curve".',
      exerciseId: 'ex_10_10a',
    ),

    Flashcard(
      front: 'PA-28-161 slow flight speeds — VS0 and VS1',
      back: 'VS0 (stall, full flap) = 49 KIAS. VS1 (stall, clean) = 57 KIAS. Slow flight typically practised at 1.1-1.2 × VS: landing config ~54-59 kt; clean ~63-68 kt.',
      exerciseId: 'ex_10_10a',
    ),
    Flashcard(
      front: 'HASELL check — full expansion',
      back: 'Height (sufficient: min 3,000 ft stalls / 5,000 ft spins), Airframe (correct config), Security (harnesses, hatches, loose items secured), Engine (mixture rich, carb heat, fuel on), Location (not over towns, near a field), Lookout (360° clearing turns).',
      exerciseId: 'ex_10_10a',
    ),
    Flashcard(
      front: '"Back side of the power curve" — what does it mean?',
      back: 'Below minimum drag speed: reducing speed requires MORE power to maintain altitude (induced drag dominates). In this regime: power controls speed, attitude controls altitude — opposite of normal cruise.',
      exerciseId: 'ex_10_10a',
    ),
    Flashcard(
      front: 'Why is slow flight directly relevant to circuit flying?',
      back: 'Circuit approach speeds (75-80 kt) are close to VS0 (49 kt). The skills of managing power, attitude, flap, and trim near the stall are directly applied on every approach and landing.',
      exerciseId: 'ex_10_10a',
    ),
    Flashcard(
      front: 'What happens to control effectiveness at slow airspeeds?',
      back: 'Aerodynamic force ∝ V². Halving airspeed quarters the control surface effectiveness. Controls feel mushy, sluggish. Larger inputs needed but margins to full deflection are reduced.',
      exerciseId: 'ex_10_10a',
    ),
  ],

  // ── Exercise 10B: Stalling ──────────────────────────────────────────────
  'ex_10_10b': [
    Flashcard(
      front: 'At what angle of attack does a wing stall?',
      back:
          'The critical angle of attack, typically 15-18 degrees for most training aircraft. A stall occurs at this angle regardless of airspeed, attitude, or weight.',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'What are the symptoms of an approaching stall?',
      back:
          'Decreasing airspeed, less effective controls, possible buffet, stall warning horn/light, high nose attitude, high power required to maintain altitude.',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'What is the standard stall recovery technique?',
      back:
          'Simultaneously: lower the nose (reduce angle of attack), apply full power, level the wings with coordinated rudder and aileron, and recover to normal flight. Minimise height loss.',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'What is the effect of flaps on stall speed?',
      back:
          'Flaps reduce the stall speed by increasing the coefficient of lift, allowing the wing to produce more lift at a lower speed. However, they also increase drag.',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'What factors increase the stall speed?',
      back:
          'Higher weight, higher load factor (steeper bank), forward CG position, ice or contamination on the wings, higher altitude (same IAS stall speed but higher TAS).',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'Can an aircraft stall in any attitude and at any airspeed?',
      back:
          'Yes. A stall occurs whenever the critical angle of attack is exceeded, regardless of the aircraft attitude, airspeed, or flight condition.',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'What is a secondary stall?',
      back:
          'A stall that occurs during the recovery from an initial stall, usually caused by pulling back too aggressively on the control column before sufficient speed has been regained.',
      exerciseId: 'ex_10_10b',
    ),

    Flashcard(
      front: 'PARE for stall recovery',
      back: 'Power (full), Attitude (nose down — reduce AoA below critical angle), Roll wings level (coordinated aileron/rudder), Engine (carb heat off for max power). Minimise altitude loss.',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'PA-28-161 stall speed in a 60° banked turn',
      back: 'VS1 = 57 KIAS. At 60° bank: LF = 2G. Stall speed = √2 × 57 = 1.41 × 57 ≈ 80 KIAS. A massive increase from the straight-and-level stall speed.',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'Why use rudder (not aileron) to raise a dropped wing at the stall?',
      back: 'Applying down aileron on the low wing increases its AoA further, deepening the stall on that wing and risking spin entry. Rudder opposite to the drop yaws the aircraft to raise the wing without increasing AoA.',
      exerciseId: 'ex_10_10b',
    ),
    Flashcard(
      front: 'Pre-stall symptoms',
      back: '1. Stall warning horn/light (5-10 kt before stall). 2. Airframe buffet (turbulent wing airflow touching the tail). 3. Mushy/ineffective controls. 4. High pitch attitude. Recovery at this stage prevents full stall.',
      exerciseId: 'ex_10_10b',
    ),
  ],

  // ── Exercise 11: Spin Awareness and Recovery ────────────────────────────
  'ex_11': [
    Flashcard(
      front: 'What conditions are required for a spin to develop?',
      back:
          'A stall (wing at or beyond critical angle of attack) combined with yaw. The yaw causes one wing to stall more deeply than the other, creating autorotation.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'What is the standard spin recovery technique?',
      back:
          'Full opposite rudder to the direction of spin, pause, then ease the control column forward to unstall the wings. When rotation stops, centralise the rudder, and gently recover from the dive.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'What is an incipient spin?',
      back:
          'The initial phase of a spin (first one or two turns) before a fully developed spin is established. Recovery is typically quicker during this phase.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'Why is a spin dangerous at low altitude?',
      back:
          'There may be insufficient height to complete the recovery. A spin from a base-to-final turn is a leading cause of fatal accidents because recovery height is not available.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'How does CG position affect spin recovery?',
      back:
          'A forward CG makes spin recovery easier because the nose-down moment helps unstall the wings. An aft CG makes recovery harder or even impossible — the aircraft may become unrecoverable.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'What is the difference between a spin and a spiral dive?',
      back:
          'In a spin, the aircraft is stalled and autorotating (low, relatively constant airspeed). In a spiral dive, the aircraft is NOT stalled — airspeed increases rapidly and g-forces build.',
      exerciseId: 'ex_11',
    ),

    Flashcard(
      front: 'PARE for spin recovery',
      back: 'Power OFF (power worsens spin), Ailerons NEUTRAL (aileron input complicates rotation), Rudder OPPOSITE to rotation (stops autorotation), Elevator FORWARD (unstalls the wing). Hold until rotation stops, then ease out of dive.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'Incipient vs developed spin',
      back: 'Incipient: first 1-2 turns — rotation building, easier to recover. Developed: stable repeating pattern with consistent altitude loss (300-500 ft/turn). Full PARE required. Recovery takes more altitude.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'Minimum altitudes for stall and spin exercises',
      back: 'Stall exercises: minimum 3,000 ft AGL. Intentional spin practice: minimum 5,000 ft AGL. HASELL check mandatory before both. Recovery must be complete before 3,000 ft AGL.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'Why is the base-to-final turn the most dangerous stall/spin scenario?',
      back: 'Aircraft is low (300-500 ft), slow (near approach speed), and turning. Pilot applies rudder to tighten the turn while slow → stall → spin → ground. Insufficient height for recovery. Prevention: fly a wider circuit.',
      exerciseId: 'ex_11',
    ),
    Flashcard(
      front: 'Spin entry conditions',
      back: 'Requires BOTH a stall (critical AoA exceeded) AND yaw simultaneously. Yaw causes asymmetric AoA — one wing stalls more deeply, differential lift/drag starts autorotation.',
      exerciseId: 'ex_11',
    ),
  ],

  // ── Exercise 12: Take-off and Climb to Downwind ─────────────────────────
  'ex_12': [
    Flashcard(
      front: 'What are the standard take-off speeds to know?',
      back:
          'Vr (rotate speed), V1 (decision speed — mainly multi-engine), V2 (take-off safety speed — mainly multi-engine), Vy (best rate of climb). Check your POH for your aircraft type.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'What is the crosswind technique for take-off?',
      back:
          'Apply into-wind aileron, maintain runway centreline with rudder. As speed increases, gradually reduce the aileron input. Lift off cleanly when ready and correct for drift once airborne.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'What is the effect of a short/soft field on take-off distance?',
      back:
          'A soft surface increases rolling resistance and therefore increases the take-off distance. Techniques like holding the nose up early help reduce time on the surface.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'Why do you check the engine instruments early in the take-off roll?',
      back:
          'To verify full power is being produced, engine temperatures and pressures are normal, and RPM is in the expected range. If not, abort the take-off immediately.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'What action should you take if the engine fails after take-off below about 500 ft AGL?',
      back:
          'Lower the nose immediately to maintain flying speed, land ahead (or within approximately 30 degrees of the runway heading). Do NOT attempt to turn back to the runway.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'What factors increase take-off distance?',
      back:
          'High density altitude, heavy weight, tailwind, uphill slope, soft/wet surface, high temperature, and high airfield elevation all increase take-off distance required.',
      exerciseId: 'ex_12',
    ),

    Flashcard(
      front: 'EFATO below 500 ft — immediate action',
      back: 'Lower the nose IMMEDIATELY to maintain flying speed. Land ahead or within 30° of the nose. Do NOT turn back to the runway. Squawk 7700, MAYDAY if time allows.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'PA-28-161 demonstrated max crosswind component',
      back: '17 kt demonstrated (not a structural limit — it is the maximum tested during certification). Treat as a practical training limit. Your school ops manual specifies limits for ab-initio students.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'Four propeller effects during take-off',
      back: 'Slipstream (hits left fin), Torque (rolls left), P-factor (descending blade more thrust), Gyroscopic precession (tail raising yaws nose left). All corrected with right rudder pressure.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'Normal take-off flap setting on PA-28-161',
      back: 'Flaps UP (0°) for normal take-off. 10° flap for short-field only. Full flap on a normal runway increases drag and reduces climb performance.',
      exerciseId: 'ex_12',
    ),
    Flashcard(
      front: 'After take-off checks — when and what',
      back: 'Completed at 500-700 ft AAL when established in the climb (not during critical initial climb). Items: flaps retracted (if used), carb heat COLD, mixture/RPM as required, trim for climb.',
      exerciseId: 'ex_12',
    ),
  ],

  // ── Exercise 13: Circuit, Approach and Landing ──────────────────────────
  'ex_13': [
    Flashcard(
      front: 'What is the standard circuit direction in the UK?',
      back:
          'Left-hand circuit (all turns are to the left) unless otherwise specified for the runway in use. Right-hand circuits are published where required by terrain or noise abatement.',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'What are the legs of a standard circuit?',
      back:
          'Upwind (climb out after take-off), crosswind (turn 90 degrees), downwind (parallel to runway, opposite direction), base (turn towards runway), final (aligned with runway for landing).',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'What is the aiming point and touchdown point on landing?',
      back:
          'The aiming point is where you look during the approach (typically the threshold markings or numbers). The actual touchdown point will be slightly beyond the aiming point after the flare.',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'What is the "flare" (round-out)?',
      back:
          'The transition from the approach descent to the landing attitude. The pilot gradually raises the nose to reduce the rate of descent and airspeed, touching down on the main wheels at minimum speed.',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'What is Vref and why is it important?',
      back:
          'Vref is the reference approach speed, typically 1.3 x Vso (stall speed in landing configuration). It provides a safe margin above the stall during the approach.',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'What is a go-around and when should you perform one?',
      back:
          'A go-around is an aborted landing. Apply full power, adopt climbing attitude, retract flaps in stages, and climb away. Perform one whenever the approach is unstable, too high, too fast, or unsafe.',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'What downwind checks should you complete?',
      back:
          'Brakes off, Undercarriage (fixed — check green light if applicable), Mixture rich, Fuel on and sufficient, Flaps as required, Instruments (DI/QFE), Hatches and Harnesses secure.',
      exerciseId: 'ex_13',
    ),

    Flashcard(
      front: 'PAPI colours and meaning',
      back: '4 white: too high. 3 white + 1 red: slightly high. 2 white + 2 red: on slope. 1 white + 3 red: slightly low. 4 red: too low (add power immediately). "All red you\'re dead."',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'Stabilised approach criteria by 500 ft AAL',
      back: 'Correct speed (target ±5 kt), correct configuration (flap set), on glidepath, on centreline, rate of descent stable. If any criterion not met by 500 ft — GO AROUND.',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'Downwind checks mnemonic — BUMFITCH',
      back: 'Brakes (off), Undercarriage (fixed — check green if retractable), Mixture (rich), Fuel (correct tank, pump on), Instruments (DI, QFE/QNH), Trim (approach), Carb Heat (on), Hatches/Harnesses.',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'Flapless circuit — speed and approach differences',
      back: 'Approach speed: 1.3 × VS1 = 1.3 × 57 = ~74 KIAS (vs normal 75-80 with flap). Approach angle is shallower (less drag). Longer landing roll required. Touch and goes: go around must be considered early.',
      exerciseId: 'ex_13',
    ),
    Flashcard(
      front: 'Cause and correction of ballooning on landing',
      back: 'Causes: flaring too high, excess speed, back pressure too fast. Correction: hold the attitude (do NOT push forward), allow aircraft to sink. If too high or fast — GO AROUND.',
      exerciseId: 'ex_13',
    ),
  ],

  // ── Exercise 14: First Solo ─────────────────────────────────────────────
  'ex_14': [
    Flashcard(
      front: 'What is the legal minimum experience before first solo?',
      back:
          'There is no legal minimum number of hours, but the instructor must be satisfied that the student is competent to fly solo safely. Typically 10-20 hours of dual instruction.',
      exerciseId: 'ex_14',
    ),
    Flashcard(
      front: 'What weather conditions are ideal for a first solo?',
      back:
          'Light winds (ideally down the runway), good visibility, no significant crosswind, no turbulence, and no low cloud. The instructor will choose the conditions carefully.',
      exerciseId: 'ex_14',
    ),
    Flashcard(
      front: 'What should you do if you feel uncomfortable or unsure during solo?',
      back:
          'Go around and try again, or land and discuss with your instructor. There is never any pressure to continue if you feel unsafe. Safety always comes first.',
      exerciseId: 'ex_14',
    ),
    Flashcard(
      front: 'How will the aircraft perform differently when flying solo?',
      back:
          'The aircraft will be lighter (no instructor), so it will climb faster, need less power, and have a lower stall speed. It may feel different in the flare — be prepared for a slightly different landing feel.',
      exerciseId: 'ex_14',
    ),
    Flashcard(
      front: 'What documents must the student have for first solo?',
      back:
          'A valid student pilot licence, a current Class 2 (or LAPL) medical certificate, and the instructor must have signed the student off in their logbook/training record for solo flight.',
      exerciseId: 'ex_14',
    ),

    Flashcard(
      front: 'PPL(A) minimum hours requirements',
      back: '45 hours total: min 25 hours dual, min 10 hours supervised solo (inc. 5 hours solo cross-country). Solo cross-country must include one flight of ≥150 nm with landings at two aerodromes different from departure.',
      exerciseId: 'ex_14',
    ),
    Flashcard(
      front: 'How the aircraft performs differently on first solo',
      back: 'Without instructor (~75-90 kg lighter): shorter take-off roll, better climb rate, lower stall speed, different trim position on approach. Aircraft feels more responsive and accelerates quicker.',
      exerciseId: 'ex_14',
    ),
    Flashcard(
      front: 'Radio failure in the circuit — procedure',
      back: 'Squawk 7600. Continue flying a normal circuit. Watch the ATC tower for light signals. Steady green = cleared to land. Complete a normal landing. Rock wings to acknowledge if able.',
      exerciseId: 'ex_14',
    ),
    Flashcard(
      front: 'Solo authorisation — what it specifies',
      back: 'Specific to: aircraft registration, aerodrome, date, and conditions (e.g., max crosswind, daylight only). May not fly solo in a different aircraft, aerodrome, or outside stated conditions without new authorisation.',
      exerciseId: 'ex_14',
    ),
    Flashcard(
      front: 'What is logged after your first solo?',
      back: 'Pilot In Command (PIC) solo time. Counts toward the 45-hour minimum and the 10-hour solo requirement. Your instructor signs the authorisation in the logbook.',
      exerciseId: 'ex_14',
    ),
  ],

  // ── Exercise 15: Advanced Turning ───────────────────────────────────────
  'ex_15': [
    Flashcard(
      front: 'What is considered a steep turn for PPL purposes?',
      back:
          'A turn with a bank angle of 45 degrees or more. At 45 degrees, the load factor is approximately 1.41g.',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'What additional power is needed in a steep turn?',
      back:
          'Additional power is needed to compensate for the increased drag from the higher angle of attack required to maintain altitude at the higher load factor.',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'What is the overbanking tendency in steep turns?',
      back:
          'The outer (higher) wing moves faster and produces more lift, tending to increase the bank further. The pilot must apply a small amount of opposite aileron to prevent the bank from steepening.',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'What is the stall speed increase at 60 degrees of bank?',
      back:
          'Stall speed increases by approximately 41% (multiplied by the square root of the load factor — sqrt(2) at 60 degrees). For example, a 50-knot stall becomes about 70 knots.',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'How should you recover from an inadvertent steep spiral descent?',
      back:
          'First reduce power (to prevent excessive speed), then level the wings, and finally ease out of the resulting dive gently to avoid exceeding the g-limit or stalling.',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'What reference should you use to maintain altitude in a steep turn?',
      back:
          'The position of the nose relative to the horizon and the altimeter. In a steep turn, the nose appears to be lower than in a shallow turn. Significant back pressure is needed.',
      exerciseId: 'ex_15',
    ),

    Flashcard(
      front: 'Spiral dive recovery — correct sequence',
      back: 'REDUCE power (prevents speed increasing), LEVEL the wings (aileron), EASE out of the dive gently. Do NOT pull first — pulling in a spiral tightens it and risks structural damage.',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'Spiral dive vs spin — key diagnostic difference',
      back: 'Spiral: NOT stalled, airspeed INCREASING rapidly, high G, fast turn. Spin: STALLED, airspeed LOW and constant (~60-80 kt), autorotating. Different recovery for each — correct diagnosis is critical.',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'PPL skills test tolerances for steep turns',
      back: 'Altitude ±100 ft throughout the turn. Roll-out within ±10° of entry heading. Bank angle maintained within ±5° of target (typically 45°).',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'Overbanking tendency in steep turns — cause and correction',
      back: 'Outer wing travels faster → more lift → bank steepens. Correct with slight opposite (into-turn) aileron to hold constant bank angle. Do not use rudder to stop overbanking.',
      exerciseId: 'ex_15',
    ),
    Flashcard(
      front: 'VA (manoeuvring speed) — why fly at or below it in turbulence',
      back: 'Below VA, full deflection of one control surface stalls the aircraft before structural limits are reached. Above VA, abrupt full inputs can exceed structural limits. PA-28-161 VA = 113 KIAS.',
      exerciseId: 'ex_15',
    ),
  ],

  // ── Exercise 16: Forced Landing Without Power ───────────────────────────
  'ex_16': [
    Flashcard(
      front: 'What is the immediate action if the engine fails in flight?',
      back:
          'Adopt the best glide speed immediately — lower the nose to maintain flying speed. This is the most critical action. Height is your most valuable resource.',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'What is the forced landing mnemonic for field selection?',
      back:
          'Wind direction, field Size and Surface, Slope, Surroundings (approach and overshoot paths), and civiLisation (proximity to help). Often remembered as the "five S\'s".',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'What is the typical glide ratio for a Cessna 152/PA-28?',
      back:
          'Approximately 8:1 to 9:1 in still air. This means for every 1,000 feet of height, you can glide about 1.5 nautical miles (approximately 8,000–9,000 feet).',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'What engine restart checks should you attempt during a forced landing?',
      back:
          'Fuel selector (switch tanks), mixture (rich), carb heat (on), magnetos (both), primer (locked), fuel pump (on). If no restart, prepare for the landing.',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'What Mayday call should you make?',
      back:
          'MAYDAY MAYDAY MAYDAY, callsign, nature of emergency (engine failure), position, altitude, intentions (forced landing), POB. Squawk 7700 on the transponder.',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'What should you do just before touchdown in a forced landing?',
      back:
          'Master switch off (to reduce fire risk), fuel off, doors unlatched (so they do not jam on impact), harnesses tight, flaps as required for the shortest ground roll.',
      exerciseId: 'ex_16',
    ),

    Flashcard(
      front: 'Engine failure in flight — immediate action (FLWOP)',
      back: '1. Establish best glide speed IMMEDIATELY (73 KIAS PA-28). 2. Select field. 3. Attempt restart (fuel, mixture, carb heat, mags). 4. MAYDAY call (121.5 MHz), squawk 7700. 5. Fly the forced landing pattern.',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'MAYDAY call format',
      back: 'MAYDAY MAYDAY MAYDAY, [callsign], [nature of emergency], [position], [altitude], [intentions], [persons on board]. Squawk 7700. If already with ATC, declare on that frequency first.',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'Five S\'s of forced landing field selection',
      back: 'Size (long enough), Shape (into-wind landing possible), Surface (firm grass/stubble, no crops/livestock/waterlogging), Slope (landing into slope preferred), Surroundings (clear approach, no power lines, near civilisation).',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'Forced landing key points (height)',
      back: 'Overhead field: 1,000 ft (high key). Abeam threshold downwind: 600-700 ft (low key). Base leg turn: ~400 ft. Final established: ~300 ft. Never commit to a field you cannot safely reach.',
      exerciseId: 'ex_16',
    ),
    Flashcard(
      front: 'Before touchdown in a forced landing — actions',
      back: 'Master switch OFF, fuel OFF, doors unlatched (prevent jamming on impact), harnesses tight and locked, flap as required for minimum landing run. Aim for shortest ground roll possible.',
      exerciseId: 'ex_16',
    ),
  ],

  // ── Exercise 17: Precautionary Landing ──────────────────────────────────
  'ex_17': [
    Flashcard(
      front: 'How does a precautionary landing differ from a forced landing?',
      back:
          'A precautionary landing is made while the engine is still running but conditions make continuing the flight unwise (deteriorating weather, fuel concerns, passenger illness, lost). You have more time to plan.',
      exerciseId: 'ex_17',
    ),
    Flashcard(
      front: 'What is the inspection pass technique?',
      back:
          'Fly over the chosen field at a safe height (500-1,000 ft) to check surface condition, slope, obstacles, and wind direction. Then fly a low pass (not below 200 ft) to confirm suitability before committing.',
      exerciseId: 'ex_17',
    ),
    Flashcard(
      front: 'What are common reasons for a precautionary landing?',
      back:
          'Deteriorating weather, becoming lost, low fuel, technical problems (partial engine failure, rough running), passenger illness, approaching darkness (for non-night-rated pilots).',
      exerciseId: 'ex_17',
    ),
    Flashcard(
      front: 'What should you look for when inspecting a field?',
      back:
          'Obstacles (power lines, fences, trees), surface type (crop height, ploughed, waterlogged), slope, livestock, length adequate for landing, and a clear approach/overshoot path.',
      exerciseId: 'ex_17',
    ),
    Flashcard(
      front: 'What radio call should you make for a precautionary landing?',
      back:
          'PAN PAN PAN PAN PAN PAN, callsign, nature of urgency, position, altitude, intentions, POB. PAN PAN is used for urgent situations, not immediately life-threatening (vs MAYDAY).',
      exerciseId: 'ex_17',
    ),

    Flashcard(
      front: 'PAN PAN vs MAYDAY — when to use each',
      back: 'PAN PAN PAN: urgent situation, not immediately life-threatening (low fuel with aerodrome in range, precautionary landing, passenger ill). MAYDAY MAYDAY MAYDAY: immediate grave danger to aircraft or persons.',
      exerciseId: 'ex_17',
    ),
    Flashcard(
      front: 'Precautionary landing inspection pass heights',
      back: 'First pass (high): 500-1,000 ft — assess overall field and surroundings. Low pass: 300-500 ft with flap — confirm surface, obstacles, slope, approach path. Do not commit until satisfied.',
      exerciseId: 'ex_17',
    ),
    Flashcard(
      front: 'What makes a field unsuitable for precautionary landing?',
      back: 'Power lines on approach, livestock, standing crops (wheat, oilseed rape), waterlogged surface, too short, obstructed approach or overshoot. Downslope landing into a rising slope is preferable to flat or downhill.',
      exerciseId: 'ex_17',
    ),
    Flashcard(
      front: 'Soft field landing technique',
      back: 'Full flap for minimum speed. Touch down as slowly as possible. Hold nose UP with back pressure after touchdown — keep nosewheel off as long as possible. Gentle braking to prevent nose-over.',
      exerciseId: 'ex_17',
    ),
    Flashcard(
      front: 'Common reasons for precautionary landing',
      back: 'Deteriorating weather below VFR minima, low/uncertain fuel, partial power loss, passenger illness, becoming lost, approaching darkness (non-night-rated pilot). Engine still running in all cases.',
      exerciseId: 'ex_17',
    ),
  ],

  // ── Exercise 18A: Navigation ────────────────────────────────────────────
  'ex_18_18a': [
    Flashcard(
      front: 'What is a track and what is a heading?',
      back:
          'Track is the path over the ground. Heading is the direction the nose points. The difference (drift) is caused by wind. Heading = Track +/- wind correction angle.',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: 'What is the 1-in-60 rule?',
      back:
          '1 degree of track error results in 1 NM displacement per 60 NM travelled. It is used to calculate heading corrections and to estimate distance off track.',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: 'What is the mnemonic for VFR pre-flight planning?',
      back:
          'NOTAMs, weather, route (chart preparation, tracks, distances), fuel (plan plus reserves), weight and balance, performance (take-off/landing distances), alternatives.',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: 'What is the difference between magnetic north and true north?',
      back:
          'True north is the geographic North Pole. Magnetic north is where the compass points. The difference is called variation (or magnetic declination). In the UK it is currently about 1 degree west.',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: 'What is the minimum altitude for VFR flight over a congested area?',
      back:
          '1,000 feet above the highest fixed obstacle within 600 metres of the aircraft. Over non-congested areas: 500 feet above ground or water.',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: 'What should you do if you become lost during a VFR navigation flight?',
      back:
          'Climb (for better visibility and radio range), Confess (tell ATC), Communicate (request a position fix or radar assistance), Comply (follow ATC instructions). Consider a precautionary landing if in doubt.',
      exerciseId: 'ex_18_18a',
    ),

    Flashcard(
      front: 'PETER lost procedure mnemonic',
      back: 'Position (estimate from DR), Estimate (how long to identify a fix), Turn (toward safe area if needed), Emergency (squawk 7700/7600 if required), Request (call ATC for assistance/DF/radar fix).',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: '1-in-60 rule — track error correction',
      back: 'Track error angle = (60 ÷ distance flown) × distance off track. Closing angle = (60 ÷ remaining distance) × distance off track. Total correction = track error + closing angle.',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: 'TVMDC — converting true to compass heading',
      back: 'True → Variation → Magnetic → Deviation → Compass. "Variation west, magnetic best (add); east, magnetic least (subtract)." Deviation is the aircraft\'s own magnetic error from the compass correction card.',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: 'UK 1:500,000 chart scale',
      back: '1 cm = 5 km. 1 inch ≈ 7 nm. Used for VFR cross-country planning. Always use current edition — chart symbology and airspace change with each issue.',
      exerciseId: 'ex_18_18a',
    ),
    Flashcard(
      front: 'Dead reckoning (DR) navigation',
      back: 'Estimating current position from a known fix using: heading flown, airspeed, elapsed time, and wind effect (drift). Provides estimated position when visual confirmation is not possible.',
      exerciseId: 'ex_18_18a',
    ),
  ],

  // ── Exercise 18B: Navigation at Lower Levels ────────────────────────────
  'ex_18_18b': [
    Flashcard(
      front: 'What are the hazards of low-level navigation?',
      back:
          'Reduced time to see and avoid obstacles, increased ground speed perception, less time for decision-making, turbulence from terrain, power lines/masts difficult to see, restricted radio range.',
      exerciseId: 'ex_18_18b',
    ),
    Flashcard(
      front: 'When might you need to navigate at lower levels?',
      back:
          'When cloud base or visibility forces you below normal cruising altitude. Also when avoiding controlled airspace above, or when terrain prevents higher altitudes.',
      exerciseId: 'ex_18_18b',
    ),
    Flashcard(
      front: 'What is the minimum flight visibility for VFR in Class G airspace below 3,000 ft AMSL?',
      back:
          '5 km flight visibility, clear of cloud, and in sight of the surface. Below 140 knots IAS: 1,500 m visibility is sufficient.',
      exerciseId: 'ex_18_18b',
    ),
    Flashcard(
      front: 'What map features are most useful for low-level navigation?',
      back:
          'Railways, motorways, rivers, coastlines, large towns, power station cooling towers. These are visible from lower altitudes when smaller features may be hard to identify.',
      exerciseId: 'ex_18_18b',
    ),
    Flashcard(
      front: 'What should you do if weather deteriorates below VFR minima during a flight?',
      back:
          'Turn back to better weather if possible, divert to a nearby airfield, or make a precautionary landing. Do NOT continue into IMC unless instrument rated and in an appropriately equipped aircraft.',
      exerciseId: 'ex_18_18b',
    ),

    Flashcard(
      front: 'VMC minima below 3,000 ft AMSL / 1,000 ft AGL at ≤140 kt in Class G',
      back: '1,500 m flight visibility, clear of cloud, and in sight of the surface. Above this threshold the full VFR minima apply: 5 km, 1,500 m horizontal from cloud, 1,000 ft vertical from cloud.',
      exerciseId: 'ex_18_18b',
    ),
    Flashcard(
      front: 'Low-level checkpoint spacing',
      back: 'At low level use checkpoints every 3-5 minutes (vs 10 min at cruise altitude). Features pass faster: at 90 kt you cover 1.5 nm/min. Less time to identify and act on each feature.',
      exerciseId: 'ex_18_18b',
    ),
    Flashcard(
      front: 'Turbulence on the lee side of terrain',
      back: 'Mechanical turbulence, downdrafts, and rotors occur on the downwind (lee) side of hills and ridges — worst in moderate-to-strong winds. Give high ground a generous clearance on the lee side.',
      exerciseId: 'ex_18_18b',
    ),
    Flashcard(
      front: 'VFR into IMC — why is it so dangerous?',
      back: 'Without visual reference, vestibular system gives false inputs. Spatial disorientation leads to unrecognised spiral dive within minutes. VFR pilots without instrument training have very low survival rates in cloud.',
      exerciseId: 'ex_18_18b',
    ),
    Flashcard(
      front: 'UK minimum low-flying height (outside built-up areas)',
      back: '500 ft above the highest obstacle within 600 m of the aircraft. Over built-up areas: 1,000 ft above the highest obstacle within 600 m. Specified in the UK Air Navigation Order.',
      exerciseId: 'ex_18_18b',
    ),
  ],

  // ── Exercise 18C: Radio Navigation ──────────────────────────────────────
  'ex_18_18c': [
    Flashcard(
      front: 'What is a VOR and how does it work?',
      back:
          'VHF Omnidirectional Range — a ground-based beacon that transmits 360 radials. The aircraft VOR receiver shows which radial you are on and whether you are tracking TO or FROM the station.',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'What is an NDB and what instrument displays it?',
      back:
          'Non-Directional Beacon — a ground-based transmitter. The ADF (Automatic Direction Finder) in the aircraft points a needle toward the NDB station.',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'What is a DME and what does it measure?',
      back:
          'Distance Measuring Equipment — shows the slant range distance from the aircraft to the DME ground station in nautical miles. It also typically shows groundspeed and time to station.',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'What is the difference between a QDM and a QDR?',
      back:
          'QDM is the magnetic heading TO fly to reach a station (with no wind). QDR is the magnetic bearing FROM the station — it is the reciprocal of the QDM.',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'What is a GPS and how is it used for VFR navigation?',
      back:
          'Global Positioning System — satellite-based. It provides accurate position, track, groundspeed, and can navigate to waypoints. However, the pilot must still carry and use current charts as primary reference.',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'What frequency band do VORs operate on?',
      back:
          'VHF band: 108.0 to 117.95 MHz. VORs are line-of-sight — range depends on aircraft altitude and the height of the station.',
      exerciseId: 'ex_18_18c',
    ),

    Flashcard(
      front: 'VOR frequency band and how to identify it before use',
      back: 'VORs: 108.00–117.975 MHz. Must be identified by Morse code ident before use. A continuous tone (no ident) or flag = unreliable. Never navigate on an unidentified VOR.',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'NDB/ADF errors',
      back: 'Night effect (sky waves at night cause bearing errors), coastal refraction (LF waves bend crossing coastlines), thunderstorm interference (ADF needle attracted to lightning — dangerous). Always cross-check with other nav sources.',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'VOR CDI full-scale deflection meaning',
      back: 'Full-scale deflection = 10 degrees or more off the selected radial. Each dot ≈ 2 degrees. Centred needle = within ~0.5-1° of selected course. Large full-scale error means significant track deviation.',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'VOR radial — FROM or TO the station?',
      back: 'VOR radials are always defined FROM the station. The 090 radial extends due east from the VOR. To fly TO the station on this radial, fly approximately 270° magnetic (with a TO indication on the CDI).',
      exerciseId: 'ex_18_18c',
    ),
    Flashcard(
      front: 'NDB frequency band',
      back: 'NDBs: 190–535 kHz (LF/MF band). VOR: 108–117.975 MHz (VHF). ILS localiser: 108–112 MHz odd tenths (VHF). VHF comms: 118–137 MHz.',
      exerciseId: 'ex_18_18c',
    ),
  ],

  // ── Exercise 19: Night Flying ───────────────────────────────────────────
  'ex_19': [
    Flashcard(
      front: 'What is the definition of "night" for aviation purposes in the UK?',
      back:
          'Night is defined as the period from 30 minutes after sunset to 30 minutes before sunrise (official definition used by the CAA/ANO).',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'What are the required aircraft lights for night flight?',
      back:
          'Navigation lights (red port, green starboard, white tail), an anti-collision light (beacon or strobe), and landing lights. All must be serviceable before a night flight.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'What is the minimum time for dark adaptation of the eyes?',
      back:
          'Approximately 20-30 minutes for full dark adaptation. Avoid bright white light during this period. Use red lighting in the cockpit to preserve night vision.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'What visual illusions are common at night?',
      back:
          'Black hole approach (featureless terrain ahead), autokinesis (stationary lights appear to move), false horizon (sloping cloud or lights), and difficulty judging height during the flare.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'What additional equipment is required for night VFR flight?',
      back:
          'A serviceable landing light, adequate cockpit lighting (including a torch/flashlight as backup), navigation lights, anti-collision light, and a way to illuminate the flight instruments.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'What is the "black hole" approach illusion?',
      back:
          'When approaching an airfield over featureless dark terrain (water, unlit countryside), the pilot may perceive a higher approach path than reality, leading to flying dangerously low. Use PAPI/VASI aids.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'Black hole approach illusion — cause and counter',
      back: 'Flying over unlit terrain makes the approach APPEAR higher than it is. Pilot dives below safe glidepath. Counter: use PAPI/VASI as primary reference on ALL night approaches. Never trust visual impression alone over dark terrain.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'Graveyard spiral — what it is and recovery',
      back: 'Aircraft enters banked turn; vestibular system adapts and signals level. Pilot pulls back (thinking slow) which tightens the spiral. Airspeed builds rapidly. Recovery: reduce power, LEVEL WINGS FIRST, then ease out of dive.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'Dark adaptation — time and preservation',
      back: 'Full dark adaptation takes 20-30 minutes. Bright white light resets it immediately. Use red cockpit lighting to preserve night vision. Avoid bright lights for 30 minutes before flight.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'UK aviation definition of night',
      back: 'From end of evening civil twilight (30 min after sunset) to beginning of morning civil twilight (30 min before sunrise). Night rating required to act as PIC during this period.',
      exerciseId: 'ex_19',
    ),
    Flashcard(
      front: 'Autokinesis illusion',
      back: 'Staring at a stationary light in darkness for >a few seconds makes it appear to move. Pilot may make control inputs to correct a false deviation. Prevention: keep eyes scanning — never fixate on one light.',
      exerciseId: 'ex_19',
    ),
  ],
};

/// Returns all composite exercise IDs that have flashcards available.
List<String> get availableFlashcardExercises =>
    flashcardsByExercise.keys.toList();

/// Returns flashcards for a given composite exercise ID, or an empty list.
List<Flashcard> getFlashcards(String compositeExerciseId) =>
    flashcardsByExercise[compositeExerciseId] ?? [];
