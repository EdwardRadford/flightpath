// Exercise flight path journey map — visual serpentine path of all 19 CAA
// exercises with progress indicators, ratings, and sub-exercise branches.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/features/exercises/widgets/exercise_list/flight_path_body.dart';

// ---------------------------------------------------------------------------
// ExerciseListScreen
// ---------------------------------------------------------------------------

class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(userExercisesProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isPremium = appUser?.isPremium ?? false;
    final currentExerciseNumber = appUser?.currentExerciseNumber ?? 1;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.flight_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Flight Path',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: exercisesAsync.when(
        data: (userExercises) => FlightPathBody(
          userExercises: userExercises,
          isPremium: isPremium,
          currentExerciseNumber: currentExerciseNumber,
        ),
        loading: () => const ExerciseListLoadingBody(),
        error: (_, __) => const ExerciseListErrorBody(),
      ),
    );
  }
}
