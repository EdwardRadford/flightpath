import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

class TestPrepCountdownCard extends ConsumerWidget {
  const TestPrepCountdownCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final cs = Theme.of(context).colorScheme;

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        if (!user.isInTestPrepWindow) return const SizedBox.shrink();

        final daysLeft = user.skillsTestDate!.difference(DateTime.now()).inDays;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Semantics(
            label: 'Skills test in $daysLeft days — open test prep hub',
            button: true,
            child: GestureDetector(
              onTap: () => context.push('/test-prep'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skills test in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open test prep hub',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
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
