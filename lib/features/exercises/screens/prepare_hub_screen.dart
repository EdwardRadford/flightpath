// Prepare hub screen — central dashboard for a single exercise showing
// the prepare checklist (brief / flashcards / before-you-fly / weather /
// self-brief), contextual tools, lesson logging, and revision entry point.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/constants/exercise_criteria.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/exercise_header.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/first_solo_motivational_section.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/lesson_button.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/paywall_banner.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/prepare_hub_misc.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/progress_card.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/stepped_prepare_checklist.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/exercise_tools_row.dart';
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
      error: (_, __) => Scaffold(
        body: PrepareHubErrorBody(
          message:
              'Unable to load exercise content. Please check your connection and try again.',
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
          return Scaffold(
            appBar: AppBar(
              title: Text(exerciseFullName(compositeExerciseId)),
            ),
            body: PrepareHubPlaceholderBody(
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
              data: (list) =>
                  list.where((l) => l.exerciseId == exerciseId).toList(),
            ) ??
            [];

        final bool hasLessons = exerciseLessons.isNotEmpty;

        // Determine if quiz was ever passed at CAA standard (75%)
        final bool quizPassed = exerciseLessons.any(
            (l) => l.quizScore >= AppConstants.quizPassThreshold);

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
                  final url =
                      'https://getflightpath.app/exercise/$compositeExerciseId';
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
// Body
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
    final exerciseLabel = content.subExercise != null
        ? 'Exercise ${content.subExercise}'
        : 'Exercise ${content.exerciseNumber}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header
          ExerciseHeader(content: content),
          const SizedBox(height: 8),

          // Ask AI chip
          ActionChip(
            avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text('Ask AI about $exerciseLabel'),
            onPressed: () {
              if (!isPremium) {
                showPremiumPaywall(
                  context,
                  source: 'ask_ai_chip',
                  freeWindowStart: freeWindowStart,
                  freeWindowEnd: freeWindowEnd,
                );
                return;
              }
              context.push(
                '/ask-ai',
                extra:
                    'Tell me about $exerciseLabel: ${content.exerciseName}',
              );
            },
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            labelStyle: TextStyle(
              color: isPremium
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
            iconTheme: IconThemeData(
              color: isPremium
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Progress card
          ProgressCard(userExercise: userExercise),
          const SizedBox(height: 16),

          // Paywall banner + objectives preview (free users only)
          if (!isPremium) ...[
            PaywallBanner(
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
            const SizedBox(height: 12),
            if (content.aim.isNotEmpty)
              _LockedObjectivesPreview(aim: content.aim),
            const SizedBox(height: 16),
          ],

          // First Solo milestone block (Exercise 14 only)
          if (content.lessonType == LessonType.milestone) ...[
            const FirstSoloMotivationalSection(),
            const SizedBox(height: 12),
            const FirstSoloInfoCards(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/exercises/pre-solo-readiness?exerciseId=$compositeExerciseId',
                ),
                icon: const Icon(Icons.checklist_rounded, size: 20),
                label: const Text('Pre-Solo Readiness Check'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Today's Expectations — CAA assessment criteria
          if (ExerciseCriteria.exerciseCriteria
              .containsKey(compositeExerciseId)) ...[
            _TodaysExpectationsSection(
              compositeExerciseId: compositeExerciseId,
            ),
            const SizedBox(height: 20),
          ],

          // Prepare checklist
          const PrepareHubSectionLabel(label: 'PREPARE'),
          const SizedBox(height: 8),
          SteppedPrepareChecklist(
            compositeExerciseId: compositeExerciseId,
            lessonType: content.lessonType,
            userExercise: userExercise,
            quizPassed: quizPassed,
            locked: !isPremium,
            content: content,
          ),
          const SizedBox(height: 28),

          // Tools row — contextual shortcuts to relevant tools for this exercise
          const PrepareHubSectionLabel(label: 'TOOLS'),
          const SizedBox(height: 8),
          ExerciseToolsRow(
            exerciseId: exerciseId,
            isPremium: isPremium,
          ),
          const SizedBox(height: 20),

          // Log / Start button
          LessonButton(
            compositeExerciseId: compositeExerciseId,
            exerciseId: exerciseId,
            subExerciseId: subExerciseId,
            hasLessons: hasLessons,
            locked: !isPremium,
          ),
          const SizedBox(height: 20),

          // After-lesson actions — review past lessons or generate an AI debrief.
          const PrepareHubSectionLabel(label: 'AFTER YOUR LESSON'),
          const SizedBox(height: 8),
          PrepareHubAfterLessonCard(
            icon: Icons.history_rounded,
            title: 'Review Relevant Lessons',
            subtitle:
                'Open the logbook filtered to lessons covering this exercise.',
            onTap: () => context.go(
              '/logbook?exerciseId=$compositeExerciseId',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's Expectations — CAA criteria
// ---------------------------------------------------------------------------

class _TodaysExpectationsSection extends StatelessWidget {
  final String compositeExerciseId;

  const _TodaysExpectationsSection({required this.compositeExerciseId});

  @override
  Widget build(BuildContext context) {
    final criteria =
        ExerciseCriteria.exerciseCriteria[compositeExerciseId] ?? const [];
    if (criteria.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "TODAY'S EXPECTATIONS",
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'What your instructor will assess',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ...criteria.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      c.label,
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked objectives preview
// ---------------------------------------------------------------------------

/// Shows the exercise aim as a "What you'll learn" preview card when the
/// exercise is locked. Read-only — no actual content is unlocked.
class _LockedObjectivesPreview extends StatelessWidget {
  final String aim;

  const _LockedObjectivesPreview({required this.aim});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: 0.8,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'What you\'ll learn',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              aim,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
