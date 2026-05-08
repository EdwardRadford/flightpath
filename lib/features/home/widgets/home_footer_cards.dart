// Home > Footer cards: Ask AI + Upgrade prompt + Debrief nudge.
// Extracted from home_screen.dart during 2026-04-13 refactor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/services/weather_service.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/home/providers/weather_preview_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

/// Shows a nudge to complete post-lesson notes when the user hasn't
/// debriefed in more than 3 days (or has never debriefed).
class DebriefNudgeCard extends ConsumerWidget {
  const DebriefNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    // Don't nudge users who have never flown — they can't debrief what hasn't happened.
    final lessons = ref.watch(allLessonsProvider).valueOrNull ?? [];
    final hasFlown = lessons.any((l) =>
        l.status == LessonStatus.completed || l.status == LessonStatus.manualEntry);
    if (!hasFlown) return const SizedBox.shrink();

    final lastDebrief = user.lastDebriefAt;
    final needsNudge = lastDebrief == null ||
        DateTime.now().difference(lastDebrief).inDays >= 3;

    if (!needsNudge) return const SizedBox.shrink();

    final userExercises = ref.watch(userExercisesProvider).valueOrNull ?? [];
    final UserExercise? mostRecent = userExercises.isEmpty
        ? null
        : userExercises
            .where((ue) => ue.lastAttempted != null)
            .fold<UserExercise?>(null, (best, ue) {
              if (best == null) return ue;
              return ue.lastAttempted!.isAfter(best.lastAttempted!) ? ue : best;
            });

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
      onTap: () {
        if (mostRecent == null) {
          context.push('/exercises');
          return;
        }
        final composite =
            compositeExerciseId(mostRecent.exerciseId, mostRecent.subExercise);
        context.push(
          '/exercises/$composite/notes',
          extra: {
            'exerciseId': mostRecent.exerciseId,
            'subExercise': mostRecent.subExercise,
          },
        );
      },
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.rate_review_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debrief your last lesson',
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'It only takes 2 minutes',
                    style: tt.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final streak = user.studyStreak;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  streak >= 2 ? '$streak day streak' : 'Start your streak',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  streak >= 2
                      ? 'Study today to keep it going'
                      : 'Open daily to build a streak',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class AskAiCard extends StatelessWidget {
  const AskAiCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
      onTap: () => context.push('/ask-ai'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ask Your AI Instructor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Answers to any PPL question',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Compact weather preview for the home screen.
///
/// Reads [weatherPreviewProvider] and renders nothing while loading or on error.
/// On data, shows the airfield ICAO, temperature + wind, and a VFR status badge.
/// Tapping navigates to `/tools/weather` where the full weather screen lives.
class WeatherPreviewCard extends ConsumerWidget {
  const WeatherPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherPreviewProvider);

    // Loading — no skeleton
    if (state.loading) return const SizedBox.shrink();

    // Non-reporting station — show a minimal tap-through card
    if (state.noDataForStation) {
      final icao = ref.watch(appUserProvider).valueOrNull?.airfieldIcao ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
        onTap: () => context.push('/tools/weather'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.wb_cloudy_outlined,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      icao.isNotEmpty ? icao.toUpperCase() : 'Weather',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      'No live data — tap to check nearby',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
      );
    }

    // Error or no data — hide
    if (state.data == null) return const SizedBox.shrink();

    final data = state.data!;
    final cs = Theme.of(context).colorScheme;

    // Determine VFR badge colour and label
    final (badgeColor, badgeLabel) = switch (data.flightCategory) {
      FlightCategory.vfr => (AppColors.success, 'VFR'),
      FlightCategory.mvfr => (AppColors.warning, 'MVFR'),
      FlightCategory.ifr => (AppColors.error, 'IFR'),
    };

    // Get the ICAO from the appUserProvider — same source the provider used
    final icao = ref.watch(appUserProvider).valueOrNull?.airfieldIcao ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
      onTap: () => context.push('/tools/weather'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.wb_sunny_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 12),

            // ICAO + temp/wind line
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icao.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            icao.toUpperCase(),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: badgeColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.temperature.round()}°C  ·  ${data.windSpeed}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class UpgradePromptCard extends ConsumerWidget {
  const UpgradePromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(appUserProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unlock All 19 Exercises',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "You're on the free plan. Upgrade once to unlock every exercise and AI debriefs.",
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                showPremiumPaywall(
                  context,
                  source: 'home_upgrade_prompt',
                  freeWindowStart: user?.freeWindowStart ?? 1,
                  freeWindowEnd: user?.freeWindowEnd ?? 3,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Upgrade to Pro — £${AppConstants.premiumPriceGbp.toStringAsFixed(2)}',
                style: tt.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
