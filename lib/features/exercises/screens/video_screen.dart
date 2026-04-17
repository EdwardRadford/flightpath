// Video screen — opens the exercise video on YouTube via url_launcher.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

class VideoScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const VideoScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  bool _saving = false;

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    FirebaseAnalytics.instance.logEvent(
      name: 'video_played',
      parameters: {'exercise_id': widget.compositeExerciseId},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _markAsWatched() async {
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      final firestore = ref.read(firestoreServiceProvider);
      final userExercises =
          ref.read(userExercisesProvider).valueOrNull ?? [];

      final existing = userExercises
          .where((ue) =>
              ue.exerciseId == exerciseId &&
              ue.subExercise == subExerciseId)
          .firstOrNull;

      final exerciseNum =
          existing?.exerciseNumber ?? _exerciseNumberFrom(exerciseId);

      await firestore.upsertUserExercise(
        uid,
        UserExercise(
          id: existing?.id ??
              (subExerciseId != null
                  ? '${uid}_${exerciseId}_$subExerciseId'
                  : '${uid}_$exerciseId'),
          exerciseId: exerciseId,
          subExercise: subExerciseId,
          exerciseNumber: exerciseNum,
          status: existing?.status ?? ExerciseStatus.notStarted,
          bestRating: existing?.bestRating,
          ratingHistory: existing?.ratingHistory ?? [],
          timesAttempted: existing?.timesAttempted ?? 0,
          lastAttempted: existing?.lastAttempted,
          spacedRepDue: existing?.spacedRepDue,
          videoWatched: true,
          briefViewed: existing?.briefViewed ?? false,
          flashcardsCompleted: existing?.flashcardsCompleted ?? false,
          weatherChecked: existing?.weatherChecked ?? false,
          quizPassed: existing?.quizPassed ?? false,
          quizAttempted: existing?.quizAttempted ?? false,
          visualisationViewed: existing?.visualisationViewed ?? false,
        ),
      );

      FirebaseAnalytics.instance.logEvent(
        name: 'video_watched',
        parameters: {'exercise_id': widget.compositeExerciseId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video marked as watched'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _exerciseNumberFrom(String exerciseId) {
    final parts = exerciseId.split('_');
    if (parts.length >= 2) return int.tryParse(parts[1]) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    final contentAsync =
        ref.watch(exerciseContentProvider((exerciseId, subExerciseId)));
    final userExercisesAsync = ref.watch(userExercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Video'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: contentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Unable to load video. Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (content) {
          if (content == null) {
            return const Center(child: Text('Video content not available.'));
          }

          final String videoUrl = content.videoUrl.isNotEmpty
              ? content.videoUrl
              : content.backupVideoUrl;
          final bool hasVideo = videoUrl.isNotEmpty;

          final bool videoWatched = userExercisesAsync.whenOrNull(
                data: (list) => list
                    .where((ue) =>
                        ue.exerciseId == exerciseId &&
                        ue.subExercise == subExerciseId)
                    .firstOrNull
                    ?.videoWatched,
              ) ??
              false;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                if (content.overview.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      content.overview,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),

                const SizedBox(height: 32),

                // Watch on YouTube
                if (hasVideo)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: const Text('Watch on YouTube'),
                      onPressed: () => _openVideo(videoUrl),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Mark as Watched
                SizedBox(
                  width: double.infinity,
                  child: videoWatched
                      ? ElevatedButton.icon(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.check_circle_rounded,
                              color: Colors.white),
                          label: const Text('Watched'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _saving ? null : _markAsWatched,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(_saving ? 'Saving...' : 'Mark as Watched'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
