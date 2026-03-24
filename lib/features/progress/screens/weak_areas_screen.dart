// Weak Areas screen — analyses quiz performance across all exercises and
// highlights where the student is weakest, sorted by lowest average score.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// Data model for per-exercise quiz stats
// ---------------------------------------------------------------------------

class _ExerciseQuizStats {
  final String compositeExerciseId;
  final String displayName;
  final List<int> scores; // chronological quiz scores
  final int attemptCount;

  _ExerciseQuizStats({
    required this.compositeExerciseId,
    required this.displayName,
    required this.scores,
  }) : attemptCount = scores.length;

  double get averageScore =>
      scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;

  /// Trend: compare second half average to first half average.
  /// Returns positive if improving, negative if declining, null if < 2 attempts.
  double? get trend {
    if (scores.length < 2) return null;
    final mid = scores.length ~/ 2;
    final firstHalf = scores.sublist(0, mid);
    final secondHalf = scores.sublist(mid);
    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    return secondAvg - firstAvg;
  }

  String get trendLabel {
    final t = trend;
    if (t == null) return '--';
    if (t > 3) return 'Improving';
    if (t < -3) return 'Declining';
    return 'Steady';
  }

  IconData get trendIcon {
    final t = trend;
    if (t == null) return Icons.remove_rounded;
    if (t > 3) return Icons.trending_up_rounded;
    if (t < -3) return Icons.trending_down_rounded;
    return Icons.trending_flat_rounded;
  }

  Color get trendColor {
    final t = trend;
    if (t == null) return AppColors.onSurfaceVariant;
    if (t > 3) return AppColors.success;
    if (t < -3) return AppColors.error;
    return AppColors.warning;
  }

  Color get scoreColor {
    final avg = averageScore;
    if (avg < 50) return AppColors.error;
    if (avg < 70) return AppColors.warning;
    return AppColors.success;
  }

  String get scoreLabel {
    if (averageScore < 50) return 'Weak';
    if (averageScore < 70) return 'Developing';
    return 'Strong';
  }
}

// ---------------------------------------------------------------------------
// Helper: build composite exercise ID from lesson
// ---------------------------------------------------------------------------

