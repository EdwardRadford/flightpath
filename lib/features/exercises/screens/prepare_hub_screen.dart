// Prepare hub screen — central dashboard for a single exercise showing
// brief, quiz, visualisation, video, and schedule options.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:flight_path/features/exercises/widgets/prepare_hub/exercise_header.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/first_solo_motivational_section.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/lesson_button.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/paywall_banner.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/prepare_hub_misc.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/progress_card.dart';
import 'package:flight_path/features/exercises/widgets/prepare_hub/stepped_prepare_checklist.dart';

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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Exercise header
          ExerciseHeader(content: content),
          const SizedBox(height: 16),

          // 2. Progress card
          ProgressCard(userExercise: userExercise),
          const SizedBox(height: 16),

          // 2b. Paywall banner
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
            const SizedBox(height: 16),
          ],

          // 2c. First Solo motivational section
          if (content.lessonType == LessonType.milestone) ...[
            const FirstSoloMotivationalSection(),
            const SizedBox(height: 16),
          ],

          // 3. Prepare checklist
          const PrepareHubSectionLabel(label: 'PREPARE'),
          const SizedBox(height: 8),
          SteppedPrepareChecklist(
            compositeExerciseId: compositeExerciseId,
            lessonType: content.lessonType,
            userExercise: userExercise,
            quizPassed: quizPassed,
            locked: !isPremium,
          ),
          const SizedBox(height: 28),

          // 4. Log / Start button
          LessonButton(
            compositeExerciseId: compositeExerciseId,
            exerciseId: exerciseId,
            subExerciseId: subExerciseId,
            hasLessons: hasLessons,
            locked: !isPremium,
          ),
          const SizedBox(height: 20),

          // 5. Revision mode banner
          const PrepareHubSectionLabel(label: 'REVISION'),
          const SizedBox(height: 8),
          const PrepareHubRevisionBanner(),
        ],
      ),
    );
  }
}
