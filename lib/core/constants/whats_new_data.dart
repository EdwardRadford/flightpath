// What's New version entries displayed after app updates and in Settings.

/// A single change-log entry for one app version.
class WhatsNewEntry {
  final String version;
  final String date;
  final List<String> changes;

  const WhatsNewEntry({
    required this.version,
    required this.date,
    required this.changes,
  });
}

/// All version entries in reverse chronological order (newest first).
const List<WhatsNewEntry> whatsNewEntries = [
  WhatsNewEntry(
    version: '1.0.6',
    date: 'April 2026',
    changes: [
      'RT Practice — AI-powered ATC roleplay for every scenario in the UK PPL syllabus, including ATIS decoding',
      'METAR Training — decode live weather reports from real UK airfields',
      'QXC Guide — learn to plan your cross-country, step by step',
      'Aircraft Data — performance figures and speed limits for 10 common UK training aircraft',
      'Airfield Info — local procedures, circuits and frequencies for UK training fields (content rolling out)',
      'Hours to Licence — track your progress against CAA PPL minimum requirements',
      'Smarter onboarding — a short quiz now suggests where to start in the syllabus',
    ],
  ),
  WhatsNewEntry(
    version: '1.0.5',
    date: 'April 2026',
    changes: [
      'Fixed hours flown card sizing on home screen',
      'Fixed exercise 18B/18C text overlap in syllabus',
      'Fixed Ask AI connection issues',
      'Fixed logbook retry button',
      'Removed unused code and improved app stability',
    ],
  ),
  WhatsNewEntry(
    version: '1.0.3',
    date: 'March 2026',
    changes: [
      'Fixed Google Sign-In crash on iOS',
      'Fixed logbook not loading after sign-in',
      'Fixed Exercise 18C sub-node appearing off-screen',
      'Improved AI debrief — instructor rating now optional',
      'Fixed share progress screen showing incorrect lesson order',
    ],
  ),
  WhatsNewEntry(
    version: '1.0.0',
    date: 'March 2026',
    changes: [
      'Complete PPL training companion with 19 CAA exercises',
      'Interactive flashcards for every exercise',
      'Digital pilot logbook',
      'AI-powered post-lesson debriefs',
      'Light and dark theme support',
    ],
  ),
];
