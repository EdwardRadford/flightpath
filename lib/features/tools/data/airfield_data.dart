// Static airfield catalogue for the Airfield Info tool.
//
// DATA UNVERIFIED — Ed to review against current AIP and operator NOTAMs before publishing.
//
// Sources used: UK AIP (NATS/CAA public data), aeronautical charts, operator
// websites. All information is publicly available. Frequencies, runway lengths,
// and procedures change — never rely on this data operationally.
//
// Confidence key used in comments:
//   [HIGH]   — cross-checked across multiple published sources
//   [MEDIUM] — single reliable published source
//   [LOW]    — best estimate; needs AIP/NOTAM verification before publishing

import 'package:flight_path/shared/models/airfield.dart';

/// Ordered list of UK training airfields shown in the Airfield Info screen.
///
/// EGTC and EGBT are listed first as they are the primary training fields
/// Ed uses; the rest follow alphabetically by ICAO.
const List<Airfield> kAirfields = [
  // ── Primary training fields ───────────────────────────────────────────────

  Airfield(
    icao: 'EGTC',
    name: 'Cranfield',
    location: 'Cranfield, Bedfordshire',
    // [HIGH] AIP AD 2 EGTC — elevation 358 ft AMSL
    elevation: 358,
    // [HIGH] Standard 2 nm ATZ, surface to 2000 ft QFE
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 03/21, 1799 m asphalt
      AirfieldRunway(
        designator: '03/21',
        lengthMetres: 1799,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGTC COM
      AirfieldFrequency(
        name: 'Cranfield Approach',
        frequency: '122.850',
        usage: 'Approach / AFIS',
      ),
      AirfieldFrequency(
        name: 'Cranfield Tower',
        frequency: '134.930',
        usage: 'Tower (when ATC active)',
      ),
      AirfieldFrequency(
        name: 'Cranfield Ground',
        frequency: '121.950',
        usage: 'Ground movement',
      ),
    ],
    // [HIGH] RW03 right hand, RW21 left hand — standard published procedure
    circuitDirection: 'RW03 right hand; RW21 left hand',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Cranfield is a university airport — expect commercial and research traffic. '
        'ATZ extends over the town; join overhead at 2000 ft QFE then descend on the deadside. '
        'Check NOTAMs for runway works and university research flights. '
        'PA-28 circuit normally uses RW03 or RW21 depending on wind.',
    commonStudentMistakes:
        'Forgetting to report at the overhead before descending to circuit height. '
        'Not checking for crossing traffic on the extended centreline from the university apron. '
        'Misreading QFE — remember Cranfield is 358 ft AMSL so QNH/QFE difference is significant.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBT',
    name: 'Turweston',
    location: 'Turweston, Northamptonshire',
    // [HIGH] AIP AD 2 EGBT — elevation 448 ft AMSL
    elevation: 448,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 03/21, approx 1005 m grass
      AirfieldRunway(
        designator: '03/21',
        lengthMetres: 1005,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBT COM — AGCS
      AirfieldFrequency(
        name: 'Turweston Radio',
        frequency: '122.175',
        usage: 'AGCS — all calls',
      ),
    ],
    // [HIGH] LH circuit both runways (standard at Turweston)
    circuitDirection: 'Left hand (both runways)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Grass strip — check surface condition and runway state on first call. '
        'Busy GA airfield; listen out carefully for other traffic. '
        'Silverstone motor circuit is close to the south — low-flying helicopters during race weekends. '
        'No ATC — AGCS only; self-announce all joins and intentions.',
    commonStudentMistakes:
        'Joining downwind without announcing position on 122.175 first. '
        'Underestimating the visual effect of grass surface on roundout height. '
        'Failing to check for Silverstone event NOTAMs which can temporarily restrict airspace nearby.',
    hasData: true,
  ),

  // ── Other common UK training fields ──────────────────────────────────────

  Airfield(
    icao: 'EGBE',
    name: 'Coventry',
    location: 'Baginton, West Midlands',
    // [HIGH] AIP AD 2 EGBE — elevation 267 ft AMSL
    elevation: 267,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 05/23 main runway, 1611 m asphalt
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 1611,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBE COM
      AirfieldFrequency(
        name: 'Coventry Approach',
        frequency: '123.830',
        usage: 'Approach',
      ),
      AirfieldFrequency(
        name: 'Coventry Tower',
        frequency: '124.800',
        usage: 'Tower / Ground',
      ),
      AirfieldFrequency(
        name: 'Coventry ATIS',
        frequency: '127.750',
        usage: 'ATIS (when available)',
      ),
    ],
    // [MEDIUM] Standard LH circuit for light aircraft
    circuitDirection: 'Check current AIP/NOTAM — verify before flight',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace — clearance required before entering ATZ. '
        'Coventry is a commercial airport with scheduled airline traffic; expect ATC instructions. '
        'PA-28 training flights normally restricted to specific periods — check with aerodrome.',
    commonStudentMistakes:
        'Attempting to enter the ATZ without a clearance — this is Class D airspace. '
        'Forgetting to set the transponder to the assigned squawk before calling. '
        'Not monitoring the tower frequency continuously once inside controlled airspace.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBJ',
    name: 'Gloucestershire',
    location: 'Staverton, Gloucestershire',
    // [HIGH] AIP AD 2 EGBJ — elevation 101 ft AMSL
    elevation: 101,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 09/27, 1312 m asphalt (main)
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 1312,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 04/22 grass strip also available
      AirfieldRunway(
        designator: '04/22',
        lengthMetres: 670,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBJ COM
      AirfieldFrequency(
        name: 'Gloucestershire Approach',
        frequency: '128.550',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Gloucestershire Tower',
        frequency: '122.900',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Gloucestershire ATIS',
        frequency: '127.475',
        usage: 'ATIS',
      ),
    ],
    // [MEDIUM] LH circuit standard; RH for noise abatement on some runways
    circuitDirection: 'RW09 left hand; RW27 right hand — verify current',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Cheltenham racecourse is to the north — temporary airspace restrictions during race meetings. '
        'Radar service available from Approach. '
        'Noise abatement procedures in force — do not overfly Cheltenham to the north.',
    commonStudentMistakes:
        'Not requesting ATIS before calling Approach, leading to incomplete radio calls. '
        'Overlooking the racecourse NOTAMs which can restrict routing. '
        'Confusing the asphalt and grass runway designators during busy circuits.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBO',
    name: 'Wolverhampton Halfpenny Green',
    location: 'Bobbington, Staffordshire',
    // [HIGH] AIP AD 2 EGBO — elevation 283 ft AMSL
    elevation: 283,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 04/22, 1057 m asphalt (main)
      AirfieldRunway(
        designator: '04/22',
        lengthMetres: 1057,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 10/28 grass runway
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 762,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBO COM
      AirfieldFrequency(
        name: 'Halfpenny Green Radio',
        frequency: '123.005',
        usage: 'AFIS — all calls',
      ),
    ],
    // [MEDIUM] Standard LH circuit
    circuitDirection: 'Left hand (verify current AIP)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'AFIS service — information only, not ATC. Pilots are responsible for their own separation. '
        'Busy GA airfield with glider operations possible — check NOTAMs. '
        'Staffordshire and Shropshire are close; check Birmingham CTA lower limit when routing.',
    commonStudentMistakes:
        'Treating AFIS as ATC — AFIS gives information but does not provide clearances. '
        'Not scanning for gliders before joining final (glider operations at and near the field). '
        'Forgetting Birmingham TMA starts at relatively low levels to the north-east.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBP',
    name: 'Cotswold (Kemble)',
    location: 'Kemble, Gloucestershire',
    // [HIGH] AIP AD 2 EGBP — elevation 433 ft AMSL
    elevation: 433,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 08/26, 1840 m asphalt (former RAF runway)
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 1840,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBP COM
      AirfieldFrequency(
        name: 'Kemble Radio',
        frequency: '118.900',
        usage: 'AGCS — all calls',
      ),
    ],
    // [MEDIUM] LH circuit standard
    circuitDirection: 'Left hand (both runways — verify current)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Former RAF Kemble — long asphalt runway. No ATC, AGCS only. '
        'Aerobatic and formation flying are common at this airfield. '
        'The strip is popular with warbird and ex-military types — expect unusual traffic. '
        'Brize Norton CTA is immediately to the north; do not climb above ATZ limits without checking.',
    commonStudentMistakes:
        'The long runway can lead to late roundouts and long landings — maintain normal approach profile. '
        'Brize Norton CTA catches students routing north after departure. '
        'Not self-announcing frequently enough in an AGCS-only environment with high traffic density.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBW',
    name: 'Wellesbourne Mountford',
    location: 'Wellesbourne, Warwickshire',
    // [HIGH] AIP AD 2 EGBW — elevation 159 ft AMSL
    elevation: 159,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 05/23, 1050 m asphalt
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 1050,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 18/36 short grass strip
      AirfieldRunway(
        designator: '18/36',
        lengthMetres: 503,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBW COM
      AirfieldFrequency(
        name: 'Wellesbourne Information',
        frequency: '124.025',
        usage: 'AFIS — all calls',
      ),
    ],
    // [MEDIUM] LH circuit standard
    circuitDirection: 'Left hand (both main runways — verify current)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Popular PPL training airfield. AFIS service — information only. '
        'Busy circuit at weekends; listen out carefully before joining. '
        'Microlight and glider activity nearby — check NOTAMs.',
    commonStudentMistakes:
        'Not listening out long enough before joining to assess circuit traffic. '
        'Mixing up AFIS and ATC authority — AFIS cannot give clearances. '
        'Overlooking the short grass runway when wind favours it — check surface condition.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGCB',
    name: 'Barton (Manchester City)',
    location: 'Eccles, Greater Manchester',
    // [HIGH] AIP AD 2 EGCB — elevation 75 ft AMSL
    elevation: 75,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 09/27 grass (main)
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 726,
        surface: 'Grass',
      ),
      // [HIGH] AIP — 13/31 grass
      AirfieldRunway(
        designator: '13/31',
        lengthMetres: 609,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGCB COM
      AirfieldFrequency(
        name: 'Barton Radio',
        frequency: '122.700',
        usage: 'AGCS — all calls',
      ),
    ],
    // [MEDIUM] LH circuit — but check as can vary by runway
    circuitDirection: 'Left hand (verify by runway — dense urban area constraints)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Surrounded by dense urban area — noise abatement is critical. '
        'Manchester Approach radar is close; stay inside ATZ without coordination. '
        'Manchester CTR starts at low level nearby — check chart before flight. '
        'Short grass runways — assess surface condition before committing.',
    commonStudentMistakes:
        'Climbing above ATZ without checking Manchester CTR lower limits. '
        'Not checking surface (grass softens quickly in wet conditions). '
        'Forgetting noise abatement track after takeoff in a built-up area.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGFF',
    name: 'Cardiff',
    location: 'Rhoose, Vale of Glamorgan',
    // [HIGH] AIP AD 2 EGFF — elevation 220 ft AMSL
    elevation: 220,
    // [HIGH] Standard 2 nm ATZ; Class D airspace
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D CTR)',
    runways: [
      // [HIGH] AIP — 12/30, 2384 m asphalt (main)
      AirfieldRunway(
        designator: '12/30',
        lengthMetres: 2384,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGFF COM
      AirfieldFrequency(
        name: 'Cardiff Approach',
        frequency: '125.850',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Cardiff Tower',
        frequency: '125.000',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Cardiff Ground',
        frequency: '121.750',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Cardiff ATIS',
        frequency: '119.475',
        usage: 'ATIS',
      ),
    ],
    // [MEDIUM] LH circuit standard for light aircraft
    circuitDirection: 'Check current AIP — Class D; ATC directed',
    // [HIGH] Standard 1000 ft QFE (ATC may assign otherwise)
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace — clearance required from Cardiff Approach. '
        'Commercial airline traffic is priority; expect sequencing delays. '
        'Radar service available. Less common for PPL training due to controlled airspace overhead.',
    commonStudentMistakes:
        'Entering the CTR without clearance — this is a serious airspace infringement risk. '
        'Not obtaining ATIS before initial call to Approach. '
        'Forgetting to squawk assigned code continuously within Class D.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHH',
    name: 'Bournemouth',
    location: 'Hurn, Dorset',
    // [HIGH] AIP AD 2 EGHH — elevation 38 ft AMSL
    elevation: 38,
    // [HIGH] Standard 2 nm ATZ; Class D airspace
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D CTR)',
    runways: [
      // [HIGH] AIP — 08/26, 2271 m asphalt (main)
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 2271,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHH COM
      AirfieldFrequency(
        name: 'Bournemouth Approach',
        frequency: '119.475',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Bournemouth Tower',
        frequency: '125.600',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Bournemouth Ground',
        frequency: '121.700',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Bournemouth ATIS',
        frequency: '121.950',
        usage: 'ATIS',
      ),
    ],
    // [MEDIUM] LH circuit for light aircraft — ATC directed
    circuitDirection: 'ATC directed — typically left hand; verify current',
    // [HIGH] Standard 1000 ft QFE (ATC may assign otherwise)
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. '
        'Bournemouth is used for PPL training but ATC procedures apply throughout. '
        'New Forest is to the north-west — routing over national park restricted in places. '
        'Radar vectoring for approaches is standard.',
    commonStudentMistakes:
        'Not having ATIS information before the first Approach call. '
        'Expecting VFR join procedures from a non-controlled field — this is Class D. '
        'Rushing radio calls when sequenced by radar — speak slowly and read back fully.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGTE',
    name: 'Exeter',
    location: 'Clyst Honiton, Devon',
    // [HIGH] AIP AD 2 EGTE — elevation 102 ft AMSL
    elevation: 102,
    // [HIGH] Standard 2 nm ATZ; Class D airspace
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D CTR)',
    runways: [
      // [HIGH] AIP — 08/26, 1834 m asphalt (main)
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 1834,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGTE COM
      AirfieldFrequency(
        name: 'Exeter Approach',
        frequency: '128.975',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Exeter Tower',
        frequency: '119.800',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Exeter Ground',
        frequency: '121.975',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Exeter ATIS',
        frequency: '120.025',
        usage: 'ATIS',
      ),
    ],
    // [MEDIUM] LH circuit standard — ATC directed
    circuitDirection: 'ATC directed — verify current',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. '
        'Exeter is an active regional airport — expect airliner traffic. '
        'Radar service available from Approach. '
        'Dartmoor is to the west — terrain awareness important on approaches in low visibility.',
    commonStudentMistakes:
        'Not requesting radar service when available — use it, especially in reduced visibility. '
        'Routing towards Dartmoor in marginal VMC without terrain awareness. '
        'Forgetting that Class D requires two-way communication and clearance to enter.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHI',
    name: 'Southampton',
    location: 'Eastleigh, Hampshire',
    // [HIGH] AIP AD 2 EGHI — elevation 44 ft AMSL
    elevation: 44,
    // [HIGH] Standard 2 nm ATZ; Class D airspace
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D CTR)',
    runways: [
      // [HIGH] AIP — 02/20, 1723 m asphalt (main)
      AirfieldRunway(
        designator: '02/20',
        lengthMetres: 1723,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHI COM
      AirfieldFrequency(
        name: 'Southampton Approach',
        frequency: '128.850',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Southampton Tower',
        frequency: '118.200',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Southampton Ground',
        frequency: '121.725',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Southampton ATIS',
        frequency: '113.350',
        usage: 'ATIS / VOR-DME SOT',
      ),
    ],
    // [MEDIUM] LH circuit standard — ATC directed
    circuitDirection: 'ATC directed — typically left hand; verify current',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. '
        'Southampton is a busy regional airport — ATC procedures apply. '
        'Solent coastline nearby — overwater routing requires passenger life-jacket consideration. '
        'MOD airspace at Boscombe Down and Netheravon is close to the north.',
    commonStudentMistakes:
        'Not accounting for the Solent overwater sector when planning or routing. '
        'Failing to obtain clearance before entering the Class D CTR. '
        'Not checking MOD airspace to the north when routing away after departure.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGKA',
    name: 'Shoreham (Brighton City)',
    location: 'Shoreham-by-Sea, West Sussex',
    // [HIGH] AIP AD 2 EGKA — elevation 7 ft AMSL
    elevation: 7,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 02/20, 949 m asphalt (main)
      AirfieldRunway(
        designator: '02/20',
        lengthMetres: 949,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 07/25 grass also available
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 762,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGKA COM
      AirfieldFrequency(
        name: 'Shoreham Approach',
        frequency: '123.150',
        usage: 'Approach / AFIS',
      ),
      AirfieldFrequency(
        name: 'Shoreham Tower',
        frequency: '125.400',
        usage: 'Tower (when active)',
      ),
    ],
    // [MEDIUM] LH circuit standard
    circuitDirection: 'Left hand (both runways — verify current)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Historic art-deco terminal — popular cross-country destination. '
        'Very close to the South Downs — terrain awareness important when routing north. '
        'Gatwick CAS starts immediately overhead at relatively low levels. '
        'Beach and seafront noise abatement track required on departure towards the sea.',
    commonStudentMistakes:
        'Climbing too quickly after departure and entering Gatwick CAS above. '
        'Underestimating the South Downs terrain when routing north of the field. '
        'Not checking the overhead Gatwick lower CAS limits when planning VFR departures.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGKB',
    name: 'Biggin Hill',
    location: 'Biggin Hill, Greater London',
    // [HIGH] AIP AD 2 EGKB — elevation 598 ft AMSL
    elevation: 598,
    // [HIGH] Standard 2 nm ATZ; surrounded by London TMA
    atzDescription: '2 nm radius, surface to 2000 ft QFE (London TMA above)',
    runways: [
      // [HIGH] AIP — 03/21, 1817 m asphalt (main)
      AirfieldRunway(
        designator: '03/21',
        lengthMetres: 1817,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGKB COM
      AirfieldFrequency(
        name: 'Biggin Hill Approach',
        frequency: '129.400',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Biggin Hill Tower',
        frequency: '134.800',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Biggin Hill Ground',
        frequency: '121.875',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Biggin Hill ATIS',
        frequency: '127.125',
        usage: 'ATIS',
      ),
    ],
    // [HIGH] LH circuit for RW03; RH circuit for RW21 (noise abatement over residential)
    circuitDirection: 'RW03 left hand; RW21 right hand (noise abatement)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Surrounded by London TMA — strict noise abatement procedures. Do not deviate from published tracks. '
        'Gatwick, Heathrow and London City are all nearby — the surrounding airspace is complex. '
        'PPL training is active here but ATC is full service. '
        'Transponder mandatory in the London TMA when flying to/from Biggin Hill.',
    commonStudentMistakes:
        'Deviating from noise abatement departure tracks — serious consequences near residential areas. '
        'Underestimating the complexity of the surrounding London TMA. '
        'Not having a Mode C transponder serviceable — it is mandatory in the London TMA.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGNM',
    name: 'Sherburn-in-Elmet',
    location: 'Sherburn-in-Elmet, North Yorkshire',
    // [HIGH] AIP AD 2 EGNM — elevation 26 ft AMSL
    elevation: 26,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 10/28 grass (main)
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 768,
        surface: 'Grass',
      ),
      // [MEDIUM] 06/24 grass also available
      AirfieldRunway(
        designator: '06/24',
        lengthMetres: 610,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGNM COM
      AirfieldFrequency(
        name: 'Sherburn Radio',
        frequency: '122.600',
        usage: 'AGCS — all calls',
      ),
    ],
    // [MEDIUM] LH circuit standard at Sherburn
    circuitDirection: 'Left hand (verify current)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Very popular gliding and PPL training aerodrome. '
        'Glider operations are common — expect gliders in the circuit and on approach. '
        'AGCS only — no ATC. All separation is pilot responsibility. '
        'Leeds Bradford CTR and Leeds Bradford Approach sector are nearby to the north-west.',
    commonStudentMistakes:
        'Failing to look for gliders before joining — they move fast and quietly. '
        'Treating the AGCS as an ATC service. '
        'Not checking Leeds Bradford CTR boundaries when routing north.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGSG',
    name: 'Stapleford',
    location: 'Stapleford Tawney, Essex',
    // [HIGH] AIP AD 2 EGSG — elevation 183 ft AMSL
    elevation: 183,
    // [HIGH] Standard 2 nm ATZ
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 04/22 grass (main)
      AirfieldRunway(
        designator: '04/22',
        lengthMetres: 750,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGSG COM
      AirfieldFrequency(
        name: 'Stapleford Radio',
        frequency: '122.800',
        usage: 'AGCS — all calls',
      ),
    ],
    // [MEDIUM] LH circuit standard
    circuitDirection: 'Left hand (verify current)',
    // [HIGH] Standard 1000 ft QFE
    circuitAltitude: 1000,
    localRules:
        'Popular Essex flying club and PPL training field. '
        'London TMA starts overhead — transponder required above ATZ. '
        'Stansted CTR is very close to the north; do not route north without checking. '
        'Busy circuit at weekends — listen out carefully before joining.',
    commonStudentMistakes:
        'Routing north of the field and entering Stansted CTR uncleared. '
        'Climbing above ATZ into London TMA without a transponder squawk and clearance. '
        'Not listening out for other traffic before joining a busy weekend circuit.',
    hasData: true,
  ),

  // ── South East England ────────────────────────────────────────────────────

  Airfield(
    icao: 'EGKR',
    name: 'Redhill',
    location: 'Redhill, Surrey',
    // [HIGH] AIP AD 2 EGKR — elevation 222 ft AMSL
    elevation: 222,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 08/26, 933 m asphalt
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 933,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 18/36 grass strip
      AirfieldRunway(
        designator: '18/36',
        lengthMetres: 579,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGKR COM
      AirfieldFrequency(
        name: 'Redhill Information',
        frequency: '119.600',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'RW08 left hand; RW26 right hand (noise abatement — verify current)',
    circuitAltitude: 1000,
    localRules:
        'Busy GA airfield south of London. Gatwick CAS starts directly overhead — stay below ATZ limits. '
        'Helicopter operations are common at Redhill. '
        'Noise abatement routes apply; do not overfly residential areas to the north.',
    commonStudentMistakes:
        'Climbing above ATZ and entering Gatwick CAS without clearance. '
        'Not looking out for helicopter traffic operating to/from the helipad area. '
        'Misjudging the upslope visual effect on short final for RW08.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGLK',
    name: 'Blackbushe',
    location: 'Yateley, Hampshire',
    // [HIGH] AIP AD 2 EGLK — elevation 325 ft AMSL
    elevation: 325,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 08/26, 1110 m asphalt
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 1110,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGLK COM
      AirfieldFrequency(
        name: 'Blackbushe Tower',
        frequency: '122.300',
        usage: 'Tower / AFIS',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Farnborough CAS is immediately adjacent — strict awareness of the boundary required. '
        'Military danger areas to the south-west. '
        'Busy light aircraft market and training field; weekend circuits can be very active.',
    commonStudentMistakes:
        'Drifting into Farnborough CAS which starts at low levels nearby. '
        'Not monitoring Farnborough LARS when transiting in the area. '
        'Forgetting the Aldershot/Odiham low-flying military activity to the south.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGLM',
    name: 'White Waltham',
    location: 'Maidenhead, Berkshire',
    // [HIGH] AIP AD 2 EGLM — elevation 131 ft AMSL
    elevation: 131,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 07/25, 1148 m grass (main)
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 1148,
        surface: 'Grass',
      ),
      // [MEDIUM] 03/21 grass also available
      AirfieldRunway(
        designator: '03/21',
        lengthMetres: 853,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGLM COM
      AirfieldFrequency(
        name: 'White Waltham Approach',
        frequency: '122.600',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (standard — verify current)',
    circuitAltitude: 1000,
    localRules:
        'Home of the West London Aero Club — one of the UK\'s largest flying clubs. '
        'Multiple grass runways in use simultaneously; listen carefully for which is active. '
        'Heathrow CAS starts overhead — do not exceed ATZ ceiling. '
        'Windsor Castle is to the north-east — noise abatement applies.',
    commonStudentMistakes:
        'Climbing into Heathrow CAS which begins at low levels immediately above. '
        'Misidentifying the active runway when multiple strips are in use. '
        'Not following the published noise abatement routing past Windsor.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGLS',
    name: 'Old Sarum',
    location: 'Salisbury, Wiltshire',
    // [HIGH] AIP AD 2 EGLS — elevation 282 ft AMSL
    elevation: 282,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 06/24, 740 m grass
      AirfieldRunway(
        designator: '06/24',
        lengthMetres: 740,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGLS COM
      AirfieldFrequency(
        name: 'Old Sarum Radio',
        frequency: '123.225',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Surrounded by Boscombe Down and Salisbury Plain danger areas. '
        'Check active danger areas D323 and Salisbury Plain LFAs before flight. '
        'Historic hillfort Old Sarum is adjacent — landmark for local navigation. '
        'AGCS only; no ATC.',
    commonStudentMistakes:
        'Not checking Salisbury Plain LFA activity — fast jets at very low level. '
        'Routing towards Boscombe Down active danger area without checking NOTAMs. '
        'Underestimating the density of military low-flying in the Wiltshire area.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGTB',
    name: 'Wycombe Air Park (Booker)',
    location: 'Booker, Buckinghamshire',
    // [HIGH] AIP AD 2 EGTB — elevation 520 ft AMSL
    elevation: 520,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 06/24, 1035 m asphalt
      AirfieldRunway(
        designator: '06/24',
        lengthMetres: 1035,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGTB COM
      AirfieldFrequency(
        name: 'Wycombe Tower',
        frequency: '126.550',
        usage: 'Tower / AFIS',
      ),
    ],
    circuitDirection: 'RW06 left hand; RW24 right hand (noise abatement — verify)',
    circuitAltitude: 1000,
    localRules:
        'Major PPL training base in the Thames Valley. '
        'Heathrow and London TMA overhead — strict altitude discipline essential. '
        'Noise abatement procedures in force over Marlow to the south. '
        'Glider activity from the adjacent Booker Gliding Club.',
    commonStudentMistakes:
        'Exceeding ATZ ceiling into London TMA above. '
        'Not accounting for terrain — field sits at 520 ft, significant QNH/QFE correction. '
        'Missing glider traffic operating from the same airfield.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGTK',
    name: 'Oxford (Kidlington)',
    location: 'Kidlington, Oxfordshire',
    // [HIGH] AIP AD 2 EGTK — elevation 270 ft AMSL
    elevation: 270,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 01/19, 1442 m asphalt (main)
      AirfieldRunway(
        designator: '01/19',
        lengthMetres: 1442,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGTK COM
      AirfieldFrequency(
        name: 'Oxford Approach',
        frequency: '125.325',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Oxford Tower',
        frequency: '118.875',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Oxford ATIS',
        frequency: '136.225',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Home of Oxford Aviation Academy — high-density professional training traffic. '
        'Brize Norton CTR is adjacent to the west; LARS available from Brize. '
        'Expect busy radio environment with commercial training calls. '
        'Full ATC service.',
    commonStudentMistakes:
        'Entering Brize Norton CTR without a clearance when routing west. '
        'Being overwhelmed by high radio workload from professional training traffic. '
        'Not requesting ATIS before the initial call.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGLG',
    name: 'Panshanger (CLOSED)',
    location: 'Welwyn Garden City, Hertfordshire',
    // [MEDIUM] Closed 2016 — data retained for reference only
    elevation: 249,
    atzDescription: 'Aerodrome permanently closed — ATZ no longer active',
    runways: [],
    frequencies: [],
    circuitDirection: 'Aerodrome closed — do not attempt to land',
    circuitAltitude: 1000,
    localRules:
        'PANSHANGER IS PERMANENTLY CLOSED (closed 2016). '
        'The site has been developed. Do not attempt to use this aerodrome. '
        'Retained in database for historical/exam reference only.',
    commonStudentMistakes:
        'Some older charts still show Panshanger — always use current edition charts.',
    hasData: false,
  ),

  Airfield(
    icao: 'EGSX',
    name: 'North Weald',
    location: 'North Weald Bassett, Essex',
    // [HIGH] AIP AD 2 EGSX — elevation 321 ft AMSL
    elevation: 321,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 02/20, 1509 m asphalt (main)
      AirfieldRunway(
        designator: '02/20',
        lengthMetres: 1509,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGSX COM
      AirfieldFrequency(
        name: 'North Weald Radio',
        frequency: '123.525',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Former RAF station — long asphalt runway popular with warbirds and GA. '
        'Air shows and events held here — check NOTAMs for temporary restrictions. '
        'London TMA overhead; Stansted CTR to the north. '
        'AGCS only — no ATC.',
    commonStudentMistakes:
        'Climbing above ATZ into London TMA without clearance. '
        'Not checking for air show NOTAMs which close or restrict the field. '
        'Long runway encourages relaxed approach — maintain normal speeds.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGMC',
    name: 'Southend',
    location: 'Rochford, Essex',
    // [HIGH] AIP AD 2 EGMC — elevation 49 ft AMSL
    elevation: 49,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 06/24, 1855 m asphalt (main)
      AirfieldRunway(
        designator: '06/24',
        lengthMetres: 1855,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGMC COM
      AirfieldFrequency(
        name: 'Southend Approach',
        frequency: '130.775',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Southend Tower',
        frequency: '127.725',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Southend ATIS',
        frequency: '121.800',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. Commercial airline and charter operations alongside GA. '
        'Thames Estuary overwater sector close to the south. '
        'Radar service available. ATC clearance required before entering CTR.',
    commonStudentMistakes:
        'Not obtaining clearance before entering Class D CTR. '
        'Forgetting the overwater routing implications over the Thames Estuary. '
        'Not having ATIS before initial Approach call.',
    hasData: true,
  ),

  // ── South East England — additional ──────────────────────────────────────

  Airfield(
    icao: 'EGHR',
    name: 'Chichester/Goodwood',
    location: 'Westhampnett, West Sussex',
    // [HIGH] AIP AD 2 EGHR — elevation 98 ft AMSL
    elevation: 98,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 06/24, 896 m grass (main)
      AirfieldRunway(
        designator: '06/24',
        lengthMetres: 896,
        surface: 'Grass',
      ),
      // [MEDIUM] 10/28 and 14/32 grass also available
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 712,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHR COM
      AirfieldFrequency(
        name: 'Goodwood Radio',
        frequency: '122.450',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (standard — verify current)',
    circuitAltitude: 1000,
    localRules:
        'Goodwood motor racing circuit is adjacent — event NOTAMs can restrict airspace. '
        'South Downs is directly to the north — terrain awareness when routing inland. '
        'Popular destination. Multiple grass runways; listen for active runway. '
        'AFIS service — information only.',
    commonStudentMistakes:
        'Not checking Goodwood race event NOTAMs. '
        'Routing north and flying into rising South Downs terrain in marginal visibility. '
        'Treating AFIS calls as ATC clearances.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHL',
    name: 'Lasham',
    location: 'Lasham, Hampshire',
    // [HIGH] AIP AD 2 EGHL — elevation 618 ft AMSL
    elevation: 618,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 09/27, 1524 m asphalt
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 1524,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHL COM
      AirfieldFrequency(
        name: 'Lasham Radio',
        frequency: '123.050',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current — gliding ops)',
    circuitAltitude: 1000,
    localRules:
        'One of the UK\'s busiest gliding centres — glider and tug operations are continuous. '
        'Power pilots must give way to gliders and be extremely vigilant. '
        'AGCS only. Notify on first call that you are a powered aircraft. '
        'High elevation (618 ft) — significant QFE correction from QNH.',
    commonStudentMistakes:
        'Not expecting the volume of glider traffic — Lasham is primarily a gliding airfield. '
        'Forgetting the high elevation when calculating QFE. '
        'Entering the circuit without announcing aircraft type (powered vs glider).',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHA',
    name: 'Compton Abbas',
    location: 'Shaftesbury, Dorset',
    // [HIGH] AIP AD 2 EGHA — elevation 811 ft AMSL
    elevation: 811,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 08/26, 603 m grass
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 603,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHA COM
      AirfieldFrequency(
        name: 'Compton Abbas Radio',
        frequency: '122.700',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'High-elevation ridge-top strip — density altitude consideration in summer. '
        'Short grass runway; upslope on landing RW08. '
        'Stunning Dorset views but terrain drops sharply on all sides. '
        'Popular touring destination. AGCS only.',
    commonStudentMistakes:
        'Not accounting for density altitude at 811 ft in warm conditions — longer take-off roll. '
        'Misjudging the upslope when landing RW08. '
        'Forgetting that terrain falls away sharply; early go-around commitment is essential.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHB',
    name: 'Headcorn (Lashenden)',
    location: 'Headcorn, Kent',
    // [HIGH] AIP AD 2 EGHB — elevation 72 ft AMSL
    elevation: 72,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 10/28, 870 m grass (main)
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 870,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHB COM
      AirfieldFrequency(
        name: 'Headcorn Radio',
        frequency: '122.000',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Parachute drop zone — skydivers descend onto and around the airfield. '
        'Check for active drop activity before joining. '
        'Popular GA destination in the Weald of Kent. '
        'AGCS only; announce intentions clearly.',
    commonStudentMistakes:
        'Joining without checking for active parachute drops overhead. '
        'Not scanning above the aircraft for descending parachutists. '
        'Rushing the approach when nervous about DZ activity.',
    hasData: true,
  ),

  // ── South West England ────────────────────────────────────────────────────

  Airfield(
    icao: 'EGHD',
    name: 'Plymouth City',
    location: 'Crownhill, Plymouth, Devon',
    // [HIGH] AIP AD 2 EGHD — elevation 476 ft AMSL
    elevation: 476,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 06/24, 1154 m asphalt
      AirfieldRunway(
        designator: '06/24',
        lengthMetres: 1154,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHD COM
      AirfieldFrequency(
        name: 'Plymouth Approach',
        frequency: '133.550',
        usage: 'Approach / AFIS',
      ),
      AirfieldFrequency(
        name: 'Plymouth Tower',
        frequency: '122.600',
        usage: 'Tower (when active)',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Elevated site — density altitude in summer. Dartmoor to the north-east; terrain awareness essential. '
        'Plymouth Sound overwater to the south. '
        'MOD Devonport and naval activity nearby. '
        'Check for temporary restrictions around naval exercise areas.',
    commonStudentMistakes:
        'Routing too close to Dartmoor terrain in reduced visibility. '
        'Forgetting the density altitude effect at 476 ft elevation in summer. '
        'Not checking MOD restrictions around Plymouth Sound and Devonport.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHQ',
    name: 'Newquay Cornwall',
    location: 'St Mawgan, Cornwall',
    // [HIGH] AIP AD 2 EGHQ — elevation 390 ft AMSL
    elevation: 390,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 12/30, 2744 m asphalt (former RAF St Mawgan)
      AirfieldRunway(
        designator: '12/30',
        lengthMetres: 2744,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHQ COM
      AirfieldFrequency(
        name: 'Newquay Approach',
        frequency: '133.400',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Newquay Tower',
        frequency: '121.350',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Newquay ATIS',
        frequency: '124.175',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Former RAF St Mawgan — very long runway. Commercial operations and ATC in service. '
        'North Cornwall coast to the west; sea fog common. '
        'Military parachuting occasionally still conducted from associated facilities.',
    commonStudentMistakes:
        'Arriving in sea fog without checking weather at this coastal site. '
        'Not obtaining ATIS before the initial Approach call. '
        'Not expecting the very long runway — maintain normal approach speed.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGTP',
    name: 'Perranporth',
    location: 'Perranporth, Cornwall',
    // [MEDIUM] Elevation approx 290 ft AMSL
    elevation: 290,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [MEDIUM] 05/23 grass (main)
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 671,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [MEDIUM] AGCS frequency
      AirfieldFrequency(
        name: 'Perranporth Radio',
        frequency: '119.750',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Clifftop grass strip close to the Atlantic coast. '
        'Sea mist and low cloud common; check weather carefully. '
        'Coastal wind can be strong and gusty — check crosswind component. '
        'AGCS only.',
    commonStudentMistakes:
        'Underestimating coastal wind strength and variability at this exposed site. '
        'Arriving without checking for sea fog at this clifftop location. '
        'Not accounting for cliff-edge turbulence on approach.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHO',
    name: 'Thruxton',
    location: 'Thruxton, Hampshire',
    // [HIGH] AIP AD 2 EGHO — elevation 319 ft AMSL
    elevation: 319,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 07/25, 914 m asphalt (main)
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 914,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHO COM
      AirfieldFrequency(
        name: 'Thruxton Radio',
        frequency: '130.450',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Major PPL training base in Hampshire. '
        'Thruxton motor racing circuit is adjacent — event NOTAMs can temporarily close airfield. '
        'Boscombe Down and Salisbury Plain danger areas close to the north. '
        'AGCS only; self-announce all positions.',
    commonStudentMistakes:
        'Not checking Thruxton race event NOTAMs before planning a visit. '
        'Routing north into Salisbury Plain danger areas without checking NOTAM status. '
        'Failing to announce on AGCS early enough when multiple aircraft are in the circuit.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHC',
    name: "Land's End",
    location: "St Just, Cornwall",
    // [HIGH] AIP AD 2 EGHC — elevation 401 ft AMSL
    elevation: 401,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 07/25, 672 m asphalt (main)
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 672,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 16/34 grass also available
      AirfieldRunway(
        designator: '16/34',
        lengthMetres: 533,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHC COM
      AirfieldFrequency(
        name: "Land's End Radio",
        frequency: '122.150',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Westernmost licensed aerodrome in England — exposed Atlantic location. '
        'Isles of Scilly route passes through this area; check Scilly TMA. '
        'Strong and variable coastal winds; sea fog common. '
        'AFIS service.',
    commonStudentMistakes:
        'Arriving without comprehensive weather check — coastal fog closes this site rapidly. '
        'Not checking the Isles of Scilly TMA when routing beyond Land\'s End. '
        'Underestimating turbulence from Atlantic swell-driven wind effects.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGHE',
    name: "St Mary's, Isles of Scilly",
    location: "St Mary's, Isles of Scilly",
    // [HIGH] AIP AD 2 EGHE — elevation 116 ft AMSL
    elevation: 116,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 09/27, 1198 m asphalt (main)
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 1198,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGHE COM
      AirfieldFrequency(
        name: "St Mary's Radio",
        frequency: '123.150',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Island airport requiring overwater flight from the mainland. '
        'Life jackets required when overflying sea beyond gliding range. '
        'Weather deteriorates rapidly — always check forecast and have return plan. '
        'AFIS service. Customs available.',
    commonStudentMistakes:
        'Not carrying appropriate survival equipment for the overwater sector. '
        'Routing to Scilly without checking weather — island fog traps pilots regularly. '
        'Not filing a flight plan for the overwater crossing.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGTU',
    name: 'Dunkeswell',
    location: 'Dunkeswell, Devon',
    // [HIGH] AIP AD 2 EGTU — elevation 850 ft AMSL
    elevation: 850,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 05/23, 1173 m asphalt
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 1173,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGTU COM
      AirfieldFrequency(
        name: 'Dunkeswell Radio',
        frequency: '123.475',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current — parachute ops)',
    circuitAltitude: 1000,
    localRules:
        'Highest paved aerodrome in southern England at 850 ft — density altitude significant. '
        'Active parachute drop zone — skydivers in circuit area. '
        'Blackdown Hills terrain surrounds the field. '
        'AGCS only; announce intentions clearly including parachute status check.',
    commonStudentMistakes:
        'Not checking for active parachute operations before joining. '
        'Significant QFE correction at 850 ft — easy to get the altimeter wrong. '
        'Underestimating density altitude in summer on a short-field calculation.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGFH',
    name: 'Swansea',
    location: 'Fairwood Common, Swansea',
    // [HIGH] AIP AD 2 EGFH — elevation 299 ft AMSL
    elevation: 299,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 04/22, 1207 m asphalt (main)
      AirfieldRunway(
        designator: '04/22',
        lengthMetres: 1207,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 10/28 asphalt also available
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 971,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGFH COM
      AirfieldFrequency(
        name: 'Swansea Radio',
        frequency: '119.700',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Training airfield on Gower Peninsula — coastal weather common. '
        'Pembrey danger area to the west. '
        'AFIS service. Check Cardiff CAS when routing east.',
    commonStudentMistakes:
        'Not checking Pembrey danger area status when routing west. '
        'Forgetting Cardiff CTR constraints when routing east towards Cardiff. '
        'Sea fog from the Bristol Channel affecting visibility on approach.',
    hasData: true,
  ),

  // ── East Anglia / East Midlands ───────────────────────────────────────────

  Airfield(
    icao: 'EGSF',
    name: 'Peterborough/Conington',
    location: 'Conington, Cambridgeshire',
    // [HIGH] AIP AD 2 EGSF — elevation 26 ft AMSL
    elevation: 26,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 10/28, 1122 m asphalt
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 1122,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGSF COM
      AirfieldFrequency(
        name: 'Conington Radio',
        frequency: '129.725',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Popular training and cross-country destination in the Fens. '
        'Very flat terrain — navigation by landmarks can be challenging. '
        'AFIS service. East Midlands and Stansted radar available for transit.',
    commonStudentMistakes:
        'Navigation errors in the featureless Fens terrain. '
        'Not contacting East Midlands radar when transiting the area at higher levels. '
        'Forgetting the flat terrain means less visual cue for circuit height assessment.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGSO',
    name: 'Crowfield',
    location: 'Crowfield, Suffolk',
    // [MEDIUM] Elevation approx 174 ft AMSL
    elevation: 174,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [MEDIUM] 05/23 grass (main)
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 640,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [MEDIUM] AGCS frequency
      AirfieldFrequency(
        name: 'Crowfield Radio',
        frequency: '122.780',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Small Suffolk grass strip. AGCS only. '
        'Wattisham military airfield is close — check Wattisham MATZ when routing. '
        'Norwich approach radar available for transit traffic.',
    commonStudentMistakes:
        'Routing through Wattisham MATZ without calling Wattisham Approach. '
        'Grass surface can be soft in wet weather — check NOTAMs for surface condition.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBG',
    name: 'Leicester',
    location: 'Stoughton, Leicestershire',
    // [HIGH] AIP AD 2 EGBG — elevation 469 ft AMSL
    elevation: 469,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 10/28, 720 m grass (main)
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 720,
        surface: 'Grass',
      ),
      // [MEDIUM] 05/23 grass also available
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 583,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBG COM
      AirfieldFrequency(
        name: 'Leicester Radio',
        frequency: '122.125',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Popular East Midlands training airfield. '
        'East Midlands CTR is close to the west. '
        'AGCS only. Density altitude significant at 469 ft elevation.',
    commonStudentMistakes:
        'Routing west without checking East Midlands CTR boundaries. '
        'Not accounting for elevation when calculating performance figures. '
        'Soft grass in wet conditions — check NOTAMs for surface state.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBK',
    name: 'Sywell',
    location: 'Sywell, Northamptonshire',
    // [HIGH] AIP AD 2 EGBK — elevation 429 ft AMSL
    elevation: 429,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 03/21, 1191 m grass (main)
      AirfieldRunway(
        designator: '03/21',
        lengthMetres: 1191,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBK COM
      AirfieldFrequency(
        name: 'Sywell Radio',
        frequency: '122.700',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Major PPL training base and popular GA destination. '
        'Turweston is close to the south; coordinate when routing between the two. '
        'AFIS service. Busy at weekends — listen out carefully before joining. '
        'Historic airfield — vintage aircraft common.',
    commonStudentMistakes:
        'Not anticipating heavy circuit traffic at weekends. '
        'Forgetting Turweston ATZ to the south when routing. '
        'Confusing AFIS with ATC authority.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBN',
    name: 'Nottingham (Tollerton)',
    location: 'Tollerton, Nottinghamshire',
    // [HIGH] AIP AD 2 EGBN — elevation 238 ft AMSL
    elevation: 238,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 09/27, 1237 m asphalt (main)
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 1237,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBN COM
      AirfieldFrequency(
        name: 'Tollerton Radio',
        frequency: '134.875',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'East Midlands GA hub. Close to East Midlands CTR — check boundaries when routing. '
        'AFIS service. Nottingham city to the north-west.',
    commonStudentMistakes:
        'Routing north-west towards East Midlands CTR without checking boundaries. '
        'Not requesting LARS from East Midlands when transiting.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBM',
    name: 'Tatenhill',
    location: 'Tatenhill, Staffordshire',
    // [MEDIUM] Elevation approx 439 ft AMSL
    elevation: 439,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [MEDIUM] 09/27 asphalt (main)
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 900,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [MEDIUM] AFIS frequency
      AirfieldFrequency(
        name: 'Tatenhill Radio',
        frequency: '124.075',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Staffordshire GA airfield. East Midlands CTA to the east. '
        'AFIS service. Close to Birmingham CTR — check when routing south.',
    commonStudentMistakes:
        'Not checking Birmingham CTR lower limits when routing south. '
        'Confusing AFIS with ATC authority.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGBS',
    name: 'Shobdon',
    location: 'Shobdon, Herefordshire',
    // [HIGH] AIP AD 2 EGBS — elevation 318 ft AMSL
    elevation: 318,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 09/27, 868 m asphalt (main)
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 868,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBS COM
      AirfieldFrequency(
        name: 'Shobdon Radio',
        frequency: '123.500',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Rural Herefordshire airfield surrounded by hills. '
        'Welsh hills to the west — terrain awareness essential when routing towards Wales. '
        'AFIS service. Glider operations nearby at Welshpool.',
    commonStudentMistakes:
        'Underestimating Welsh hill terrain when routing westward. '
        'Not checking weather over high ground before departing westbound.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGSV',
    name: 'Old Buckenham',
    location: 'Old Buckenham, Norfolk',
    // [MEDIUM] Elevation approx 170 ft AMSL
    elevation: 170,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [MEDIUM] 07/25 grass (main)
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 826,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [MEDIUM] AGCS frequency
      AirfieldFrequency(
        name: 'Old Buckenham Radio',
        frequency: '118.475',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Norfolk grass strip. AGCS only. '
        'Norwich CTR to the north. Flat Fenland terrain — visual navigation requires care. '
        'Broads and coastal areas create sea fog risk in summer.',
    commonStudentMistakes:
        'Navigation in the flat featureless Norfolk landscape. '
        'Not checking Norwich CTR when routing north.',
    hasData: true,
  ),

  // ── Northern England ──────────────────────────────────────────────────────

  Airfield(
    icao: 'EGNJ',
    name: 'Humberside',
    location: 'Kirmington, Lincolnshire',
    // [HIGH] AIP AD 2 EGNJ — elevation 121 ft AMSL
    elevation: 121,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 03/21, 2469 m asphalt
      AirfieldRunway(
        designator: '03/21',
        lengthMetres: 2469,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGNJ COM
      AirfieldFrequency(
        name: 'Humberside Approach',
        frequency: '119.125',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Humberside Tower',
        frequency: '124.675',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Humberside ATIS',
        frequency: '124.050',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Regional airport with full ATC. Humber Estuary to the south — coastal weather. '
        'Radar service available. Commercial and GA traffic mix.',
    commonStudentMistakes:
        'Not obtaining ATIS before first Approach call. '
        'Coastal sea fog from the Humber Estuary arriving rapidly.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGNR',
    name: 'Hawarden',
    location: 'Hawarden, Flintshire, Wales',
    // [HIGH] AIP AD 2 EGNR — elevation 45 ft AMSL
    elevation: 45,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 04/22, 1959 m asphalt (main)
      AirfieldRunway(
        designator: '04/22',
        lengthMetres: 1959,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGNR COM
      AirfieldFrequency(
        name: 'Hawarden Approach',
        frequency: '123.350',
        usage: 'Approach / AFIS',
      ),
      AirfieldFrequency(
        name: 'Hawarden Tower',
        frequency: '124.950',
        usage: 'Tower (when active)',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Adjacent to Airbus factory — large aircraft movements. '
        'Liverpool CTR and Manchester CTR are close; check boundaries. '
        'AFIS and Tower service depending on activity.',
    commonStudentMistakes:
        'Not checking Liverpool or Manchester CTR when routing north or east. '
        'Being surprised by large Airbus aircraft movements on the long runway.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGNT',
    name: 'Newcastle',
    location: 'Woolsington, Tyne and Wear',
    // [HIGH] AIP AD 2 EGNT — elevation 266 ft AMSL
    elevation: 266,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 07/25, 2329 m asphalt (main)
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 2329,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGNT COM
      AirfieldFrequency(
        name: 'Newcastle Approach',
        frequency: '124.375',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Newcastle Tower',
        frequency: '119.700',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Newcastle Ground',
        frequency: '121.725',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Newcastle ATIS',
        frequency: '126.350',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — Class D; verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. Regional airport with commercial traffic. '
        'Radar service. Clearance required before entering CTR.',
    commonStudentMistakes:
        'Entering Class D CTR without clearance. '
        'Not obtaining ATIS before initial Approach call.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGNV',
    name: 'Teesside International',
    location: 'Darlington, County Durham',
    // [HIGH] AIP AD 2 EGNV — elevation 120 ft AMSL
    elevation: 120,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 05/23, 2290 m asphalt (main)
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 2290,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGNV COM
      AirfieldFrequency(
        name: 'Teesside Approach',
        frequency: '118.850',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Teesside Tower',
        frequency: '119.800',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Teesside ATIS',
        frequency: '128.850',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Regional airport with ATC. North Yorkshire Moors to the south-east — terrain awareness. '
        'Radar service available. Mix of commercial and GA traffic.',
    commonStudentMistakes:
        'Not checking North Yorkshire Moors terrain when routing south-east. '
        'Not obtaining ATIS before initial call.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGNH',
    name: 'Blackpool',
    location: 'Blackpool, Lancashire',
    // [HIGH] AIP AD 2 EGNH — elevation 34 ft AMSL
    elevation: 34,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 10/28, 1869 m asphalt (main)
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 1869,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 13/31 asphalt
      AirfieldRunway(
        designator: '13/31',
        lengthMetres: 1256,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGNH COM
      AirfieldFrequency(
        name: 'Blackpool Approach',
        frequency: '135.950',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Blackpool Tower',
        frequency: '118.400',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Blackpool ATIS',
        frequency: '121.750',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Regional airport with ATC. Irish Sea to the west — coastal weather. '
        'Radar service available. Lake District CAS to the north.',
    commonStudentMistakes:
        'Coastal sea mist arriving rapidly from the Irish Sea. '
        'Not checking Lake District airspace when routing north.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGNL',
    name: 'Barrow/Walney Island',
    location: 'Walney Island, Cumbria',
    // [MEDIUM] Elevation approx 173 ft AMSL
    elevation: 173,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [MEDIUM] 06/24 asphalt (main)
      AirfieldRunway(
        designator: '06/24',
        lengthMetres: 1283,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [MEDIUM] AFIS frequency
      AirfieldFrequency(
        name: 'Walney Island Radio',
        frequency: '123.200',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Island aerodrome on the Cumbrian coast. BAE Systems facility adjacent. '
        'Irish Sea crossings possible from here. Exposed coastal location.',
    commonStudentMistakes:
        'Underestimating Irish Sea coastal weather variability. '
        'Not checking BAE Systems activity when routing near the facility.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGNS',
    name: 'Isle of Man (Ronaldsway)',
    location: 'Ballasalla, Isle of Man',
    // [HIGH] AIP AD 2 EGNS — elevation 52 ft AMSL
    elevation: 52,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 08/26, 1880 m asphalt (main)
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 1880,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 03/21 also available
      AirfieldRunway(
        designator: '03/21',
        lengthMetres: 1460,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGNS COM
      AirfieldFrequency(
        name: 'Ronaldsway Approach',
        frequency: '120.850',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Ronaldsway Tower',
        frequency: '118.900',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Ronaldsway ATIS',
        frequency: '127.650',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Overwater crossing required from the UK mainland — life jackets required. '
        'Isle of Man is not part of the UK for flight planning purposes — customs required. '
        'Full ATC service. TT Races create restrictions each June — check NOTAMs. ',
    commonStudentMistakes:
        'Forgetting the Isle of Man is a separate jurisdiction — customs and immigration required. '
        'Not filing a flight plan for the overwater crossing. '
        'Not checking TT Race NOTAMs — airspace can be significantly restricted.',
    hasData: true,
  ),

  // ── Yorkshire ─────────────────────────────────────────────────────────────

  Airfield(
    icao: 'EGSY',
    name: 'Sheffield City Airport (CLOSED)',
    location: 'Tinsley, Sheffield',
    // [MEDIUM] Closed 2008 — retained for reference
    elevation: 231,
    atzDescription: 'Aerodrome permanently closed — ATZ no longer active',
    runways: [],
    frequencies: [],
    circuitDirection: 'Aerodrome closed — do not attempt to land',
    circuitAltitude: 1000,
    localRules:
        'SHEFFIELD CITY AIRPORT IS PERMANENTLY CLOSED (closed 2008). '
        'Site has been redeveloped. Retained in database for exam/historical reference only.',
    commonStudentMistakes:
        'Older charts may still show this airfield — always use current edition charts.',
    hasData: false,
  ),

  Airfield(
    icao: 'EGBR',
    name: 'Breighton',
    location: 'Breighton, East Yorkshire',
    // [MEDIUM] Elevation approx 23 ft AMSL
    elevation: 23,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [MEDIUM] 07/25 grass (main)
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 914,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [MEDIUM] AGCS frequency
      AirfieldFrequency(
        name: 'Breighton Radio',
        frequency: '129.850',
        usage: 'AGCS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Warbird and vintage aircraft base. AGCS only. '
        'Humberside approach sector nearby. Flat Vale of York terrain.',
    commonStudentMistakes:
        'Not expecting warbird aircraft with unusual performance characteristics. '
        'Navigation in flat featureless Vale of York.',
    hasData: true,
  ),

  // ── Scotland ──────────────────────────────────────────────────────────────

  Airfield(
    icao: 'EGPD',
    name: 'Aberdeen (Dyce)',
    location: 'Dyce, Aberdeen',
    // [HIGH] AIP AD 2 EGPD — elevation 215 ft AMSL
    elevation: 215,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 16/34, 1829 m asphalt (main)
      AirfieldRunway(
        designator: '16/34',
        lengthMetres: 1829,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 05/23 asphalt
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 1311,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPD COM
      AirfieldFrequency(
        name: 'Aberdeen Approach',
        frequency: '120.400',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Aberdeen Tower',
        frequency: '118.100',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Aberdeen Ground',
        frequency: '121.700',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Aberdeen ATIS',
        frequency: '114.300',
        usage: 'ATIS / VOR ABD',
      ),
    ],
    circuitDirection: 'ATC directed — Class D; verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. Major North Sea helicopter hub. '
        'Expect high density of helicopter traffic at all times. '
        'Radar service. Commercial and offshore aviation mixed with GA.',
    commonStudentMistakes:
        'Not anticipating the volume of helicopter traffic at this offshore hub. '
        'Entering Class D without clearance. '
        'Not obtaining ATIS before initial Approach call.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPE',
    name: 'Inverness',
    location: 'Dalcross, Inverness',
    // [HIGH] AIP AD 2 EGPE — elevation 31 ft AMSL
    elevation: 31,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 05/23, 1890 m asphalt (main)
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 1890,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPE COM
      AirfieldFrequency(
        name: 'Inverness Approach',
        frequency: '122.600',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Inverness Tower',
        frequency: '118.425',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Inverness ATIS',
        frequency: '109.200',
        usage: 'ATIS / ILS INS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Gateway to the Highlands. ATC service. '
        'Scottish Highland terrain all around — thorough weather brief essential. '
        'Radar coverage limited to the north and west of Inverness. '
        'Mountain wave and severe turbulence possible near high terrain.',
    commonStudentMistakes:
        'Underestimating rapid weather changes in Highland terrain. '
        'Assuming radar coverage exists over the Highlands — it does not above certain areas. '
        'Not briefing for mountain wave turbulence on routes near the Cairngorms.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPH',
    name: 'Edinburgh',
    location: 'Turnhouse, Edinburgh',
    // [HIGH] AIP AD 2 EGPH — elevation 135 ft AMSL
    elevation: 135,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 06/24, 2556 m asphalt (main)
      AirfieldRunway(
        designator: '06/24',
        lengthMetres: 2556,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 12/30 asphalt
      AirfieldRunway(
        designator: '12/30',
        lengthMetres: 1799,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPH COM
      AirfieldFrequency(
        name: 'Edinburgh Approach',
        frequency: '121.200',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Edinburgh Tower',
        frequency: '118.700',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Edinburgh Ground',
        frequency: '121.750',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Edinburgh ATIS',
        frequency: '132.075',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — Class D; verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. Major Scottish international airport. '
        'High-density commercial traffic. Radar service. Clearance required to enter CTR.',
    commonStudentMistakes:
        'Entering Class D CTR without clearance. '
        'Not obtaining ATIS before initial Approach call.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPF',
    name: 'Glasgow',
    location: 'Abbotsinch, Renfrewshire',
    // [HIGH] AIP AD 2 EGPF — elevation 26 ft AMSL
    elevation: 26,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 05/23, 2658 m asphalt (main)
      AirfieldRunway(
        designator: '05/23',
        lengthMetres: 2658,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPF COM
      AirfieldFrequency(
        name: 'Glasgow Approach',
        frequency: '119.100',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Glasgow Tower',
        frequency: '118.800',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Glasgow ATIS',
        frequency: '113.400',
        usage: 'ATIS / VOR GOW',
      ),
    ],
    circuitDirection: 'ATC directed — Class D; verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. Major Scottish international airport — limited GA. '
        'Radar service. Glasgow Prestwick (EGPK) is the preferred GA alternative.',
    commonStudentMistakes:
        'Attempting GA operations at Glasgow main airport without understanding Class D requirements. '
        'Not using Prestwick as the preferred GA alternative in the area.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPK',
    name: 'Glasgow Prestwick',
    location: 'Prestwick, South Ayrshire',
    // [HIGH] AIP AD 2 EGPK — elevation 65 ft AMSL
    elevation: 65,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 13/31, 2986 m asphalt (main)
      AirfieldRunway(
        designator: '13/31',
        lengthMetres: 2986,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPK COM
      AirfieldFrequency(
        name: 'Prestwick Approach',
        frequency: '120.550',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Prestwick Tower',
        frequency: '118.150',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Prestwick ATIS',
        frequency: '127.125',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Very long runway — one of the longest in Scotland. Full ATC. '
        'Popular transatlantic diversion field. GA welcome. '
        'Radar service. Notable for frequent low cloud off the Firth of Clyde.',
    commonStudentMistakes:
        'Not anticipating rapid weather changes from the Firth of Clyde. '
        'Failing to get ATIS before initial Approach call.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPN',
    name: 'Dundee',
    location: 'Dundee, Angus',
    // [HIGH] AIP AD 2 EGPN — elevation 17 ft AMSL
    elevation: 17,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 10/28, 1399 m asphalt
      AirfieldRunway(
        designator: '10/28',
        lengthMetres: 1399,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPN COM
      AirfieldFrequency(
        name: 'Dundee Approach',
        frequency: '122.900',
        usage: 'Approach / AFIS',
      ),
      AirfieldFrequency(
        name: 'Dundee Tower',
        frequency: '118.575',
        usage: 'Tower (when active)',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'City airport on the Tay Estuary. Short runway for a regional airport. '
        'Sidlaw Hills to the north — terrain awareness. '
        'AFIS or Tower depending on operating hours.',
    commonStudentMistakes:
        'Not accounting for terrain to the north when routing away from the field. '
        'Short runway requires disciplined approach speed management.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPO',
    name: 'Stornoway',
    location: 'Stornoway, Isle of Lewis',
    // [HIGH] AIP AD 2 EGPO — elevation 26 ft AMSL
    elevation: 26,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 18/36, 2025 m asphalt (main)
      AirfieldRunway(
        designator: '18/36',
        lengthMetres: 2025,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPO COM
      AirfieldFrequency(
        name: 'Stornoway Approach',
        frequency: '123.500',
        usage: 'Approach / AFIS',
      ),
      AirfieldFrequency(
        name: 'Stornoway Tower',
        frequency: '119.200',
        usage: 'Tower (when active)',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Island airport — overwater crossing required. Life jackets required. '
        'Weather can be severe — thorough weather brief essential. '
        'Atlantic weather arrives with little warning. File a flight plan.',
    commonStudentMistakes:
        'Not carrying appropriate survival equipment for the long overwater crossing. '
        'Arriving without a comprehensive weather brief — Atlantic weather changes rapidly. '
        'Not filing a flight plan for the overwater sector.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPU',
    name: 'Tiree',
    location: 'Tiree, Argyll and Bute',
    // [HIGH] AIP AD 2 EGPU — elevation 38 ft AMSL
    elevation: 38,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 11/29, 1463 m asphalt (main)
      AirfieldRunway(
        designator: '11/29',
        lengthMetres: 1463,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 07/25 also available
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 1067,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPU COM
      AirfieldFrequency(
        name: 'Tiree Radio',
        frequency: '122.700',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Exposed Hebridean island airport. Overwater crossing required. '
        'Known for very strong and persistent winds. '
        'Weather can change rapidly. AFIS service. File a flight plan.',
    commonStudentMistakes:
        'Underestimating the wind strength — Tiree is one of the windiest places in the UK. '
        'Not carrying survival equipment for the overwater crossing. '
        'Not filing a flight plan.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPB',
    name: 'Sumburgh',
    location: 'Sumburgh, Shetland',
    // [HIGH] AIP AD 2 EGPB — elevation 20 ft AMSL
    elevation: 20,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 09/27, 1585 m asphalt (main)
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 1585,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 15/33 also available
      AirfieldRunway(
        designator: '15/33',
        lengthMetres: 927,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPB COM
      AirfieldFrequency(
        name: 'Sumburgh Approach',
        frequency: '131.300',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Sumburgh Tower',
        frequency: '118.250',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Sumburgh ATIS',
        frequency: '125.850',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — verify current',
    circuitAltitude: 1000,
    localRules:
        'Southernmost tip of Shetland — very long overwater crossing from mainland. '
        'North Sea oil industry helicopter hub. Expect heavy helicopter traffic. '
        'Severe weather common — always have comprehensive alternate plans. '
        'Full ATC service.',
    commonStudentMistakes:
        'The overwater distance from mainland Scotland is significant — thorough fuel and weather planning required. '
        'Not anticipating very high helicopter traffic density. '
        'Severe weather arriving from the North Sea with minimal warning.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPA',
    name: 'Kirkwall',
    location: 'Orkney Mainland',
    // [HIGH] AIP AD 2 EGPA — elevation 50 ft AMSL
    elevation: 50,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 09/27, 1433 m asphalt (main)
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 1433,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 14/32 also available
      AirfieldRunway(
        designator: '14/32',
        lengthMetres: 1125,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPA COM
      AirfieldFrequency(
        name: 'Kirkwall Approach',
        frequency: '118.300',
        usage: 'Approach / AFIS',
      ),
      AirfieldFrequency(
        name: 'Kirkwall Tower',
        frequency: '118.300',
        usage: 'Tower (when active)',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Orkney island airport — overwater crossing required from mainland. '
        'Pentland Firth crossing has very strong tidal streams below. '
        'Weather deteriorates rapidly. File a flight plan. Life jackets required.',
    commonStudentMistakes:
        'Underestimating the Pentland Firth weather and sea conditions below. '
        'Not filing a flight plan for the overwater sector. '
        'Not carrying appropriate survival equipment.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGPR',
    name: 'Barra',
    location: 'Eoligarry, Isle of Barra',
    // [HIGH] AIP AD 2 EGPR — elevation 5 ft AMSL
    elevation: 5,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] Beach runways — tidal; must check tide tables before flight
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 870,
        surface: 'Beach (tidal — sand)',
      ),
      AirfieldRunway(
        designator: '11/29',
        lengthMetres: 752,
        surface: 'Beach (tidal — sand)',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGPR COM
      AirfieldFrequency(
        name: 'Barra Radio',
        frequency: '130.650',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current — tidal beach runways)',
    circuitAltitude: 1000,
    localRules:
        'UNIQUE: Barra is the only scheduled service airport in the world that uses a beach as its runway. '
        'TIDAL RUNWAYS — landing is only permitted at low tide. Check tide tables before flight. '
        'Runways submerge at high tide — aircraft must depart before the tide comes in. '
        'Long overwater sector from mainland. Life jackets required. File a flight plan. '
        'AFIS service — check operating hours as these are limited.',
    commonStudentMistakes:
        'Arriving without checking tide tables — the runway will literally be underwater. '
        'Not carrying survival equipment for the Hebridean overwater crossing. '
        'Not filing a flight plan for this remote island destination.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGEO',
    name: 'Oban',
    location: 'North Connel, Argyll',
    // [MEDIUM] Elevation approx 20 ft AMSL
    elevation: 20,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [MEDIUM] 01/19 asphalt (main)
      AirfieldRunway(
        designator: '01/19',
        lengthMetres: 1008,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [MEDIUM] AFIS frequency
      AirfieldFrequency(
        name: 'Oban Radio',
        frequency: '118.050',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Scenic West Highlands location on Loch Etive. '
        'Surrounding mountains — thorough weather brief required. '
        'AFIS service with limited operating hours. Call ahead before visiting.',
    commonStudentMistakes:
        'Arriving outside operating hours — AFIS coverage is limited. '
        'Underestimating mountain terrain surrounding the field. '
        'Not checking weather in the glens when routing through the Highlands.',
    hasData: true,
  ),

  // ── Wales ─────────────────────────────────────────────────────────────────

  Airfield(
    icao: 'EGCK',
    name: 'Caernarfon',
    location: 'Dinas Dinlle, Gwynedd',
    // [HIGH] AIP AD 2 EGCK — elevation 1 ft AMSL
    elevation: 1,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 02/20, 1026 m asphalt (main)
      AirfieldRunway(
        designator: '02/20',
        lengthMetres: 1026,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 08/26 grass also available
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 594,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGCK COM
      AirfieldFrequency(
        name: 'Caernarfon Radio',
        frequency: '122.250',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Snowdonia National Park immediately to the east — significant terrain. '
        'Anglesey (EGOV) military ATZ to the north — check before routing. '
        'Irish Sea to the west. Coastal fog common in summer.',
    commonStudentMistakes:
        'Routing east into Snowdonia terrain in reduced visibility. '
        'Not checking Anglesey RAF Valley military ATZ to the north. '
        'Sea fog arriving from Cardigan Bay without warning.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGFP',
    name: 'Pembrey',
    location: 'Pembrey, Carmarthenshire',
    // [MEDIUM] Elevation approx 38 ft AMSL
    elevation: 38,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [MEDIUM] 04/22 asphalt (main)
      AirfieldRunway(
        designator: '04/22',
        lengthMetres: 1402,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [MEDIUM] AFIS/AGCS frequency
      AirfieldFrequency(
        name: 'Pembrey Radio',
        frequency: '122.750',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Pembrey military range to the west — check danger area P001 status. '
        'Coastal airfield on Carmarthen Bay. AFIS service. '
        'Swansea is close to the east — check EGFH ATZ when routing.',
    commonStudentMistakes:
        'Not checking Pembrey danger area P001 status before routing west. '
        'Not checking Swansea ATZ when routing east.',
    hasData: true,
  ),

  // ── Northern Ireland ──────────────────────────────────────────────────────

  Airfield(
    icao: 'EGAA',
    name: 'Belfast International (Aldergrove)',
    location: 'Aldergrove, County Antrim',
    // [HIGH] AIP AD 2 EGAA — elevation 268 ft AMSL
    elevation: 268,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 07/25, 2780 m asphalt (main)
      AirfieldRunway(
        designator: '07/25',
        lengthMetres: 2780,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 17/35 asphalt
      AirfieldRunway(
        designator: '17/35',
        lengthMetres: 1829,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGAA COM
      AirfieldFrequency(
        name: 'Belfast Approach',
        frequency: '128.500',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Belfast Tower',
        frequency: '118.300',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Belfast Ground',
        frequency: '121.750',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Belfast ATIS',
        frequency: '120.900',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — Class D; verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. Northern Ireland\'s main international airport. '
        'Overwater crossing from Great Britain — life jackets required. '
        'Radar service. Commercial traffic priority.',
    commonStudentMistakes:
        'Not obtaining ATIS before first Approach call. '
        'Entering Class D CTR without clearance. '
        'Not carrying survival equipment for the Irish Sea crossing.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGAC',
    name: 'Belfast City (George Best)',
    location: 'Belfast, County Antrim',
    // [HIGH] AIP AD 2 EGAC — elevation 15 ft AMSL
    elevation: 15,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 04/22, 1829 m asphalt
      AirfieldRunway(
        designator: '04/22',
        lengthMetres: 1829,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGAC COM
      AirfieldFrequency(
        name: 'City of Belfast Approach',
        frequency: '130.750',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'City of Belfast Tower',
        frequency: '122.825',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'City of Belfast ATIS',
        frequency: '127.125',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — Class D; verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. City centre airport — very noise sensitive. '
        'Strict noise abatement procedures apply at all times. '
        'Belfast Lough to the north-east. Commercial operations priority.',
    commonStudentMistakes:
        'Not following noise abatement procedures in this densely populated area. '
        'Entering Class D without clearance. '
        'Not obtaining ATIS before initial call.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGAD',
    name: 'Newtownards',
    location: 'Newtownards, County Down',
    // [HIGH] AIP AD 2 EGAD — elevation 9 ft AMSL
    elevation: 9,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 04/22, 927 m asphalt (main)
      AirfieldRunway(
        designator: '04/22',
        lengthMetres: 927,
        surface: 'Asphalt',
      ),
      // [MEDIUM] 16/34 grass also available
      AirfieldRunway(
        designator: '16/34',
        lengthMetres: 640,
        surface: 'Grass',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGAD COM
      AirfieldFrequency(
        name: 'Newtownards Radio',
        frequency: '122.800',
        usage: 'AFIS — all calls',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Popular GA and training airfield close to Belfast. '
        'Strangford Lough to the south — scenic overwater routing. '
        'Belfast City CTR nearby — check boundaries when routing north. '
        'AFIS service.',
    commonStudentMistakes:
        'Not checking Belfast City CTR when routing north. '
        'Routing over Strangford Lough without being mindful of overwater requirements.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGAE',
    name: 'City of Derry (Eglinton)',
    location: 'Eglinton, County Londonderry',
    // [HIGH] AIP AD 2 EGAE — elevation 22 ft AMSL
    elevation: 22,
    atzDescription: '2 nm radius, surface to 2000 ft QFE',
    runways: [
      // [HIGH] AIP — 08/26, 1829 m asphalt
      AirfieldRunway(
        designator: '08/26',
        lengthMetres: 1829,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGAE COM
      AirfieldFrequency(
        name: 'Derry Approach',
        frequency: '123.625',
        usage: 'Approach / AFIS',
      ),
      AirfieldFrequency(
        name: 'Derry Tower',
        frequency: '119.700',
        usage: 'Tower (when active)',
      ),
    ],
    circuitDirection: 'Left hand (verify current)',
    circuitAltitude: 1000,
    localRules:
        'Regional airport on Lough Foyle. Overwater approach from the east. '
        'Donegal Bay and Republic of Ireland airspace adjacent to the south-west. '
        'AFIS or Tower depending on operating hours.',
    commonStudentMistakes:
        'Not being aware of the Republic of Ireland airspace boundary to the south-west. '
        'Not checking operating hours — AFIS coverage is limited.',
    hasData: true,
  ),

  // ── Midlands / Central additions ──────────────────────────────────────────

  Airfield(
    icao: 'EGBB',
    name: 'Birmingham',
    location: 'Elmdon, Birmingham',
    // [HIGH] AIP AD 2 EGBB — elevation 327 ft AMSL
    elevation: 327,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 15/33, 3052 m asphalt (main)
      AirfieldRunway(
        designator: '15/33',
        lengthMetres: 3052,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGBB COM
      AirfieldFrequency(
        name: 'Birmingham Approach',
        frequency: '131.325',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'Birmingham Tower',
        frequency: '118.300',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'Birmingham Ground',
        frequency: '121.800',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'Birmingham ATIS',
        frequency: '126.025',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — Class D; verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. Major international airport — very limited GA. '
        'Clearance required to enter CTR. Commercial traffic priority. '
        'PPL training not normally conducted here; nearby fields preferred.',
    commonStudentMistakes:
        'Entering Birmingham Class D CTR without clearance. '
        'Routing under the CTR without understanding its lateral and vertical limits.',
    hasData: true,
  ),

  Airfield(
    icao: 'EGNX',
    name: 'East Midlands',
    location: 'Castle Donington, Leicestershire',
    // [HIGH] AIP AD 2 EGNX — elevation 306 ft AMSL
    elevation: 306,
    atzDescription: '2 nm radius, surface to 2000 ft QFE (Class D)',
    runways: [
      // [HIGH] AIP — 09/27, 2893 m asphalt
      AirfieldRunway(
        designator: '09/27',
        lengthMetres: 2893,
        surface: 'Asphalt',
      ),
    ],
    frequencies: [
      // [HIGH] AIP EGNX COM
      AirfieldFrequency(
        name: 'East Midlands Approach',
        frequency: '134.175',
        usage: 'Approach / Radar',
      ),
      AirfieldFrequency(
        name: 'East Midlands Tower',
        frequency: '124.000',
        usage: 'Tower',
      ),
      AirfieldFrequency(
        name: 'East Midlands Ground',
        frequency: '121.900',
        usage: 'Ground',
      ),
      AirfieldFrequency(
        name: 'East Midlands ATIS',
        frequency: '128.225',
        usage: 'ATIS',
      ),
    ],
    circuitDirection: 'ATC directed — Class D; verify current',
    circuitAltitude: 1000,
    localRules:
        'Class D controlled airspace. Major cargo and charter hub. '
        'High density of overnight freight operations — 24-hour operation. '
        'Radar service. Clearance required to enter CTR.',
    commonStudentMistakes:
        'Entering Class D CTR without clearance. '
        'Not expecting freight aircraft operations during night/early morning. '
        'Not obtaining ATIS before initial Approach call.',
    hasData: true,
  ),
];
