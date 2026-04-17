import 'package:flutter/material.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/exercise_content.dart';

class ExerciseHeader extends StatelessWidget {
  final ExerciseContent content;

  const ExerciseHeader({super.key, required this.content});

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
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content.exerciseName,
            style: TextStyle(
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