String _lessonCompositeId(Lesson lesson) {
  if (lesson.subExercise != null) {
    return '${lesson.exerciseId}_${lesson.subExercise}';
  }
  return lesson.exerciseId;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class WeakAreasScreen extends ConsumerStatefulWidget {
  const WeakAreasScreen({super.key});

  @override
  ConsumerState<WeakAreasScreen> createState() => _WeakAreasScreenState();
}

class _WeakAreasScreenState extends ConsumerState<WeakAreasScreen> {
  bool _analyticsLogged = false;

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(allLessonsProvider);

    if (!_analyticsLogged) {
      _analyticsLogged = true;
      FirebaseAnalytics.instance.logEvent(name: 'weak_areas_viewed');
    }

    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Weak Areas'),
        
        elevation: 0,
      ),
      body: lessonsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, _) =>  Center(
          child: Text(
            'Unable to load quiz data. Please try again.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        data: (lessons) => _buildBody(lessons),
      ),
    );
  }

  Widget _buildBody(List<Lesson> lessons) {
    // Filter to lessons that have quiz scores
    final lessonsWithQuiz =
        lessons.where((l) => l.quizScore != null).toList();

    if (lessonsWithQuiz.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.quiz_rounded,
        title: 'Complete your first quiz to see insights here',
        subtitle:
            'Once you take a quiz, we\'ll track your scores and highlight which exercises need extra attention.',
        buttonText: 'Browse Exercises',
        onButtonPressed: () => context.push('/exercises'),
      );
    }

    // Group quiz scores by composite exercise ID, keeping chronological order
    final Map<String, List<int>> scoresByExercise = {};
    // Process oldest first so scores list is chronological
    for (final lesson in lessonsWithQuiz.reversed) {
      final id = _lessonCompositeId(lesson);
      scoresByExercise.putIfAbsent(id, () => []);
      scoresByExercise[id]!.add(lesson.quizScore!);
    }

    // Build stats list
    final stats = scoresByExercise.entries.map((entry) {
      return _ExerciseQuizStats(
        compositeExerciseId: entry.key,
        displayName: exerciseLongName(entry.key),
        scores: entry.value,
      );
    }).toList();

    // Sort by weakest first (lowest average score)
    stats.sort((a, b) => a.averageScore.compareTo(b.averageScore));

    // Calculate overall average
    final allScores = lessonsWithQuiz.map((l) => l.quizScore!).toList();
    final overallAverage = allScores.reduce((a, b) => a + b) / allScores.length;

    // Build the top insight message about weakest exercise
    final weakest = stats.first;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insight message about weakest area
          if (weakest.averageScore < 70)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You struggle most with ${weakest.displayName} (${weakest.averageScore.round()}% avg). Focus your revision here.',
                      style:  TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Overall average card
          _OverallAverageCard(
            average: overallAverage,
            totalAttempts: allScores.length,
            exerciseCount: stats.length,
          ),
          const SizedBox(height: 24),

          // Section label
           Text(
            'By Exercise',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
           Text(
            'Sorted by weakest first',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Per-exercise cards
          ...stats.map((stat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExerciseQuizCard(stat: stat),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overall average card
// ---------------------------------------------------------------------------

class _OverallAverageCard extends StatelessWidget {
  final double average;
  final int totalAttempts;
  final int exerciseCount;

  const _OverallAverageCard({
    required this.average,
    required this.totalAttempts,
    required this.exerciseCount,
  });

  Color get _color {
    if (average < 50) return AppColors.error;
    if (average < 70) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
           Text(
            'Overall Quiz Average',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Large score
          Text(
            '${average.round()}%',
            style: TextStyle(
              color: _color,
              fontSize: 48,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniStat(
                label: 'Quizzes Taken',
                value: '$totalAttempts',
              ),
              const SizedBox(width: 32),
              _MiniStat(
                label: 'Exercises Covered',
                value: '$exerciseCount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style:  TextStyle(
            color: AppColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style:  TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Per-exercise quiz card
// ---------------------------------------------------------------------------

class _ExerciseQuizCard extends StatelessWidget {
  final _ExerciseQuizStats stat;

  const _ExerciseQuizCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: name + score badge
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.displayName,
                  style:  TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stat.scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: stat.scoreColor, width: 1),
                ),
                child: Text(
                  '${stat.averageScore.round()}%',
                  style: TextStyle(
                    color: stat.scoreColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats row: attempts, trend
          Row(
            children: [
              Icon(Icons.repeat_rounded,
                  color: AppColors.onSurfaceVariant, size: 14),
              const SizedBox(width: 4),
              Text(
                '${stat.attemptCount} attempt${stat.attemptCount == 1 ? '' : 's'}',
                style:  TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              Icon(stat.trendIcon, color: stat.trendColor, size: 14),
              const SizedBox(width: 4),
              Text(
                stat.trendLabel,
                style: TextStyle(
                  color: stat.trendColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Status label
              Text(
                stat.scoreLabel,
                style: TextStyle(
                  color: stat.scoreColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Score bar
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stat.averageScore / 100,
              backgroundColor: AppColors.surfaceVariant,
              valueColor:
                  AlwaysStoppedAnimation<Color>(stat.scoreColor),
              minHeight: 6,
            ),
          ),

          // Revise button for weak exercises
          if (stat.averageScore < 70) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  FirebaseAnalytics.instance.logEvent(
                    name: 'weak_area_revise_tapped',
                    parameters: {
                      'exercise_id': stat.compositeExerciseId,
                    },
                  );
                  context.push(
                      '/exercises/${stat.compositeExerciseId}/quiz');
                },
                icon: const Icon(Icons.quiz_rounded, size: 16),
                label: const Text('Revise Now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: stat.scoreColor,
                  side: BorderSide(
                      color: stat.scoreColor.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
