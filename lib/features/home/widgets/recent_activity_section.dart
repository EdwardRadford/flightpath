// Home > Recent activity section (list of latest lessons).
// Extracted from home_screen.dart during 2026-04-13 refactor.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

class RecentActivitySection extends StatelessWidget {
  final List<Lesson> lessons;
  const RecentActivitySection({super.key, required this.lessons});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (lessons.isEmpty) {
      return const EmptyRecentActivity();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with "View All"
        Row(
          children: [
            const Icon(Icons.history_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Recent Activity',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            TextButton(
              onPressed: () => context.push('/logbook'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Lesson list
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: lessons.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: cs.outline,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) =>
                _LessonListItem(lesson: lessons[index]),
          ),
        ),
      ],
    );
  }
}

class EmptyRecentActivity extends StatelessWidget {
  const EmptyRecentActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flight_takeoff_rounded,
            color: AppColors.primary.withValues(alpha: 0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Ready for your first lesson?',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Start by exploring the exercises to build your preparation plan.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.55),
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => context.push('/exercises'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBright,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Browse Exercises',
                style: TextStyle(
                  fontSize: 14,
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

class RecentActivityLoading extends StatelessWidget {
  const RecentActivityLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _LessonListItem extends StatelessWidget {
  final Lesson lesson;
  const _LessonListItem({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compositeId = lesson.subExercise.isNotEmpty
        ? '${lesson.exerciseId}_${lesson.subExercise}'
        : lesson.exerciseId;
    final displayName = exerciseDisplayName(compositeId);
    final date =
        lesson.lessonDate ?? lesson.scheduledDate ?? lesson.createdAt;
    final formattedDate = DateFormat('dd MMM yyyy').format(date);

    return InkWell(
      onTap: () => context.push('/lesson-detail', extra: lesson),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _statusColor(lesson.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(formattedDate,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          )),
                      if (lesson.status == LessonStatus.completed &&
                          lesson.studentRating != null) ...[
                        const SizedBox(width: 10),
                        _StarRating(rating: lesson.studentRating!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(LessonStatus status) {
    switch (status) {
      case LessonStatus.scheduled:
        return AppColors.statusScheduled;
      case LessonStatus.prepared:
        return AppColors.warning;
      case LessonStatus.completed:
        return AppColors.success;
      case LessonStatus.cancelled:
        return AppColors.onSurfaceVariant;
      case LessonStatus.manualEntry:
        return AppColors.statusManualEntry;
    }
  }
}

class _StarRating extends StatelessWidget {
  final int rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: AppColors.warning, size: 13),
        const SizedBox(width: 2),
        Text('$rating/5',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              fontSize: 12,
            )),
      ],
    );
  }
}
