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

        String copy;
        if (weekLessons.isNotEmpty) {
          final n = weekLessons.length;
          final ratings = weekLessons
              .where((l) => l.studentRating != null)
              .map((l) => l.studentRating!);
          final avgRating = ratings.isEmpty
              ? null
              : ratings.reduce((a, b) => a + b) / ratings.length;
          copy = 'Since 7 days ago: $n lesson${n == 1 ? '' : 's'} logged'
              '${avgRating != null ? ', average rating ${avgRating.toStringAsFixed(1)}/5' : ''}.';
        } else {
          copy = 'No lessons this week. A flashcard session is a useful way to keep momentum.';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              copy,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
