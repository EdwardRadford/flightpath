// Lesson Day screen (/lesson-day) — pre-flight checklist that walks the user through Weather, ATIS, and Before You Fly before marking them ready to fly.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/exercises/widgets/exercise_list/flight_path_body.dart';

class LessonDayScreen extends ConsumerStatefulWidget {
  const LessonDayScreen({super.key});

  @override
  ConsumerState<LessonDayScreen> createState() => _LessonDayScreenState();
}

class _LessonDayScreenState extends ConsumerState<LessonDayScreen> {
  final Set<int> _completedSteps = {};

  @override
  Widget build(BuildContext context) {
    final userExercises = ref.watch(userExercisesProvider).valueOrNull ?? [];
    final currentIndex = findCurrentExerciseIndex(userExercises);
    final currentItem = kExercises[currentIndex];

    String currentExerciseId;
    if (currentItem.hasSubExercises) {
      final subId = currentItem.subExercises.first.subId;
      currentExerciseId = '${currentItem.exerciseId}_$subId';
    } else {
      currentExerciseId = currentItem.exerciseId;
    }

    final steps = [
      _StepData(
        icon: Icons.wb_sunny_rounded,
        title: 'Weather',
        subtitle: 'Check conditions at your home airfield',
        route: '/tools/weather',
      ),
      _StepData(
        icon: Icons.radio_rounded,
        title: 'ATIS',
        subtitle: 'Get the current ATIS',
        route: '/learn/atis',
      ),
      _StepData(
        icon: Icons.menu_book_rounded,
        title: 'Before You Fly',
        subtitle: 'Review your exercise brief',
        route: '/exercises/$currentExerciseId/before-you-fly',
      ),
    ];

    final allComplete = _completedSteps.length == steps.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-flight Prep'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              for (int i = 0; i < steps.length; i++) ...[
                _StepCard(
                  step: i + 1,
                  data: steps[i],
                  completed: _completedSteps.contains(i),
                  onTap: () {
                    // Mark complete before pushing so the tick is visible if the
                    // user swipes back rather than using the in-screen button.
                    setState(() => _completedSteps.add(i));
                    context.push(steps[i].route);
                  },
                ),
                const SizedBox(height: 12),
              ],
              const Spacer(),
              if (allComplete) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Ready to fly',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _StepData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

class _StepCard extends StatelessWidget {
  final int step;
  final _StepData data;
  final bool completed;
  final VoidCallback onTap;

  const _StepCard({
    required this.step,
    required this.data,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: completed
                ? AppColors.success.withValues(alpha: 0.4)
                : cs.outline,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(data.icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            completed
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 22,
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.3),
                    size: 22,
                  ),
          ],
        ),
      ),
    );
  }
}
