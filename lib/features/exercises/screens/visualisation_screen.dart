// Visualisation screen — guided mental rehearsal script with elapsed timer.
import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/micro_animations.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Guided visualisation with a live timer and auto-scroll script.
class VisualisationScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const VisualisationScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<VisualisationScreen> createState() =>
      _VisualisationScreenState();
}

class _VisualisationScreenState extends ConsumerState<VisualisationScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = _stopwatch.elapsed);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _markVisualisationViewed() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);
    final exercises = ref.read(userExercisesProvider).valueOrNull ?? [];
    final existing = exercises
        .where((ue) =>
            ue.exerciseId == exerciseId && ue.subExercise == subExerciseId)
        .firstOrNull;
    final firestore = ref.read(firestoreServiceProvider);
    await firestore.upsertUserExercise(
      uid,
      UserExercise(
        id: existing?.id ?? '',
        exerciseId: exerciseId,
        subExercise: subExerciseId,
        exerciseNumber: existing?.exerciseNumber ?? 0,
        status: existing?.status ?? ExerciseStatus.notStarted,
        bestRating: existing?.bestRating,
        timesAttempted: existing?.timesAttempted ?? 0,
        ratingHistory: existing?.ratingHistory ?? [],
        lastAttempted: existing?.lastAttempted,
        videoWatched: existing?.videoWatched ?? false,
        briefViewed: existing?.briefViewed ?? false,
        flashcardsCompleted: existing?.flashcardsCompleted ?? false,
        weatherChecked: existing?.weatherChecked ?? false,
        quizPassed: existing?.quizPassed ?? false,
        quizAttempted: existing?.quizAttempted ?? false,
        visualisationViewed: true,
        spacedRepDue: existing?.spacedRepDue,
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    final contentAsync =
        ref.watch(exerciseContentProvider((exerciseId, subExerciseId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualisation'),
        actions: [
          // Elapsed timer chip in the app bar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: AppColors.onSurfaceVariant,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatElapsed(_elapsed),
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: contentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Unable to load visualisation. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ),
        data: (content) {
          if (content == null) {
            return Center(
              child: Text(
                'Visualisation content not available.',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Airplane icon with instrument bezel
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.15),
                              AppColors.primary.withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.flight_rounded,
                          color: AppColors.primary,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Exercise name
                      Text(
                        content.exerciseName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Prompt text
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Close your eyes and work through the exercise in your mind',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Visualisation script
                      if (content.visualisationScript.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            content.visualisationScript,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 15,
                              height: 1.8,
                              letterSpacing: 0.2,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Take a few minutes to mentally rehearse the exercise '
                            'from start to finish. Visualise each manoeuvre, the '
                            'checks you will perform, and how you will respond to '
                            'any unexpected situations.',
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 15,
                              height: 1.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Mark as Complete button with check animation
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                child: AnimatedCheckButton(
                  label: 'Mark as Complete',
                  icon: Icons.check_rounded,
                  onComplete: () {
                    _markVisualisationViewed();
                    FirebaseAnalytics.instance.logEvent(
                      name: 'visualisation_completed',
                      parameters: {
                        'exercise_id': widget.compositeExerciseId,
                        'duration_seconds': _stopwatch.elapsed.inSeconds,
                      },
                    );
                    FirebaseAnalytics.instance.logEvent(
                      name: 'active_recall_completed',
                      parameters: {
                        'exercise_id': widget.compositeExerciseId,
                        'duration_seconds': _stopwatch.elapsed.inSeconds,
                      },
                    );
                    context.pop();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
