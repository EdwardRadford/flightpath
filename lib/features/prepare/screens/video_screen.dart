// Video screen — embedded YouTube player with primary/backup URL fallback.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// YouTube video player with automatic fallback to a backup URL.
class VideoScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const VideoScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  YoutubePlayerController? _controller;
  bool _primaryFailed = false;
  bool _backupFailed = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Tries to extract a YouTube video ID from the given URL.
  /// Returns null if it's not a valid YouTube URL.
  String? _extractVideoId(String url) {
    if (url.isEmpty) return null;
    return YoutubePlayer.convertUrlToId(url);
  }

  /// Initialise or reinitialise the YouTube controller with the given URL.
  void _initController(String videoUrl) {
    final videoId = _extractVideoId(videoUrl);
    if (videoId == null) return;

    _controller?.dispose();
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        controlsVisibleAtStart: true,
      ),
    );
    _controller!.addListener(() {
      if (_controller!.value.hasError && mounted) {
        _onPlayerError();
      }
    });
  }

  void _onPlayerError() {
    if (!_primaryFailed) {
      setState(() => _primaryFailed = true);
      // Attempt backup — the build method will pick it up
    } else {
      setState(() => _backupFailed = true);
    }
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

      final exerciseNum = existing?.exerciseNumber ??
          _exerciseNumberFrom(exerciseId);

      await firestore.upsertUserExercise(UserExercise(
        id: subExerciseId != null
            ? '${uid}_${exerciseId}_$subExerciseId'
            : '${uid}_$exerciseId',
        userId: uid,
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
        visualisationViewed: existing?.visualisationViewed ?? false,
      ));

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
        error: (_, _) =>  Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Unable to load video. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
            ),
          ),
        ),
        data: (content) {
          if (content == null) {
            return  Center(
              child: Text(
                'Video content not available.',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            );
          }

          // Determine which URL to use
          final String primaryUrl = content.videoUrl;
          final String backupUrl = content.backupVideoUrl;
          final bool hasPrimary =
              !_primaryFailed && _extractVideoId(primaryUrl) != null;
          final bool hasBackup =
              !_backupFailed && _extractVideoId(backupUrl) != null;

          final String? activeUrl = hasPrimary
              ? primaryUrl
              : hasBackup
                  ? backupUrl
                  : null;

          // Initialise controller if we have a valid URL
          if (activeUrl != null && _controller == null) {
            _initController(activeUrl);
          } else if (activeUrl != null &&
              _primaryFailed &&
              !_backupFailed &&
              _controller != null) {
            // Switch to backup
            _initController(activeUrl);
          }

          // Resolve the matching UserExercise
          final bool videoWatched = userExercisesAsync.whenOrNull(
                data: (list) => list
                    .where((ue) =>
                        ue.exerciseId == exerciseId &&
                        ue.subExercise == subExerciseId)
                    .firstOrNull
                    ?.videoWatched,
              ) ??
              false;

          return Column(
            children: [
              // Video player or fallback
              if (activeUrl != null && _controller != null)
                YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: AppColors.primary,
                  progressColors: const ProgressBarColors(
                    playedColor: AppColors.primary,
                    handleColor: AppColors.primary,
                  ),
                )
              else
                _VideoUnavailable(),

              // Content below video
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exercise name
                      Text(
                        content.displayName,
                        style:  TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description (overview)
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
                            style:  TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Using backup notice
                      if (_primaryFailed && hasBackup)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.warning
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child:  Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: AppColors.warning, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Playing backup video — primary was unavailable.',
                                    style: TextStyle(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Mark as Watched button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                child: SizedBox(
                  width: double.infinity,
                  child: videoWatched
                      ? ElevatedButton.icon(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.check_circle_rounded,
                              color: Colors.white),
                          label: const Text(
                            'Watched',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                          label: Text(
                            _saving
                                ? 'Saving...'
                                : 'Mark as Watched',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video Unavailable fallback
// ---------------------------------------------------------------------------

class _VideoUnavailable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        width: double.infinity,
        color: AppColors.surface,
        child:  Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                color: AppColors.onSurfaceVariant,
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'Video temporarily unavailable',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
