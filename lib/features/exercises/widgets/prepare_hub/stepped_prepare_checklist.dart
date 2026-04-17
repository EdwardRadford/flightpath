import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/user_exercise.dart';

// ---------------------------------------------------------------------------
// Step data class
// ---------------------------------------------------------------------------

class PrepareStepItem {
  final int stepNumber;
  final IconData icon;
  final String label;
  final bool done;
  final String route;
  final String statusLabel;

  const PrepareStepItem({
    required this.stepNumber,
    required this.icon,
    required this.label,
    required this.done,
    required this.route,
    required this.statusLabel,
  });
}

// ---------------------------------------------------------------------------
// Stepped prepare checklist
// ---------------------------------------------------------------------------

class SteppedPrepareChecklist extends StatelessWidget {
  final String compositeExerciseId;
  final LessonType lessonType;
  final UserExercise? userExercise;
  final bool quizPassed;
  final bool locked;

  const SteppedPrepareChecklist({
    super.key,
    required this.compositeExerciseId,
    required this.lessonType,
    required this.userExercise,
    required this.quizPassed,
    this.locked = false,
  });

  List<PrepareStepItem> _buildSteps() {
    final bool briefDone = userExercise?.briefViewed ?? false;
    final bool videoDone = userExercise?.videoWatched ?? false;
    final bool flashcardsDone = userExercise?.flashcardsCompleted ?? false;
    final String briefStatusLabel = userExercise?.briefStatus ?? 'Not Viewed';
    final String videoStatusLabel = userExercise?.videoStatus ?? 'Not Watched';
    final String flashcardsStatusLabel =
        userExercise?.flashcardsStatus ?? 'Not Started';
    final String quizStatusLabel = userExercise?.quizStatus ?? 'Not Started';

    switch (lessonType) {
      case LessonType.ground:
        return [
          PrepareStepItem(
            stepNumber: 1,
            icon: Icons.menu_book_rounded,
            label: 'Brief',
            done: briefDone,
            route: '/exercises/$compositeExerciseId/brief',
            statusLabel: briefStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 2,
            icon: Icons.edit_rounded,
            label: 'Quiz',
            done: quizPassed,
            route: '/exercises/$compositeExerciseId/quiz',
            statusLabel: quizStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 3,
            icon: Icons.style_rounded,
            label: 'Flashcards',
            done: flashcardsDone,
            route: '/exercises/$compositeExerciseId/flashcards',
            statusLabel: flashcardsStatusLabel,
          ),
        ];

      case LessonType.milestone:
        return [
          PrepareStepItem(
            stepNumber: 1,
            icon: Icons.calendar_today_rounded,
            label: 'Schedule Your Lesson',
            done: false,
            route: '/exercises/$compositeExerciseId/schedule',
            statusLabel: 'Not Started',
          ),
        ];

      case LessonType.flight:
        return [
          PrepareStepItem(
            stepNumber: 1,
            icon: Icons.menu_book_rounded,
            label: 'Brief',
            done: briefDone,
            route: '/exercises/$compositeExerciseId/brief',
            statusLabel: briefStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 2,
            icon: Icons.play_circle_rounded,
            label: 'Video',
            done: videoDone,
            route: '/exercises/$compositeExerciseId/video',
            statusLabel: videoStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 3,
            icon: Icons.style_rounded,
            label: 'Flashcards',
            done: flashcardsDone,
            route: '/exercises/$compositeExerciseId/flashcards',
            statusLabel: flashcardsStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 4,
            icon: Icons.edit_rounded,
            label: 'Quiz',
            done: quizPassed,
            route: '/exercises/$compositeExerciseId/quiz',
            statusLabel: quizStatusLabel,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final completedCount = steps.where((s) => s.done).length;
    final totalCount = steps.length;
    final allDone = completedCount == totalCount;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    final firstIncomplete = steps.where((s) => !s.done).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: allDone
                  ? AppColors.success.withValues(alpha: 0.5)
                  : AppColors.divider,
              width: allDone ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    allDone ? 'All Steps Complete!' : 'Preparation Progress',
                    style: TextStyle(
                      color:
                          allDone ? AppColors.success : AppColors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$completedCount of $totalCount steps',
                    style: TextStyle(
                      color: allDone
                          ? AppColors.success
                          : AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    allDone ? AppColors.success : AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
              if (allDone) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Great work! You\'re fully prepared for this lesson.',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Step list
        ...steps.map((step) {
          const viewableLabels = {'Brief', 'Video', 'Visualisation'};
          final isStepLocked =
              locked && !viewableLabels.contains(step.label);
          final isNext = !isStepLocked &&
              firstIncomplete != null &&
              step == firstIncomplete;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: isStepLocked
                ? LockedStepCard(step: step, totalSteps: totalCount)
                : StepCard(
                    step: step,
                    totalSteps: totalCount,
                    isNextStep: isNext,
                    onTap: () => context.push(step.route),
                  ),
          );
        }),

        // Start Next Step button
        if (firstIncomplete != null &&
            !({
              'Quiz',
              'Flashcards',
              'Schedule Your Lesson',
            }.contains(firstIncomplete.label) &&
                locked)) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push(firstIncomplete.route),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                'Continue to Step ${firstIncomplete.stepNumber}: ${firstIncomplete.label}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step card
// ---------------------------------------------------------------------------

class StepCard extends StatelessWidget {
  final PrepareStepItem step;
  final int totalSteps;
  final bool isNextStep;
  final VoidCallback onTap;

  const StepCard({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.isNextStep,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = step.done
        ? AppColors.success.withValues(alpha: 0.5)
        : isNextStep
            ? AppColors.primary.withValues(alpha: 0.6)
            : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isNextStep ? 2 : 1.5,
          ),
          boxShadow: isNextStep
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Step number circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: step.done
                    ? AppColors.success
                    : isNextStep
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: step.done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : Text(
                        '${step.stepNumber}',
                        style: TextStyle(
                          color: isNextStep
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Icon
            Icon(
              step.icon,
              color: step.done
                  ? AppColors.success
                  : isNextStep
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Text(
                'Step ${step.stepNumber} of $totalSteps: ${step.label}',
                style: TextStyle(
                  color: step.done
                      ? AppColors.success
                      : isNextStep
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight:
                      isNextStep ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),

            // Status indicator
            if (step.done)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20)
            else if (step.statusLabel == 'Unsatisfactory')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Unsatisfactory',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (isNextStep)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked step card
// ---------------------------------------------------------------------------

class LockedStepCard extends StatelessWidget {
  final PrepareStepItem step;
  final int totalSteps;

  const LockedStepCard({
    super.key,
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          // Step number circle (greyed)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${step.stepNumber}',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const SizedBox(width: 12),

          // Label (greyed)
          Expanded(
            child: Text(
              'Step ${step.stepNumber} of $totalSteps: ${step.label}',
              style: TextStyle(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Lock icon
          Icon(
            Icons.lock_rounded,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            size: 18,
          ),
        ],
      ),
    );
  }
}
