// Prepare hub screen — central dashboard for a single exercise showing
// brief, quiz, visualisation, video, weather, and schedule options.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Central preparation dashboard for a single exercise.
class PrepareHubScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const PrepareHubScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<PrepareHubScreen> createState() => _PrepareHubScreenState();
}

class _PrepareHubScreenState extends ConsumerState<PrepareHubScreen> {
  bool _analyticsLogged = false;

  @override
  Widget build(BuildContext context) {
    final compositeExerciseId = widget.compositeExerciseId;
    final (exerciseId, subExerciseId) = parseExerciseId(compositeExerciseId);

    final contentAsync =
        ref.watch(exerciseContentProvider((exerciseId, subExerciseId)));
    final userExercisesAsync = ref.watch(userExercisesProvider);
    final lessonsAsync = ref.watch(allLessonsProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return contentAsync.when(
      loading: () => const Scaffold(
        
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, _) => Scaffold(
        
        body: _ErrorBody(
          message: 'Unable to load exercise content. Please check your connection and try again.',
          onRetry: () => ref.invalidate(
            exerciseContentProvider((exerciseId, subExerciseId)),
          ),
        ),
      ),
      data: (content) {
        // Log analytics only once per screen instance, not on every rebuild.
        if (!_analyticsLogged) {
          _analyticsLogged = true;
          FirebaseAnalytics.instance.logEvent(
            name: 'exercise_opened',
            parameters: {'exercise_id': compositeExerciseId},
          );
        }

        if (content == null) {
          // Show placeholder when content hasn't been seeded yet
          return Scaffold(
            
            appBar: AppBar(
              title: Text(exerciseFullName(compositeExerciseId)),
              
            ),
            body: _PlaceholderBody(
              compositeExerciseId: compositeExerciseId,
              displayName: exerciseFullName(compositeExerciseId),
            ),
          );
        }

        // Resolve the matching UserExercise for this exercise (may be null)
        final UserExercise? userExercise = userExercisesAsync.whenOrNull(
          data: (list) => list.where((ue) {
            final sameExercise = ue.exerciseId == exerciseId;
            final sameSub = ue.subExercise == subExerciseId;
            return sameExercise && sameSub;
          }).firstOrNull,
        );

        // Check if any completed lessons exist for this exercise
        final List<Lesson> exerciseLessons = lessonsAsync.whenOrNull(
              data: (list) => list
                  .where((l) => l.exerciseId == exerciseId)
                  .toList(),
            ) ??
            [];

        final bool hasLessons = exerciseLessons.isNotEmpty;

        // Determine if quiz was ever passed at CAA standard (75%)
        final bool quizPassed = exerciseLessons
            .any((l) => l.quizScore != null && l.quizScore! >= AppConstants.quizPassThreshold);

        // Free exercises are always accessible; premium exercises need purchase.
        final hasAccess = appUser?.canAccessExercise(compositeExerciseId) ??
            AppConstants.isFreeExercise(compositeExerciseId,
                currentExerciseNumber: appUser?.currentExerciseNumber ?? 1);

        return Scaffold(
          
          appBar: AppBar(
            title: Text(
              content.subExercise != null
                  ? 'Exercise ${content.subExercise}'
                  : 'Exercise ${content.exerciseNumber}',
            ),
            
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share exercise link',
                onPressed: () {
                  final url = 'https://flightpath.app/exercise/$compositeExerciseId';
                  final title = content.subExercise != null
                      ? 'Exercise ${content.subExercise}'
                      : 'Exercise ${content.exerciseNumber}';
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'Check out $title on Flight Path: $url',
                    ),
                  );
                  FirebaseAnalytics.instance.logEvent(
                    name: 'exercise_shared',
                    parameters: {'exercise_id': compositeExerciseId},
                  );
                },
              ),
            ],
          ),
          body: _PrepareHubBody(
            compositeExerciseId: compositeExerciseId,
            exerciseId: exerciseId,
            subExerciseId: subExerciseId,
            content: content,
            userExercise: userExercise,
            hasLessons: hasLessons,
            quizPassed: quizPassed,
            isPremium: hasAccess,
            freeWindowStart: appUser?.freeWindowStart ?? 1,
            freeWindowEnd: appUser?.freeWindowEnd ?? 3,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Body — extracted so it can be a StatelessWidget with const constructor
// ---------------------------------------------------------------------------

class _PrepareHubBody extends StatelessWidget {
  final String compositeExerciseId;
  final String exerciseId;
  final String? subExerciseId;
  final ExerciseContent content;
  final UserExercise? userExercise;
  final bool hasLessons;
  final bool quizPassed;
  final bool isPremium;
  final int freeWindowStart;
  final int freeWindowEnd;

  const _PrepareHubBody({
    required this.compositeExerciseId,
    required this.exerciseId,
    required this.subExerciseId,
    required this.content,
    required this.userExercise,
    required this.hasLessons,
    required this.quizPassed,
    required this.isPremium,
    required this.freeWindowStart,
    required this.freeWindowEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Exercise header
          _ExerciseHeader(content: content),
          const SizedBox(height: 16),

          // 2. Progress card
          _ProgressCard(userExercise: userExercise),
          const SizedBox(height: 16),

          // 2b. Paywall banner (shown when trial/subscription has expired)
          if (!isPremium) ...[
            _PaywallBanner(
              freeWindowStart: freeWindowStart,
              freeWindowEnd: freeWindowEnd,
              onShown: () {
                FirebaseAnalytics.instance.logEvent(
                  name: 'paywall_shown',
                  parameters: {
                    'source': 'prepare_hub',
                    'exercise_id': compositeExerciseId,
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // 2c. First Solo motivational section (Exercise 14 / milestone)
          if (content.lessonType == LessonType.milestone &&
              content.exerciseNumber == 14) ...[
            const _FirstSoloMotivationalSection(),
            const SizedBox(height: 16),
          ],

          // 3. Prepare checklist with step numbering
          _SectionLabel(label: 'Prepare'),
          const SizedBox(height: 8),
          _SteppedPrepareChecklist(
            compositeExerciseId: compositeExerciseId,
            lessonType: content.lessonType,
            userExercise: userExercise,
            quizPassed: quizPassed,
            locked: !isPremium,
          ),
          const SizedBox(height: 28),

          // 4. Log / Start button
          _LessonButton(
            compositeExerciseId: compositeExerciseId,
            exerciseId: exerciseId,
            subExerciseId: subExerciseId,
            hasLessons: hasLessons,
            locked: !isPremium,
          ),
          const SizedBox(height: 20),

          // 5. Revision mode banner
          _SectionLabel(label: 'Revision'),
          const SizedBox(height: 8),
          _RevisionBanner(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 1: Exercise header
// ---------------------------------------------------------------------------

class _ExerciseHeader extends StatelessWidget {
  final ExerciseContent content;

  const _ExerciseHeader({required this.content});

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final String badgeLabel;

    switch (content.lessonType) {
      case LessonType.ground:
        badgeColor = AppColors.warning;
        badgeLabel = 'GROUND';
        break;
      case LessonType.milestone:
        badgeColor = AppColors.success;
        badgeLabel = 'MILESTONE';
        break;
      case LessonType.flight:
        badgeColor = AppColors.primary;
        badgeLabel = 'FLIGHT';
        break;
    }

    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content.subExercise != null
                ? 'Exercise ${content.subExercise}'
                : 'Exercise ${content.exerciseNumber}',
            style:  TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content.exerciseName,
            style:  TextStyle(
              color: AppColors.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 2: Progress card
// ---------------------------------------------------------------------------

class _ProgressCard extends StatelessWidget {
  final UserExercise? userExercise;

  const _ProgressCard({required this.userExercise});

  @override
  Widget build(BuildContext context) {
    if (userExercise == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child:  Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.onSurfaceVariant, size: 20),
            SizedBox(width: 10),
            Text(
              'Not yet started',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final ue = userExercise!;
    final String statusLabel;
    final Color statusColor;

    switch (ue.status) {
      case ExerciseStatus.inProgress:
        statusLabel = 'In Progress';
        statusColor = AppColors.warning;
        break;
      case ExerciseStatus.complete:
        statusLabel = 'Complete';
        statusColor = AppColors.success;
        break;
      case ExerciseStatus.notStarted:
        statusLabel = 'Not Started';
        statusColor = AppColors.onSurfaceVariant;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Status pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Best rating
          if (ue.bestRating != null) ...[
            const Icon(Icons.star_rounded,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 4),
            Text(
              '${ue.bestRating}/5 best',
              style:  TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 16),
          ],
          // Times attempted
           Icon(Icons.repeat_rounded,
              color: AppColors.onSurfaceVariant, size: 18),
          const SizedBox(width: 4),
          Text(
            '${ue.timesAttempted} ${ue.timesAttempted == 1 ? 'lesson' : 'lessons'}',
            style:  TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Revision banner — tappable card linking to cross-exercise revision mode
// ---------------------------------------------------------------------------

class _RevisionBanner extends StatelessWidget {
  const _RevisionBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/revision'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revision Mode',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mixed questions across all exercises, weighted to your weak areas.',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style:  TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// Section 3b: Stepped prepare checklist (numbered steps + progress bar)
// ---------------------------------------------------------------------------

/// Data class for a single preparation step.
class _StepItem {
  final int stepNumber;
  final IconData icon;
  final String label;
  final bool done;
  final String route;

  const _StepItem({
    required this.stepNumber,
    required this.icon,
    required this.label,
    required this.done,
    required this.route,
  });
}

class _SteppedPrepareChecklist extends StatelessWidget {
  final String compositeExerciseId;
  final LessonType lessonType;
  final UserExercise? userExercise;
  final bool quizPassed;
  final bool locked;

  const _SteppedPrepareChecklist({
    required this.compositeExerciseId,
    required this.lessonType,
    required this.userExercise,
    required this.quizPassed,
    this.locked = false,
  });

  List<_StepItem> _buildSteps() {
    final bool briefDone = userExercise?.briefViewed ?? false;
    final bool videoDone = userExercise?.videoWatched ?? false;
    final bool flashcardsDone = userExercise?.flashcardsCompleted ?? false;
    final bool weatherDone = userExercise?.weatherChecked ?? false;

    switch (lessonType) {
      case LessonType.ground:
        // Ground lessons: fewer steps — no weather/video
        return [
          _StepItem(
            stepNumber: 1,
            icon: Icons.menu_book_rounded,
            label: 'Brief',
            done: briefDone,
            route: '/exercises/$compositeExerciseId/brief',
          ),
          _StepItem(
            stepNumber: 2,
            icon: Icons.edit_rounded,
            label: 'Quiz',
            done: quizPassed,
            route: '/exercises/$compositeExerciseId/quiz',
          ),
          _StepItem(
            stepNumber: 3,
            icon: Icons.style_rounded,
            label: 'Flashcards',
            done: flashcardsDone,
            route: '/exercises/$compositeExerciseId/flashcards',
          ),
        ];

      case LessonType.milestone:
        // Milestone: just schedule
        return [
          _StepItem(
            stepNumber: 1,
            icon: Icons.calendar_today_rounded,
            label: 'Schedule Your Lesson',
            done: false,
            route: '/exercises/$compositeExerciseId/schedule',
          ),
        ];

      case LessonType.flight:
        // Full flight prep: Brief, Video, Flashcards, Quiz, Weather Briefing
        return [
          _StepItem(
            stepNumber: 1,
            icon: Icons.menu_book_rounded,
            label: 'Brief',
            done: briefDone,
            route: '/exercises/$compositeExerciseId/brief',
          ),
          _StepItem(
            stepNumber: 2,
            icon: Icons.play_circle_rounded,
            label: 'Video',
            done: videoDone,
            route: '/exercises/$compositeExerciseId/video',
          ),
          _StepItem(
            stepNumber: 3,
            icon: Icons.style_rounded,
            label: 'Flashcards',
            done: flashcardsDone,
            route: '/exercises/$compositeExerciseId/flashcards',
          ),
          _StepItem(
            stepNumber: 4,
            icon: Icons.edit_rounded,
            label: 'Quiz',
            done: quizPassed,
            route: '/exercises/$compositeExerciseId/quiz',
          ),
          _StepItem(
            stepNumber: 5,
            icon: Icons.cloud_rounded,
            label: 'Weather Briefing',
            done: weatherDone,
            route: '/exercises/$compositeExerciseId/weather',
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

    // Find the first incomplete step for auto-navigation
    final firstIncomplete = steps.where((s) => !s.done).firstOrNull;

    Widget content = Column(
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
                      color: allDone ? AppColors.success : AppColors.onSurface,
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
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 8),
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
          // Brief, Video, and Visualisation are always viewable even on the
          // free tier — only interactive steps (Quiz, Flashcards, Schedule)
          // require a subscription outside the free window.
          const viewableLabels = {'Brief', 'Video', 'Visualisation'};
          final isStepLocked = locked && !viewableLabels.contains(step.label);
          final isNext = !isStepLocked &&
              firstIncomplete != null &&
              step == firstIncomplete;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: isStepLocked
                ? _LockedStepCard(step: step, totalSteps: totalCount)
                : _StepCard(
                    step: step,
                    totalSteps: totalCount,
                    isNextStep: isNext,
                    onTap: () => context.push(step.route),
                  ),
          );
        }),

        // Start Next Step button (only when there's a non-locked incomplete step)
        if (firstIncomplete != null && !({
              'Quiz',
              'Flashcards',
              'Schedule Your Lesson',
            }.contains(firstIncomplete.label) && locked)) ...[
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

    return content;
  }
}

/// A single step card with step number, icon, label, and done/next state.
class _StepCard extends StatelessWidget {
  final _StepItem step;
  final int totalSteps;
  final bool isNextStep;
  final VoidCallback onTap;

  const _StepCard({
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
              const Text(
                'Done',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

/// A locked step card — shows the step name greyed out with a lock icon.
/// Not tappable.
class _LockedStepCard extends StatelessWidget {
  final _StepItem step;
  final int totalSteps;

  const _LockedStepCard({
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

          // Icon (greyed)
          Icon(
            step.icon,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            size: 22,
          ),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: done
              ? Border.all(
                  color: AppColors.success.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                    color: done ? AppColors.success : AppColors.primary,
                    size: 28),
                if (done)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: done ? AppColors.success : AppColors.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 4: Log / Start lesson button
// ---------------------------------------------------------------------------

class _LessonButton extends ConsumerStatefulWidget {
  final String compositeExerciseId;
  final String exerciseId;
  final String? subExerciseId;
  final bool hasLessons;
  final bool locked;

  const _LessonButton({
    required this.compositeExerciseId,
    required this.exerciseId,
    required this.subExerciseId,
    required this.hasLessons,
    this.locked = false,
  });

  @override
  ConsumerState<_LessonButton> createState() => _LessonButtonState();
}

class _LessonButtonState extends ConsumerState<_LessonButton> {
  bool _updating = false;

  /// Find the most recent active lesson (scheduled or prepared) for this exercise.
  Lesson? _activeLesson(List<Lesson> lessons) {
    final matching = lessons.where((l) {
      final sameExercise = l.exerciseId == widget.exerciseId;
      final sameSub = l.subExercise == widget.subExerciseId;
      final isActive = l.status == LessonStatus.scheduled ||
          l.status == LessonStatus.prepared;
      return sameExercise && sameSub && isActive;
    }).toList();
    if (matching.isEmpty) return null;
    // Return the most recently created active lesson.
    matching.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matching.first;
  }

  Future<void> _markPrepared(Lesson lesson) async {
    setState(() => _updating = true);
    try {
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.updateLesson(lesson.id, {'status': 'prepared'});

      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_prepared',
        parameters: {'exercise_id': widget.compositeExerciseId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You\'re ready for your lesson!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update lesson. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locked) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final user = ref.read(appUserProvider).valueOrNull;
            showPremiumPaywall(
              context,
              source: 'prepare_hub_button',
              freeWindowStart: user?.freeWindowStart ?? 1,
              freeWindowEnd: user?.freeWindowEnd ?? 3,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Upgrade to Pro',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final lessonsAsync = ref.watch(allLessonsProvider);
    final activeLesson = lessonsAsync.whenOrNull(
      data: (lessons) => _activeLesson(lessons),
    );

    // If the most recent active lesson is "scheduled", show the "I'm Ready" button.
    if (activeLesson != null && activeLesson.status == LessonStatus.scheduled) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _updating ? null : () => _markPrepared(activeLesson),
              icon: _updating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text(
                "I'm Ready \u2713",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
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
              onPressed: () => context
                  .push('/exercises/${widget.compositeExerciseId}/debrief'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.divider),
                foregroundColor: AppColors.onSurfaceVariant,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Check In After Lesson',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    // If the most recent active lesson is "prepared", show "Debrief Lesson" as primary.
    if (activeLesson != null && activeLesson.status == LessonStatus.prepared) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context
              .push('/exercises/${widget.compositeExerciseId}/debrief'),
          icon: const Icon(Icons.rate_review_rounded),
          label: const Text(
            'Debrief Lesson',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    // Default: no active lesson — show the standard "Check In After Lesson" button.
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context
            .push('/exercises/${widget.compositeExerciseId}/debrief'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Check In After Lesson',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paywall banner
// ---------------------------------------------------------------------------

class _PaywallBanner extends StatefulWidget {
  final VoidCallback? onShown;
  final int freeWindowStart;
  final int freeWindowEnd;
  const _PaywallBanner({
    this.onShown,
    this.freeWindowStart = 1,
    this.freeWindowEnd = 3,
  });

  @override
  State<_PaywallBanner> createState() => _PaywallBannerState();
}

class _PaywallBannerState extends State<_PaywallBanner> {
  @override
  void initState() {
    super.initState();
    widget.onShown?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:  [
                Text(
                  'Pro Exercise',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Upgrade to Pro to unlock all 19 exercises.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => showPremiumPaywall(
              context,
              source: 'prepare_hub',
              freeWindowStart: widget.freeWindowStart,
              freeWindowEnd: widget.freeWindowEnd,
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Placeholder body (shown when content not yet seeded to Firestore)
// ---------------------------------------------------------------------------

class _PlaceholderBody extends StatelessWidget {
  final String compositeExerciseId;
  final String displayName;

  const _PlaceholderBody({
    required this.compositeExerciseId,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: const Text(
                    'FLIGHT',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style:  TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Progress
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child:  Row(
              children: [
                Icon(Icons.flag_outlined,
                    color: AppColors.onSurfaceVariant, size: 20),
                SizedBox(width: 10),
                Text(
                  'Not yet started',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Prepare section
           Text(
            'PREPARE',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ActionCard(
                icon: Icons.menu_book_rounded,
                label: 'Study Brief',
                done: false,
                onTap: () => context
                    .push('/exercises/$compositeExerciseId/brief'),
              ),
              _ActionCard(
                icon: Icons.play_circle_rounded,
                label: 'Watch Video',
                done: false,
                onTap: () => context
                    .push('/exercises/$compositeExerciseId/video'),
              ),
              _ActionCard(
                icon: Icons.edit_rounded,
                label: 'Take Quiz',
                done: false,
                onTap: () =>
                    context.push('/exercises/$compositeExerciseId/quiz'),
              ),
              _ActionCard(
                icon: Icons.cloud_rounded,
                label: 'Weather Briefing',
                done: false,
                onTap: () => context
                    .push('/exercises/$compositeExerciseId/weather'),
              ),
              _ActionCard(
                icon: Icons.calendar_today_rounded,
                label: 'Schedule',
                done: false,
                onTap: () => context
                    .push('/exercises/$compositeExerciseId/schedule'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Content coming soon notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child:  Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Detailed content for this exercise is being added. The brief, quiz, and visualisation will be available soon.',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Log lesson button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context
                  .push('/exercises/$compositeExerciseId/debrief'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Check In After Lesson',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// First Solo (Exercise 14) motivational preparation section
// ---------------------------------------------------------------------------

class _FirstSoloMotivationalSection extends StatelessWidget {
  const _FirstSoloMotivationalSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.success.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.warning,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your First Solo',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is the moment every student pilot works towards. '
                'Your instructor believes you\'re ready.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Things to remember checklist
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Remember',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _SoloChecklistItem(text: 'Trust your training'),
              const SizedBox(height: 10),
              const _SoloChecklistItem(
                text: 'Fly the aircraft \u2014 don\'t let it fly you',
              ),
              const SizedBox(height: 10),
              const _SoloChecklistItem(
                text: 'Remember your checks: HASELL, pre-landing, downwind',
              ),
              const SizedBox(height: 10),
              const _SoloChecklistItem(
                text: 'Your instructor wouldn\'t send you solo if you weren\'t ready',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Key procedures reminder card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Key Procedures',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _SoloProcedureItem(
                icon: Icons.loop_rounded,
                text: 'Circuit pattern and radio calls',
              ),
              const SizedBox(height: 10),
              const _SoloProcedureItem(
                icon: Icons.flight_takeoff_rounded,
                text: 'Go-around procedure \u2014 always an option',
              ),
              const SizedBox(height: 10),
              const _SoloProcedureItem(
                icon: Icons.warning_amber_rounded,
                text: 'Emergency procedures you\'ve practised',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Encouragement footer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.thumb_up_alt_rounded, color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Text(
                'You\'ve Got This!',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoloChecklistItem extends StatelessWidget {
  final String text;
  const _SoloChecklistItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.success, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.onSurface, fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _SoloProcedureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SoloProcedureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.onSurface, fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

