// Home > Current exercise card (replaces legacy "Next Lesson Hero").
// Extracted from home_screen.dart during 2026-04-13 refactor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/home/providers/home_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/rating_sparkline.dart';

String _exerciseRoute(String exerciseId, String? subExerciseId) {
  if (subExerciseId != null) {
    return '/exercises/${exerciseId}_$subExerciseId';
  }
  return '/exercises/$exerciseId';
}

class CurrentExerciseCard extends StatelessWidget {
  final AsyncValue<SuggestedExercise?> suggestedExercise;
  final WidgetRef ref;

  const CurrentExerciseCard({
    super.key,
    required this.suggestedExercise,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: suggestedExercise.when(
        data: (suggested) => _buildCard(context, suggested),
        loading: () => _buildLoadingCard(context),
        error: (_, __) => _buildCard(context, null),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildCard(BuildContext context, SuggestedExercise? suggested) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // No suggested exercise — all complete or no data
    if (suggested == null) {
      return _buildAllCompleteCard(context, cs, isDark);
    }

    final compositeId = suggested.subExerciseId != null
        ? '${suggested.exerciseId}_${suggested.subExerciseId}'
        : suggested.exerciseId;
    final displayName = exerciseDisplayName(compositeId);
    final fullName = exerciseFullName(compositeId);
    final routePath =
        _exerciseRoute(suggested.exerciseId, suggested.subExerciseId);

    // Look up prep progress
    final userExercises =
        ref.watch(userExercisesProvider).valueOrNull ?? [];
    UserExercise? matchingUe;
    for (final ue in userExercises) {
      if (compositeExerciseId(ue.exerciseId, ue.subExercise) ==
          compositeId) {
        matchingUe = ue;
        break;
      }
    }

    final briefDone = matchingUe != null && matchingUe.timesAttempted > 0;
    final quizDone = matchingUe?.quizPassed ?? false;
    final videoDone = matchingUe?.videoWatched ?? false;

    final prepItems = [
      (label: 'Brief', done: briefDone, icon: Icons.menu_book_rounded),
      (label: 'Quiz', done: quizDone, icon: Icons.quiz_rounded),
      (label: 'Video', done: videoDone, icon: Icons.play_circle_rounded),
    ];
    final doneCount = prepItems.where((item) => item.done).length;
    final allPrepped = doneCount == prepItems.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  AppColors.heroGradientStart,
                  AppColors.heroGradientEnd,
                ]
              : [AppColors.primaryLight, AppColors.surfaceVariantLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT EXERCISE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        suggested.reason,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Exercise name
            Text(
              displayName,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (fullName != displayName) ...[
              const SizedBox(height: 4),
              Text(
                fullName,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Prep progress indicators
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        allPrepped
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        color: allPrepped
                            ? AppColors.success
                            : AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        allPrepped
                            ? 'Preparation Complete'
                            : '$doneCount of ${prepItems.length} completed',
                        style: TextStyle(
                          color: allPrepped
                              ? AppColors.success
                              : AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < prepItems.length; i++) ...[
                        if (i > 0) const Spacer(),
                        _PrepCheckItem(
                          label: prepItems[i].label,
                          done: prepItems[i].done,
                          icon: prepItems[i].icon,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Rating trend sparkline — only shown when >= 2 ratings exist
            if ((matchingUe?.ratingHistory.length ?? 0) >= 2) ...[
              const SizedBox(height: 16),
              Text(
                'Rating trend',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              RatingSparkline(ratings: matchingUe!.ratingHistory),
            ],

            const SizedBox(height: 16),

            // CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(routePath),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      allPrepped ? AppColors.success : AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allPrepped
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      allPrepped ? "You're Ready!" : 'Continue Preparing',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCompleteCard(
      BuildContext context, ColorScheme cs, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  AppColors.heroGradientStart,
                  AppColors.heroGradientEnd,
                ]
              : [AppColors.primaryLight, AppColors.surfaceVariantLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'All Exercises Complete',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Great work! Review your progress or revisit any exercise from the exercises tab.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/progress'),
              icon: const Icon(Icons.insights_rounded, size: 18),
              label: const Text('View Progress',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrepCheckItem extends StatelessWidget {
  final String label;
  final bool done;
  final IconData icon;
  const _PrepCheckItem({
    required this.label,
    required this.done,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${done ? 'completed' : 'not completed'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? AppColors.success : AppColors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: done ? AppColors.success : AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
