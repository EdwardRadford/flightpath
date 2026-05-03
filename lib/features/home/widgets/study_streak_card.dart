import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

class StudyStreakCard extends ConsumerWidget {
  const StudyStreakCard({super.key});

  String _copy(int streak) {
    if (streak <= 3) {
      return 'You\'ve opened Flight Path Training ${streak == 1 ? '1 day' : '$streak days'} in a row.';
    } else if (streak <= 6) {
      return '$streak-day streak. The recommended cadence for steady PPL progression is 3–4 days a week.';
    } else {
      return '$streak-day streak. You\'re well above the recommended cadence — make sure your schedule allows the rest you need too.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final cs = Theme.of(context).colorScheme;

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final streak = user.studyStreak;
        if (streak == 0) return const SizedBox.shrink();
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
              _copy(streak),
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
