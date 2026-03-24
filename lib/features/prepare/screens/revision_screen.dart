// Revision screen — cross-exercise quiz mode for skills test prep. Pulls
// questions from all exercises weighted by weakness.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/prepare/providers/revision_provider.dart';
import 'package:flight_path/shared/models/quiz_question.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

// ---------------------------------------------------------------------------
// Shared prefs key for tracking incorrect question IDs
// ---------------------------------------------------------------------------
const _incorrectQuestionsKey = 'revision_incorrect_question_ids';

// ---------------------------------------------------------------------------
// Session length options
// ---------------------------------------------------------------------------
enum _SessionLength {
  quick(10, 'Quick'),
  standard(20, 'Standard'),
  full(30, 'Full');

  final int count;
  final String label;
  const _SessionLength(this.count, this.label);
}

// ---------------------------------------------------------------------------
// RevisionScreen
// ---------------------------------------------------------------------------

class RevisionScreen extends ConsumerStatefulWidget {
  const RevisionScreen({super.key});

  @override
  ConsumerState<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends ConsumerState<RevisionScreen> {
  // Session state
  _SessionLength? _selectedLength; // ignore: unused_field — reserved for future session length UI
  List<QuizQuestion>? _questions;
  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {};
  bool _showResults = false;
  int _score = 0;
  Set<String> _incorrectIds = {};

  // Focus area retry state
  bool _focusMode = false; // ignore: unused_field — reserved for focus area retry mode

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'revision_opened');
    _loadIncorrectIds();
  }

  Future<void> _loadIncorrectIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_incorrectQuestionsKey) ?? [];
    setState(() => _incorrectIds = ids.toSet());
  }

  Future<void> _saveIncorrectIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_incorrectQuestionsKey, _incorrectIds.toList());
  }

  void _startSession(_SessionLength length) {
    final allQuestions = ref.read(allQuizQuestionsProvider).valueOrNull ?? [];
    final exerciseScores =
        ref.read(exerciseQuizScoresProvider).valueOrNull ?? {};

    if (allQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quiz questions available yet.')),
      );
      return;
    }

    final selected = selectWeightedQuestions(
      allQuestions: allQuestions,
      exerciseScores: exerciseScores,
      incorrectQuestionIds: _incorrectIds,
      count: length.count,
    );

    setState(() {
      _selectedLength = length;
      _questions = selected;
      _currentIndex = 0;
      _selectedAnswers.clear();
      _showResults = false;
      _score = 0;
    });

    FirebaseAnalytics.instance.logEvent(
      name: 'revision_started',
      parameters: {'session_length': length.label},
    );
  }

  void _startFocusSession(List<String> weakExerciseIds) {
    final allQuestions = ref.read(allQuizQuestionsProvider).valueOrNull ?? [];
    final focused = allQuestions
        .where((q) => weakExerciseIds.contains(q.exerciseId))
        .toList();

    if (focused.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No questions available for these exercises.')),
      );
      return;
    }

    final exerciseScores =
        ref.read(exerciseQuizScoresProvider).valueOrNull ?? {};

    final selected = selectWeightedQuestions(
      allQuestions: focused,
      exerciseScores: exerciseScores,
      incorrectQuestionIds: _incorrectIds,
      count: 20,
    );

    setState(() {
      _selectedLength = _SessionLength.standard;
      _questions = selected;
      _currentIndex = 0;
      _selectedAnswers.clear();
      _showResults = false;
      _score = 0;
      _focusMode = true;
    });
  }

  void _selectAnswer(String answer) {
    if (_showResults) return;
    setState(() {
      _selectedAnswers[_currentIndex] = answer;
    });
  }

  void _next() {
    if (_questions == null) return;
    if (_currentIndex < _questions!.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    if (_questions == null) return;
    int correct = 0;
    final newIncorrect = <String>{};

    for (var i = 0; i < _questions!.length; i++) {
      if (_selectedAnswers[i] == _questions![i].correctAnswer) {
        correct++;
        // Remove from incorrect set if they got it right
        _incorrectIds.remove(_questions![i].id);
      } else {
        newIncorrect.add(_questions![i].id);
      }
    }

    _incorrectIds.addAll(newIncorrect);
    _saveIncorrectIds();

    setState(() {
      _score = correct;
      _showResults = true;
    });

    FirebaseAnalytics.instance.logEvent(
      name: 'revision_completed',
      parameters: {
        'score': correct,
        'total': _questions!.length,
        'percentage': (correct / _questions!.length * 100).round(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Revision Mode'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (_questions != null && !_showResults) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Leave Revision?'),
                  content: const Text(
                      'Your progress in this session will be lost.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Stay'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop();
                      },
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: _questions == null
          ? _buildSessionPicker(cs)
          : _showResults
              ? _buildResults(cs)
              : _buildQuestion(cs),
    );
  }

  // ── Session length picker ─────────────────────────────────────────────────

  Widget _buildSessionPicker(ColorScheme cs) {
    final questionsAsync = ref.watch(allQuizQuestionsProvider);

    return questionsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: cs.primary),
      ),
      error: (_, _) => Center(
        child: Text('Unable to load questions.',
            style: TextStyle(color: cs.error)),
      ),
      data: (allQuestions) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_rounded,
                    color: AppColors.primary, size: 48),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Skills Test Revision',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Questions from all exercises, weighted towards\nyour weakest areas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${allQuestions.length} questions available',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Choose session length:',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._SessionLength.values.map((sl) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SessionLengthTile(
                    session: sl,
                    available: allQuestions.length,
                    onTap: allQuestions.length >= sl.count
                        ? () => _startSession(sl)
                        : (allQuestions.isNotEmpty
                            ? () => _startSession(sl)
                            : null),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── Question display ──────────────────────────────────────────────────────

  Widget _buildQuestion(ColorScheme cs) {
    final q = _questions![_currentIndex];
    final selected = _selectedAnswers[_currentIndex];
    final hasAnswered = selected != null;
    final isCorrect = selected == q.correctAnswer;
    final exerciseName = exerciseDisplayName(q.exerciseId);

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions!.length,
          backgroundColor: cs.onSurface.withValues(alpha: 0.1),
          color: AppColors.primary,
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question counter + exercise badge
                Row(
                  children: [
                    Text(
                      'Question ${_currentIndex + 1} of ${_questions!.length}',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        exerciseName,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Question text
                Text(
                  q.question,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Answer options
                ...q.options.map((option) {
                  final isSelected = selected == option.key;
                  final isCorrectOption = option.key == q.correctAnswer;

                  Color? bgColor;
                  Color? borderColor;
                  if (hasAnswered) {
                    if (isCorrectOption) {
                      bgColor = AppColors.success.withValues(alpha: 0.12);
                      borderColor = AppColors.success;
                    } else if (isSelected && !isCorrect) {
                      bgColor = AppColors.error.withValues(alpha: 0.12);
                      borderColor = AppColors.error;
                    }
                  } else if (isSelected) {
                    bgColor = AppColors.primary.withValues(alpha: 0.12);
                    borderColor = AppColors.primary;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: hasAnswered ? null : () => _selectAnswer(option.key),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgColor ?? cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor ??
                                cs.onSurface.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          option.value,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Explanation (after answering)
                if (hasAnswered) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isCorrect
                              ? AppColors.success
                              : AppColors.error)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color:
                              isCorrect ? AppColors.success : AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q.explanation,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Next / Confirm button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: hasAnswered
                  ? FilledButton(
                      onPressed: _next,
                      child: Text(
                        _currentIndex < _questions!.length - 1
                            ? 'Next'
                            : 'See Results',
                      ),
                    )
                  : FilledButton(
                      onPressed: selected != null
                          ? () {} // already handled above
                          : null,
                      child: const Text('Select an answer'),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Results display ───────────────────────────────────────────────────────

  Widget _buildResults(ColorScheme cs) {
    final percentage =
        (_score / _questions!.length * 100).round();
    final passed = percentage >= AppConstants.quizPassThreshold;

    // Build per-exercise breakdown
    final exerciseResults = <String, (int correct, int total)>{};
    for (var i = 0; i < _questions!.length; i++) {
      final exId = _questions![i].exerciseId;
      final entry = exerciseResults[exId] ?? (0, 0);
      final isCorrect = _selectedAnswers[i] == _questions![i].correctAnswer;
      exerciseResults[exId] = (
        entry.$1 + (isCorrect ? 1 : 0),
        entry.$2 + 1,
      );
    }

    // Sort by score ascending (weakest first)
    final sorted = exerciseResults.entries.toList()
      ..sort((a, b) {
        final aPC = a.value.$2 > 0 ? a.value.$1 / a.value.$2 : 0.0;
        final bPC = b.value.$2 > 0 ? b.value.$1 / b.value.$2 : 0.0;
        return aPC.compareTo(bPC);
      });

    // Focus areas = 2-3 weakest
    final focusAreas = sorted
        .where((e) =>
            e.value.$2 > 0 &&
            (e.value.$1 / e.value.$2) < AppConstants.quizPassThreshold / 100.0)
        .take(3)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Score circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (passed ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
              border: Border.all(
                color: passed ? AppColors.success : AppColors.warning,
                width: 3,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: passed ? AppColors.success : AppColors.warning,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_score / ${_questions!.length}',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            passed ? 'Great work!' : 'Keep practising!',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Exercise breakdown
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Breakdown by Exercise',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          ...sorted.map((entry) {
            final exName = exerciseDisplayName(entry.key);
            final correct = entry.value.$1;
            final total = entry.value.$2;
            final pct = total > 0 ? (correct / total * 100).round() : 0;
            final color = pct >= 75
                ? AppColors.success
                : pct >= 50
                    ? AppColors.warning
                    : AppColors.error;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exName,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '$correct/$total ($pct%)',
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Focus areas
          if (focusAreas.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.track_changes_rounded,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Focus Areas',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...focusAreas.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '  -  ${exerciseDisplayName(e.key)}',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _startFocusSession(
                          focusAreas.map((e) => e.key).toList()),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Revise Weak Areas'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() {
                    _questions = null;
                    _focusMode = false;
                  }),
                  child: const Text('New Session'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session length tile
// ---------------------------------------------------------------------------

class _SessionLengthTile extends StatelessWidget {
  final _SessionLength session;
  final int available;
  final VoidCallback? onTap;

  const _SessionLengthTile({
    required this.session,
    required this.available,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${session.count}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.label} Session',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${session.count} questions',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
