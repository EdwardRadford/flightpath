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
      'Fixed quiz questions showing A/B instead of True/False',
      'Fixed instructor home screen briefly showing student view',
      'Fixed instructor invite code input getting stuck loading',
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
      'Interactive quizzes and flashcards for every exercise',
      'Digital pilot logbook',
      'AI-powered post-lesson debriefs',
      'Instructor dashboard with student progress tracking',
      'Light and dark theme support',
    ],
  ),
];
