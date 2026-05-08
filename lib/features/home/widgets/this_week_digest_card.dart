import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/home/providers/home_provider.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

class ThisWeekDigestCard extends ConsumerWidget {
  const ThisWeekDigestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentLessonsProvider);
    final userAsync = ref.watch(appUserProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return recentAsync.when(
      data: (lessons) {
        final user = userAsync.valueOrNull;
        if (user == null) return const SizedBox.shrink();

        // Filter to last 7 days
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        final weekLessons = lessons
            .where((l) => l.lessonDate != null && l.lessonDate!.isAfter(cutoff))
            .toList();

        // Only show if user has 3+ days of streak (proxy for 3+ days activity)
        if (user.studyStreak < 3 && weekLessons.isEmpty) {
          return const SizedBox.shrink();
        }

        String title;
        String subtitle;
        if (weekLessons.isNotEmpty) {
          final n = weekLessons.length;
          final ratings = weekLessons
              .where((l) => l.studentRating != null)
              .map((l) => l.studentRating!);
          final avgRating = ratings.isEmpty
              ? null
              : ratings.reduce((a, b) => a + b) / ratings.length;
          title = 'This week: $n lesson${n == 1 ? '' : 's'}';
          subtitle = avgRating != null
              ? 'Average rating ${avgRating.toStringAsFixed(1)}/5.'
              : 'Logged in the last 7 days.';
        } else {
          title = 'No lessons this week';
          subtitle = 'A flashcard session keeps momentum.';
        }

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
                Icon(Icons.calendar_view_week_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          )),
                      Text(subtitle,
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
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
