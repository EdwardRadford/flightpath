import 'package:flutter/material.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/widgets/rating_sparkline.dart';

class ProgressCard extends StatelessWidget {
  final UserExercise? userExercise;

  const ProgressCard({super.key, required this.userExercise});

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
        child: Row(
          children: [
            Icon(Icons.flag_outlined,
                color: AppColors.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
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
      case ExerciseStatus.completedUnsatisfactory:
        statusLabel = 'Completed (Unsatisfactory)';
        statusColor = AppColors.warning;
        break;
      case ExerciseStatus.completedSatisfactory:
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  style: TextStyle(
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
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          // Rating trendline sparkline — shown when 2+ ratings exist
          if (ue.ratingHistory.length > 1) ...[
            const SizedBox(height: 12),
            RatingSparkline(
              ratings: ue.ratingHistory,
            ),
          ],
        ],
      ),
    );
  }
}
