// Debrief feature providers — edit mode holder and AI debrief state.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/models/lesson.dart';

// ---------------------------------------------------------------------------
// Edit mode — holds the lesson being edited (null = create mode)
// ---------------------------------------------------------------------------

/// Holds the [Lesson] that the debrief screen is editing.
/// Set before navigating to the debrief/edit route; cleared on pop.
final editingLessonProvider = StateProvider<Lesson?>((ref) => null);

// ---------------------------------------------------------------------------
// AI debrief state
// ---------------------------------------------------------------------------

/// Possible states for an in-progress AI debrief call.
enum AiDebriefStatus { idle, loading, success, error }

class AiDebriefState {
  final AiDebriefStatus status;
  final String? well;
  final String? improve;
  final String? focus;
  final String? errorMessage;

  const AiDebriefState({
    this.status = AiDebriefStatus.idle,
    this.well,
    this.improve,
    this.focus,
    this.errorMessage,
  });

  AiDebriefState copyWith({
    AiDebriefStatus? status,
    String? well,
    String? improve,
    String? focus,
    String? errorMessage,
  }) {
    return AiDebriefState(
      status: status ?? this.status,
      well: well ?? this.well,
      improve: improve ?? this.improve,
      focus: focus ?? this.focus,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Tracks the state of the AI debrief Cloud Function call within a debrief session.
final aiDebriefStateProvider =
    StateProvider.autoDispose<AiDebriefState>((ref) => const AiDebriefState());
