// Home > Daily question card with reveal animation.
// Extracted from home_screen.dart during 2026-04-13 refactor.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/home/providers/daily_question_provider.dart';
import 'package:flight_path/shared/models/quiz_question.dart';

class DailyQuestionCard extends ConsumerStatefulWidget {
  const DailyQuestionCard({super.key});

  @override
  ConsumerState<DailyQuestionCard> createState() =>
      _DailyQuestionCardState();
}

class _DailyQuestionCardState extends ConsumerState<DailyQuestionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _onRevealTapped(QuizQuestion question) async {
    await ref.read(dailyQuestionProvider.notifier).markAnswered();
    _expandController.forward();
    FirebaseAnalytics.instance.logEvent(
      name: 'daily_question_answered',
      parameters: {
        'question_id': question.id,
        'exercise_id': question.exerciseId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyQuestionProvider);
    final cs = Theme.of(context).colorScheme;

    if (state.loading) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    if (state.error != null || state.question == null) {
      return const SizedBox.shrink();
    }

    final question = state.question!;

    if (state.answered && _expandController.isDismissed) {
      _expandController.value = 1.0;
    }

    // The model already returns the display string for the correct option
    // (e.g. 'A. Ailerons, elevator, rudder' or 'A. True'), so we can use it
    // directly for both MC and T/F questions.
    final String correctAnswerText = question.correctAnswerText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.quiz_rounded,
                      color: AppColors.primary, size: 15),
                ),
                const SizedBox(width: 10),
                const Text('Daily Question',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    )),
              ],
            ),
            const SizedBox(height: 12),

            // Question text
            Text(question.question,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                )),
            const SizedBox(height: 14),

            // Answer reveal
            SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, thickness: 1, color: cs.outline),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CORRECT ANSWER',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: 4),
                        Text(correctAnswerText,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                  if (question.explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(question.explanation,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.5,
                        )),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Reveal button
            if (!state.answered)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _onRevealTapped(question),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reveal Answer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
