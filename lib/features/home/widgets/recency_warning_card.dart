// Recency warning card — shown on the home screen when the user's last flight was more than 14 days ago; taps through to Before You Fly.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/exercises/widgets/exercise_list/flight_path_body.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

class RecencyWarningCard extends ConsumerWidget {
  const RecencyWarningCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userExercises = ref.watch(userExercisesProvider).valueOrNull ?? [];
    if (userExercises.isEmpty) return const SizedBox.shrink();

    final currentIndex = findCurrentExerciseIndex(userExercises);
    final currentItem = kExercises[currentIndex];

    UserExercise? ue;
    if (currentItem.hasSubExercises) {
      ue = findExerciseInList(
          userExercises, currentItem.exerciseId, currentItem.subExercises.first.subId);
    } else {
      ue = findExerciseInList(userExercises, currentItem.exerciseId);
    }

    if (ue == null || ue.lastAttempted == null) return const SizedBox.shrink();

    final daysSince = DateTime.now().difference(ue.lastAttempted!).inDays;
    // 14-day threshold matches CAA recency guidance for student pilots.
    if (daysSince <= 14) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final compositeId = compositeExerciseId(ue.exerciseId, ue.subExercise);

    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
      onTap: () => context.push('/exercises/$compositeId/before-you-fly'),
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
            Icon(Icons.schedule_rounded,
                color: AppColors.warning, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Recency check',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      )),
                  Text('Last flight $daysSince days ago — review before next lesson',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      )),
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
