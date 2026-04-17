import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

class LessonButton extends ConsumerStatefulWidget {
  final String compositeExerciseId;
  final String exerciseId;
  final String? subExerciseId;
  final bool hasLessons;
  final bool locked;

  const LessonButton({
    super.key,
    required this.compositeExerciseId,
    required this.exerciseId,
    required this.subExerciseId,
    required this.hasLessons,
    this.locked = false,
  });

  @override
  ConsumerState<LessonButton> createState() => _LessonButtonState();
}

class _LessonButtonState extends ConsumerState<LessonButton> {
  bool _updating = false;

  Lesson? _activeLesson(List<Lesson> lessons) {
    final matching = lessons.where((l) {
      final sameExercise = l.exerciseId == widget.exerciseId;
      final sameSub = l.subExercise == widget.subExerciseId;
      final isActive = l.status == LessonStatus.scheduled ||
          l.status == LessonStatus.prepared;
      return sameExercise && sameSub && isActive;
    }).toList();
    if (matching.isEmpty) return null;
    matching.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matching.first;
  }

  Future<void> _markPrepared(Lesson lesson) async {
    setState(() => _updating = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.updateLesson(uid, lesson.id, {'status': 'prepared'});

      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_prepared',
        parameters: {'exercise_id': widget.compositeExerciseId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You\'re ready for your lesson!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update lesson. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locked) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final user = ref.read(appUserProvider).valueOrNull;
            showPremiumPaywall(
              context,
              source: 'prepare_hub_button',
              freeWindowStart: user?.freeWindowStart ?? 1,
              freeWindowEnd: user?.freeWindowEnd ?? 3,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Upgrade to Pro',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final lessonsAsync = ref.watch(allLessonsProvider);
    final activeLesson = lessonsAsync.whenOrNull(
      data: (lessons) => _activeLesson(lessons),
    );

    if (activeLesson != null &&
        activeLesson.status == LessonStatus.scheduled) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _updating ? null : () => _markPrepared(activeLesson),
              icon: _updating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text(
                "I'm Ready \u2713",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context
                  .push('/exercises/${widget.compositeExerciseId}/debrief'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.divider),
                foregroundColor: AppColors.onSurfaceVariant,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Check In After Lesson',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    if (activeLesson != null &&
        activeLesson.status == LessonStatus.prepared) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context
              .push('/exercises/${widget.compositeExerciseId}/debrief'),
          icon: const Icon(Icons.rate_review_rounded),
          label: const Text(
            'Debrief Lesson',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context
                .push('/exercises/${widget.compositeExerciseId}/debrief'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Check In After Lesson',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context
                .push('/exercises/${widget.compositeExerciseId}/schedule'),
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: const Text(
              'Schedule a Lesson',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.divider),
              foregroundColor: AppColors.onSurfaceVariant,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
