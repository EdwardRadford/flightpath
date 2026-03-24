// Revision providers — fetches all quiz questions across exercises and applies
// weakness-based weighting for cross-exercise revision mode.
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/shared/models/quiz_question.dart';
import 'package:flight_path/shared/models/lesson.dart';

final _db = FirebaseFirestore.instance;

// ---------------------------------------------------------------------------
// All quiz questions (one-shot fetch)
// ---------------------------------------------------------------------------

/// Fetches all quiz questions from Firestore.
final allQuizQuestionsProvider =
    FutureProvider<List<QuizQuestion>>((ref) async {
  final snapshot = await _db.collection('quiz_questions').get();
  return snapshot.docs
      .map((doc) => QuizQuestion.fromFirestore(doc))
      .toList();
});

// ---------------------------------------------------------------------------
// Per-exercise quiz score stats (derived from lessons)
// ---------------------------------------------------------------------------

/// Returns a map of exerciseId -> list of quiz scores from completed lessons.
final exerciseQuizScoresProvider =
    FutureProvider<Map<String, List<int>>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return {};

  final snapshot = await _db
      .collection('lessons')
      .where('user_id', isEqualTo: uid)
      .where('status', isEqualTo: 'completed')
      .get();

  final scores = <String, List<int>>{};
  for (final doc in snapshot.docs) {
    final lesson = Lesson.fromFirestore(doc);
    if (lesson.quizScore != null) {
      final key = lesson.exerciseId;
      scores.putIfAbsent(key, () => []).add(lesson.quizScore!);
    }
  }
  return scores;
});

// ---------------------------------------------------------------------------
// Weighted question selection
// ---------------------------------------------------------------------------

/// Holds a question with its computed weight for selection.
class WeightedQuestion {
  final QuizQuestion question;
  final double weight;

  const WeightedQuestion({required this.question, required this.weight});
}

/// Selects [count] questions using weighted random sampling based on weakness.
///
/// Weighting rules:
/// - Questions from exercises with lower average scores: 2x
/// - Questions never attempted: 1.5x
/// - Recently mastered (avg > 80%): 0.5x
/// - Base weight: 1.0x
///
/// The [incorrectQuestionIds] set gives 3x weight to previously wrong answers.
List<QuizQuestion> selectWeightedQuestions({
  required List<QuizQuestion> allQuestions,
  required Map<String, List<int>> exerciseScores,
  required Set<String> incorrectQuestionIds,
  required int count,
}) {
  if (allQuestions.isEmpty) return [];

  final random = Random();
  final weighted = <WeightedQuestion>[];

  for (final q in allQuestions) {
    double weight = 1.0;

    // Weight by exercise performance
    final scores = exerciseScores[q.exerciseId];
    if (scores == null || scores.isEmpty) {
      // Never attempted this exercise
      weight *= 1.5;
    } else {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      if (avg < 60) {
        weight *= 2.0; // Low performance
      } else if (avg > 80) {
        weight *= 0.5; // Recently mastered
      }
    }

    // Weight by individual question history
    if (incorrectQuestionIds.contains(q.id)) {
      weight *= 3.0;
    }

    weighted.add(WeightedQuestion(question: q, weight: weight));
  }

  // Weighted random selection without replacement
  final selected = <QuizQuestion>[];
  final remaining = List<WeightedQuestion>.from(weighted);

  final target = min(count, remaining.length);
  for (var i = 0; i < target; i++) {
    final totalWeight =
        remaining.fold(0.0, (acc, wq) => acc + wq.weight);
    var pick = random.nextDouble() * totalWeight;

    WeightedQuestion? chosen;
    for (final wq in remaining) {
      pick -= wq.weight;
      if (pick <= 0) {
        chosen = wq;
        break;
      }
    }
    chosen ??= remaining.last;

    selected.add(chosen.question);
    remaining.remove(chosen);
  }

  return selected;
}
