// CAP 413 mandatory readback list for UK PPL radiotelephony training.
//
// Source: CAP 413 Radiotelephony Manual, v24 (April 2026), Chapter 3.
// Always verify against the current edition published by the CAA.
//
// This data is for study and reference purposes only.

/// One category section of the mandatory readback reference.
typedef ReadbackSection = ({String category, List<String> items});

/// Complete list of CAP 413 mandatory readback categories and items.
const List<ReadbackSection> kMandatoryReadbacks = [
  (
    category: 'Always read back',
    items: [
      'ATC route clearances',
      'Clearances and instructions to enter, land on, take off from, hold short of, cross, or taxi on any runway',
      'Runway-in-use',
      'Altimeter settings (QNH and QFE)',
      'SSR transponder codes',
      'Level instructions (altitude, flight level, or height to maintain)',
      'Heading instructions',
      'Speed instructions',
      'Transition levels',
      'Frequency changes',
    ],
  ),
  (
    category: 'When in doubt — read it back',
    items: [
      'Taxi instructions (holding point, route, runway)',
      'Traffic information affecting your routing',
      'All holds, approach, or departure clearances',
      'Conditional clearances (e.g. "Behind the landing traffic, line up")',
    ],
  ),
  (
    category: 'Readback format rules',
    items: [
      'Always include your callsign at the end of a readback',
      'Read back numbers digit by digit: "270" → "Two Seven Zero"',
      'Runways: always include the word "runway" — "Runway Two Seven"',
      'Flight levels: "FL" before the digits — "FL 085"',
      'QNH/QFE: state the figure and unit — "QNH One Zero One Three"',
      'SSR codes: four digits individually — "Squawk Three Four Five Six"',
    ],
  ),
  (
    category: 'Common student errors',
    items: [
      'Forgetting the callsign at end of readback',
      'Reading back instructions as questions instead of statements',
      'Omitting the runway number from landing or take-off clearances',
      'Not reading back a heading change — "Turn left heading 270" must be read back',
      'Saying "wilco" instead of reading back a level clearance',
      '"Roger" is NOT a readback — it only means "message received"',
    ],
  ),
];
