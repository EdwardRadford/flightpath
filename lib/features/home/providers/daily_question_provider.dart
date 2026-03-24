// Daily question provider — fetches a deterministic quiz question per day
// and tracks whether the user has already revealed the answer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/quiz_question.dart';

// ---------------------------------------------------------------------------
// Keys used in SharedPreferences
// ---------------------------------------------------------------------------

const String _kDailyQuestionDate = 'daily_question_date';
const String _kDailyQuestionAnswered = 'daily_question_answered';

// ---------------------------------------------------------------------------
// Date seed helper
// ---------------------------------------------------------------------------

/// Returns today's date as a canonical string, e.g. "2026-03-22".
String _todaySeed() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

// ---------------------------------------------------------------------------
// Daily question state
// ---------------------------------------------------------------------------

/// Holds the question for today plus whether the user has already revealed it.
/// Immutable state for the daily question widget.
class DailyQuestionState {
  final QuizQuestion? question;
  final bool answered;
  final bool loading;
  final String? error;

  const DailyQuestionState({
    this.question,
    this.answered = false,
    this.loading = true,
    this.error,
  });

  DailyQuestionState copyWith({
    QuizQuestion? question,
    bool? answered,
    bool? loading,
    String? error,
  }) {
    return DailyQuestionState(
      question: question ?? this.question,
      answered: answered ?? this.answered,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Daily question notifier
// ---------------------------------------------------------------------------

/// Loads the daily question from Firestore and persists answer state locally.
class DailyQuestionNotifier extends StateNotifier<DailyQuestionState> {
  DailyQuestionNotifier(this._ref) : super(const DailyQuestionState()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final seed = _todaySeed();
      final prefs = await SharedPreferences.getInstance();

      // Check if the stored date matches today — if not, reset.
      final storedDate = prefs.getString(_kDailyQuestionDate);
      final answeredToday =
          storedDate == seed && (prefs.getBool(_kDailyQuestionAnswered) ?? false);

      // Fetch the question from Firestore.
      final firestore = _ref.read(firestoreServiceProvider);
      final question = await firestore.getDailyQuestion(seed);

      state = DailyQuestionState(
        question: question,
        answered: answeredToday,
        loading: false,
      );
    } catch (e) {
      state = DailyQuestionState(
        loading: false,
        error: e.toString(),
      );
    }
  }

  /// Call when the user reveals the answer.
  Future<void> markAnswered() async {
    final seed = _todaySeed();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDailyQuestionDate, seed);
    await prefs.setBool(_kDailyQuestionAnswered, true);
    state = state.copyWith(answered: true);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final dailyQuestionProvider =
    StateNotifierProvider<DailyQuestionNotifier, DailyQuestionState>(
  (ref) => DailyQuestionNotifier(ref),
);
