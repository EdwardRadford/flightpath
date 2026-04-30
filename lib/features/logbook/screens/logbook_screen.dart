// Logbook screen — now redirects to the combined LogbookProgressScreen.
// Kept for backward compatibility with existing imports.
export 'logbook_progress_screen.dart' show LogbookProgressScreen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logbook_progress_screen.dart';

/// Legacy alias — routes and imports that reference [LogbookScreen] will
/// transparently use the combined [LogbookProgressScreen].
class LogbookScreen extends ConsumerWidget {
  final String? initialExerciseId;

  const LogbookScreen({super.key, this.initialExerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LogbookProgressScreen(initialExerciseId: initialExerciseId);
  }
}
