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
    version: '1.0.0',
    date: 'March 2026',
    changes: [
      'Complete PPL training companion with 19 CAA exercises',
      'Interactive quizzes and flashcards for every exercise',
      'Weather briefing with METAR decoding and crosswind calculator',
      'Digital pilot logbook',
      'AI-powered post-lesson debriefs',
      'Instructor dashboard with student progress tracking',
      'Light and dark theme support',
    ],
  ),
];
