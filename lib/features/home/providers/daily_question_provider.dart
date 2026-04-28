// Daily question provider — picks a question from the user's weakest exercise.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/models/quiz_question.dart';
import 'package:flight_path/shared/models/user_exercise.dart';

// ---------------------------------------------------------------------------
// Keys used in SharedPreferences
// ---------------------------------------------------------------------------

const String _kDailyQuestionDate = 'daily_question_date';
const String _kDailyQuestionAnswered = 'daily_question_answered';

// ---------------------------------------------------------------------------
// Date seed helper
// ---------------------------------------------------------------------------

String _todaySeed() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

// ---------------------------------------------------------------------------
// Weakest exercise picker
// ---------------------------------------------------------------------------

/// Given the user's exercise progress records, returns the composite exercise
/// ID that most needs attention, or 'ex_01' as a fallback for new users.
///
/// Priority:
///   1. Exercises never attempted (quizAttempted == false) — pick the first
///      one in syllabus order.
///   2. Among attempted exercises, pick the one with the lowest bestRating
///      (treating null as 0).  Ties broken by syllabus order.
String _weakestExerciseId(List<UserExercise> exercises) {
  final progressById = <String, UserExercise>{};
  for (final ue in exercises) {
    final id = (ue.subExercise != null && ue.subExercise!.isNotEmpty)
        ? '${ue.exerciseId}_${ue.subExercise}'
        : ue.exerciseId;
    progressById[id] = ue;
  }

  // Phase 1 — first untouched exercise in syllabus order.
  for (final id in AppConstants.allExerciseIds) {
    final ue = progressById[id];
    if (ue == null || !ue.quizAttempted) return id;
  }

  // Phase 2 — lowest bestRating among attempted exercises.
  String? weakest;
  int lowestRating = 101;
  for (final id in AppConstants.allExerciseIds) {
    final ue = progressById[id];
    if (ue == null) continue;
    final rating = ue.bestRating ?? 0;
    if (rating < lowestRating) {
      lowestRating = rating;
      weakest = id;
    }
  }

  return weakest ?? AppConstants.allExerciseIds.first;
}

// ---------------------------------------------------------------------------
// Daily question state
// ---------------------------------------------------------------------------

class DailyQuestionState {
  final QuizQuestion? question;
  final bool answered;
  final bool loading;
  final String? error;
  final String? sourceExerciseId;
  final String? sourceExerciseName;

  const DailyQuestionState({
    this.question,
    this.answered = false,
    this.loading = true,
    this.error,
    this.sourceExerciseId,
    this.sourceExerciseName,
  });

  DailyQuestionState copyWith({
    QuizQuestion? question,
    bool? answered,
    bool? loading,
    String? error,
    String? sourceExerciseId,
    String? sourceExerciseName,
  }) {
    return DailyQuestionState(
      question: question ?? this.question,
      answered: answered ?? this.answered,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      sourceExerciseId: sourceExerciseId ?? this.sourceExerciseId,
      sourceExerciseName: sourceExerciseName ?? this.sourceExerciseName,
    );
  }
}

// ---------------------------------------------------------------------------
// Daily question notifier
// ---------------------------------------------------------------------------

class DailyQuestionNotifier extends StateNotifier<DailyQuestionState> {
  DailyQuestionNotifier(this._ref) : super(const DailyQuestionState()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final seed = _todaySeed();
      final prefs = await SharedPreferences.getInstance();

      final storedDate = prefs.getString(_kDailyQuestionDate);
      final answeredToday =
          storedDate == seed && (prefs.getBool(_kDailyQuestionAnswered) ?? false);

      // Resolve weakest exercise from current user progress.
      final uid = _ref.read(currentUserIdProvider);
      List<UserExercise> exercises = [];
      if (uid != null) {
        final firestore = _ref.read(firestoreServiceProvider);
        exercises = await firestore.exercisesCollection(uid).get().then((qs) {
          final items = <UserExercise>[];
          for (final doc in qs.docs) {
            try {
              items.add(UserExercise.fromFirestore(doc));
            } catch (_) {
              debugPrint('daily_question_provider: $_');
            }
          }
          return items;
        });
      }

      final exerciseId = _weakestExerciseId(exercises);
      final exerciseName = AppConstants.exerciseNames[exerciseId] ?? exerciseId;

      // Parse composite ID into base + sub.
      String baseId;
      String? subId;
      final parts = exerciseId.split('_');
      if (parts.length >= 3) {
        baseId = '${parts[0]}_${parts[1]}';
        subId = parts.sublist(2).join('_');
      } else {
        baseId = exerciseId;
        subId = null;
      }

      final firestore = _ref.read(firestoreServiceProvider);
      final questions = await firestore.getQuizQuestions(
        baseId,
        subExerciseId: subId,
      );

      if (questions.isEmpty) {
        state = DailyQuestionState(
          loading: false,
          error: 'no_questions',
          sourceExerciseId: exerciseId,
          sourceExerciseName: exerciseName,
        );
        return;
      }

      // Pick a deterministic question for the day using a seed hash,
      // falling back to random if the list is shorter than expected.
      final index = seed.hashCode.abs() % questions.length;
      final question = questions[index];

      state = DailyQuestionState(
        question: question,
        answered: answeredToday,
        loading: false,
        sourceExerciseId: exerciseId,
        sourceExerciseName: exerciseName,
      );
    } catch (e) {
      state = DailyQuestionState(
        loading: false,
        error: e.toString(),
      );
    }
  }

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
