// Completion screen — celebratory view shown when all exercises are complete,
// with animated entrance and links to the CAA skills test booking page.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

/// Full-screen celebration shown when every exercise and sub-exercise is
/// marked as complete. Displays summary stats and a scrollable list of
/// exercises with best ratings.
class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({super.key});

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _scaleIn = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final exercisesAsync = ref.watch(userExercisesProvider);
    final lessonsAsync = ref.watch(allLessonsProvider);

    return Scaffold(
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => Center(
          child: Text('Something went wrong',
              style: TextStyle(color: AppColors.onSurface)),
        ),
        data: (user) {
          final exercises = exercisesAsync.valueOrNull ?? [];
          final lessons = lessonsAsync.valueOrNull ?? [];

          return FadeTransition(
            opacity: _fadeIn,
            child: _buildContent(
              totalHours: user?.hoursFlown ?? 0,
              exercises: exercises,
              lessons: lessons,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required double totalHours,
    required List<UserExercise> exercises,
    required List<Lesson> lessons,
  }) {
    final completedExercises =
        exercises.where((e) => e.status.isCompleted).toList();
    final totalLessons =
        lessons.where((l) => l.status == LessonStatus.completed).length;
    final avgRating = completedExercises.isNotEmpty
        ? completedExercises
                .where((e) => e.bestRating != null)
                .fold<double>(0, (sum, e) => sum + e.bestRating!) /
            completedExercises.where((e) => e.bestRating != null).length
        : 0.0;

    final completedLessons = lessons
        .where((l) => l.status == LessonStatus.completed && l.lessonDate != null)
        .toList();
    String trainingDuration = '--';
    if (completedLessons.length >= 2) {
      completedLessons.sort((a, b) => a.lessonDate!.compareTo(b.lessonDate!));
      final first = completedLessons.first.lessonDate!;
      final last = completedLessons.last.lessonDate!;
      final days = last.difference(first).inDays;
      if (days > 30) {
        final months = (days / 30.44).round();
        trainingDuration = '$months month${months == 1 ? '' : 's'}';
      } else {
        trainingDuration = '$days day${days == 1 ? '' : 's'}';
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.top + 16),
        ),

        // Close button
        SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: () => context.go('/exercises'),
                icon: Icon(Icons.close, color: AppColors.onSurfaceVariant),
                tooltip: 'Close',
              ),
            ),
          ),
        ),

        // Hero section
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleIn,
            child: _buildHeroSection(),
          ),
        ),

        // Stats row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              children: [
                _buildStatCard('Total Hours', totalHours.toStringAsFixed(1),
                    Icons.access_time_rounded),
                const SizedBox(width: 12),
                _buildStatCard('Exercises', '${completedExercises.length}',
                    Icons.check_circle_outline_rounded),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                _buildStatCard(
                    'Lessons', '$totalLessons', Icons.book_outlined),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Avg Rating',
                  avgRating > 0 ? avgRating.toStringAsFixed(1) : '--',
                  Icons.star_rounded,
                ),
              ],
            ),
          ),
        ),

        // Training duration
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Training Duration',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trainingDuration,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Exercise list as collapsible dropdown
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'All Exercises (${AppConstants.allExerciseIds.length})',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: AppConstants.allExerciseIds.map((exerciseId) {
                  final ue = exercises.where((e) {
                    final composite =
                        compositeExerciseId(e.exerciseId, e.subExercise);
                    return composite == exerciseId;
                  }).firstOrNull;
                  return _buildExerciseRow(exerciseId, ue);
                }).toList(),
              ),
            ),
          ),
        ),

        // Action buttons
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: ElevatedButton(
              onPressed: _openCaaWebsite,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Book Your Skills Test',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: OutlinedButton(
              onPressed: () => context.go('/exercises'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.divider),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue Reviewing',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child:
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primary,
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Transform.rotate(
                angle:
                    math.sin(_shimmerController.value * 2 * math.pi) * 0.05,
                child: child,
              );
            },
            child: const Icon(
              Icons.flight_takeoff_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Skills Test Ready!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You've completed all CAA PPL(A) exercises.\nYou're ready to book your Skills Test.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseRow(String exerciseId, UserExercise? ue) {
    final name = exerciseDisplayName(exerciseId);
    final title = AppConstants.exerciseTitles[exerciseId] ?? '';
    final rating = ue?.bestRating ?? 0;
    final isComplete = ue?.status.isCompleted ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isComplete
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: isComplete ? AppColors.success : AppColors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Wrap in Semantics + ExcludeSemantics so VoiceOver reads
          // "rating, $rating of 5" instead of five separate "image" nodes.
          Semantics(
            label: 'Rating, $rating of 5',
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i < rating
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                    size: 16,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCaaWebsite() {
    launchUrl(Uri.parse(
        'https://www.caa.co.uk/general-aviation/pilot-licences/aeroplanes/national-private-pilot-licence/'));
  }
}
