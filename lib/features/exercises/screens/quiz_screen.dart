// Quiz screen — presents up to 10 shuffled questions with instant feedback
// and saves the score to Firestore. Includes spaced-repetition-style mastery
// tracking: questions answered correctly twice consecutively are considered
// "mastered" and deprioritised in future attempts.
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/quiz_question.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/aviation_widgets.dart';
import 'package:flight_path/shared/widgets/micro_animations.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Interactive quiz with progress tracking and score persistence.
class QuizScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const QuizScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {};
  bool _showResults = false;
  int _score = 0;
  bool _saving = false;
  bool _saved = false;
  bool _loggedStart = false;

  // ── Question mastery tracking ──────────────────────────────────────────
  List<QuizQuestion>? _orderedQuestions;
  Map<String, int>? _cachedMasteryData;

  /// A question is "mastered" when answered correctly 2+ times consecutively.
  static const int _masteryThreshold = 2;

  /// Reorders questions: unmastered first (shuffled), then mastered (shuffled).
  List<QuizQuestion> _prioritiseQuestions(
    List<QuizQuestion> allQuestions,
    Map<String, int> masteryData,
  ) {
    final unmastered = <QuizQuestion>[];
    final mastered = <QuizQuestion>[];

    for (final q in allQuestions) {
      final count = masteryData[q.id] ?? 0;
      if (count >= _masteryThreshold) {
        mastered.add(q);
      } else {
        unmastered.add(q);
      }
    }

    final rng = Random();

    if (unmastered.isEmpty && mastered.isNotEmpty) {
      mastered.shuffle(rng);
      return mastered;
    }

    unmastered.shuffle(rng);
    mastered.shuffle(rng);

    final result = <QuizQuestion>[...unmastered];
    if (result.length < allQuestions.length) {
      result.addAll(mastered);
    }
    return result;
  }

  Map<String, int> _computeUpdatedMastery(
    List<QuizQuestion> questions,
    Map<String, int> existingMastery,
  ) {
    final updated = Map<String, int>.from(existingMastery);
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final isCorrect = _selectedAnswers[i] == q.correctAnswer;
      updated[q.id] = isCorrect ? (updated[q.id] ?? 0) + 1 : 0;
    }
    return updated;
  }

  void _selectAnswer(String answer) {
    if (_showResults) return;
    setState(() {
      _selectedAnswers[_currentIndex] = answer;
    });
  }

  void _next(List<QuizQuestion> questions) {
    if (_currentIndex < questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishQuiz(questions);
    }
  }

  String get _consecutiveFailKey =>
      'quiz_consecutive_fails_${widget.compositeExerciseId}';

  Future<int> _updateConsecutiveFailCount({required bool passed}) async {
    final prefs = await SharedPreferences.getInstance();
    if (passed) {
      await prefs.setInt(_consecutiveFailKey, 0);
      return 0;
    } else {
      final current = prefs.getInt(_consecutiveFailKey) ?? 0;
      final updated = current + 1;
      await prefs.setInt(_consecutiveFailKey, updated);
      return updated;
    }
  }

  void _showConsecutiveFailPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.warning,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A Quick Suggestion',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'We suggest re-reading the Key Focus Areas and Common '
                  'Mistakes sections before trying again. A quick review '
                  'can make all the difference!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push(
                        '/exercises/${widget.compositeExerciseId}/brief',
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded, size: 20),
                    label: const Text('Review Brief'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _resetQuiz();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.divider),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Try Again',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _finishQuiz(List<QuizQuestion> questions) {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (_selectedAnswers[i] == questions[i].correctAnswer) correct++;
    }
    final int total = questions.length;
    final int percent = total == 0 ? 0 : (correct * 100 ~/ total);
    final bool passed = percent >= AppConstants.quizPassThreshold;

    FirebaseAnalytics.instance.logEvent(
      name: 'quiz_completed',
      parameters: {
        'exercise_id': widget.compositeExerciseId,
        'score_percent': percent,
        'passed': passed ? 1 : 0,
      },
    );
    if (passed) {
      FirebaseAnalytics.instance.logEvent(
        name: 'quiz_passed',
        parameters: {
          'exercise_id': widget.compositeExerciseId,
          'score_percent': percent,
        },
      );
    } else {
      FirebaseAnalytics.instance.logEvent(
        name: 'quiz_failed',
        parameters: {
          'exercise_id': widget.compositeExerciseId,
          'score_percent': percent,
        },
      );
    }
    setState(() {
      _score = correct;
      _showResults = true;
    });

    final newMastery =
        _computeUpdatedMastery(questions, _cachedMasteryData ?? {});
    if (!_saved) {
      _saveResult(questions, passed: passed, updatedMastery: newMastery);
    }

    _updateConsecutiveFailCount(passed: passed).then((failCount) {
      if (!passed &&
          failCount >= AppConstants.quizConsecutiveFailPrompt &&
          mounted) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _showConsecutiveFailPrompt();
        });
      }
    });
  }

  Future<void> _saveResult(
    List<QuizQuestion> questions, {
    bool passed = false,
    Map<String, int> updatedMastery = const {},
  }) async {
    if (_saved || _saving) return;
    setState(() => _saving = true);
    _saved = true;

    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;

      final (exerciseId, subExerciseId) =
          parseExerciseId(widget.compositeExerciseId);

      final firestore = ref.read(firestoreServiceProvider);

      final exercises = ref.read(userExercisesProvider).valueOrNull ?? [];
      final UserExercise? existing = exercises.where((ue) {
        return ue.exerciseId == exerciseId && ue.subExercise == subExerciseId;
      }).firstOrNull;

      final updated = UserExercise(
        id: existing?.id ?? '',
        exerciseId: exerciseId,
        subExercise: subExerciseId,
        exerciseNumber: existing?.exerciseNumber ?? 0,
        status: ExerciseStatus.inProgress,
        bestRating: existing?.bestRating,
        timesAttempted: (existing?.timesAttempted ?? 0) + 1,
        ratingHistory: existing?.ratingHistory ?? [],
        lastAttempted: DateTime.now(),
        videoWatched: existing?.videoWatched ?? false,
        briefViewed: existing?.briefViewed ?? false,
        flashcardsCompleted: existing?.flashcardsCompleted ?? false,
        weatherChecked: existing?.weatherChecked ?? false,
        quizPassed: (existing?.quizPassed ?? false) || passed,
        quizAttempted: true,
        visualisationViewed: existing?.visualisationViewed ?? false,
        spacedRepDue: existing?.spacedRepDue,
        quizMastery: updatedMastery,
      );

      await firestore.upsertUserExercise(uid, updated);
    } catch (e) {
      debugPrint('QuizScreen: failed to save result: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetQuiz() {
    FirebaseAnalytics.instance.logEvent(
      name: 'quiz_retaken',
      parameters: {'exercise_id': widget.compositeExerciseId},
    );
    setState(() {
      _currentIndex = 0;
      _selectedAnswers.clear();
      _showResults = false;
      _score = 0;
      _saved = false;
      _loggedStart = false;
      _orderedQuestions = null;
      _cachedMasteryData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    final questionsAsync =
        ref.watch(quizQuestionsProvider((exerciseId, subExerciseId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
      ),
      body: questionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 40),
                const SizedBox(height: 16),
                Text(
                  'Failed to load quiz. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(
                        quizQuestionsProvider((exerciseId, subExerciseId)));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No quiz questions available yet for this exercise.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          if (_orderedQuestions == null) {
            if (_cachedMasteryData == null) {
              final exercises =
                  ref.watch(userExercisesProvider).valueOrNull ?? [];
              final existing = exercises.where((ue) {
                return ue.exerciseId == exerciseId &&
                    ue.subExercise == subExerciseId;
              }).firstOrNull;
              _cachedMasteryData = existing?.quizMastery ?? {};
            }
            _orderedQuestions =
                _prioritiseQuestions(questions, _cachedMasteryData!);
          }

          final ordered = _orderedQuestions!;

          if (!_loggedStart) {
            _loggedStart = true;
            FirebaseAnalytics.instance.logEvent(
              name: 'quiz_started',
              parameters: {'exercise_id': widget.compositeExerciseId},
            );
          }

          if (_showResults) {
            return _ResultsView(
              questions: ordered,
              selectedAnswers: _selectedAnswers,
              score: _score,
              onTryAgain: _resetQuiz,
              onBack: () => context.pop(),
            );
          }

          return _QuizView(
            questions: ordered,
            currentIndex: _currentIndex,
            selectedAnswers: _selectedAnswers,
            onSelectAnswer: _selectAnswer,
            onNext: () => _next(ordered),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quiz phase
// ---------------------------------------------------------------------------

class _QuizView extends StatelessWidget {
  final List<QuizQuestion> questions;
  final int currentIndex;
  final Map<int, String> selectedAnswers;
  final void Function(String) onSelectAnswer;
  final VoidCallback onNext;

  const _QuizView({
    required this.questions,
    required this.currentIndex,
    required this.selectedAnswers,
    required this.onSelectAnswer,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final question = questions[currentIndex];
    final selected = selectedAnswers[currentIndex];
    final isLast = currentIndex == questions.length - 1;

    return Column(
      children: [
        Semantics(
          label:
              'Quiz progress: question ${currentIndex + 1} of ${questions.length}',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: RunwayProgressIndicator(
              value: (currentIndex + 1) / questions.length,
              height: 6,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentIndex + 1} of ${questions.length}',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  question.questionType == QuestionType.trueFalse
                      ? 'True / False'
                      : 'Multiple Choice',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    question.question,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Answer options
                ...question.options.map((option) {
                  final key = option.key;
                  final value = option.value;
                  final isSelected = selected == key;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AnswerTile(
                      label: value,
                      selected: isSelected,
                      onTap: () => onSelectAnswer(key),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Next button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selected != null ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.surfaceVariant,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isLast ? 'See Results' : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results phase
// ---------------------------------------------------------------------------

class _ResultsView extends StatelessWidget {
  final List<QuizQuestion> questions;
  final Map<int, String> selectedAnswers;
  final int score;
  final VoidCallback onTryAgain;
  final VoidCallback onBack;

  const _ResultsView({
    required this.questions,
    required this.selectedAnswers,
    required this.score,
    required this.onTryAgain,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final int total = questions.length;
    final int percent = total == 0 ? 0 : (score * 100 ~/ total);
    final bool passed = percent >= AppConstants.quizPassThreshold;

    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Score card with celebration animation
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline, width: 0.5),
            ),
            child: Column(
              children: [
                QuizCompletionAnimation(
                  passed: passed,
                  scorePercent: percent,
                ),
                const SizedBox(height: 16),
                Text(
                  '$score / $total',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$percent% correct',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pass/Fail banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: passed
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: passed ? AppColors.success : AppColors.error,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  passed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: passed ? AppColors.success : AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    passed
                        ? 'Passed — great work!'
                        : 'Not passed — aim for ${AppConstants.quizPassThreshold}% to pass',
                    style: TextStyle(
                      color: passed ? AppColors.success : AppColors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Question breakdown
          Text(
            'Review',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          ...questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            final userAnswer = selectedAnswers[i];
            final isCorrect = userAnswer == q.correctAnswer;

            final String userAnswerText = _getAnswerText(q, userAnswer);
            final String correctAnswerText =
                _getAnswerText(q, q.correctAnswer);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCorrect
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.error.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isCorrect ? AppColors.success : AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Q${i + 1}',
                          style: TextStyle(
                            color: isCorrect
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.question,
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!isCorrect) ...[
                      _ReviewRow(
                        label: 'Your answer:',
                        value: userAnswerText,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 4),
                    ],
                    _ReviewRow(
                      label: 'Correct answer:',
                      value: correctAnswerText,
                      color: AppColors.success,
                    ),
                    if (q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          q.explanation,
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          if (!passed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: onTryAgain,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.divider),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Back to Exercise'),
          ),
        ],
      ),
    );
  }

  String _getAnswerText(QuizQuestion q, String? answerKey) {
    if (answerKey == null) return '—';
    for (final option in q.options) {
      if (option.key == answerKey) return option.value;
    }
    return answerKey;
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReviewRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
