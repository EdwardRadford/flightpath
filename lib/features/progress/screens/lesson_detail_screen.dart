// Lesson detail screen — full read-only view of a single completed lesson
// including ratings, quiz score, and AI debrief.
// Includes edit and delete actions via an overflow menu.
//
// Can be opened in two ways:
//   1. In-memory: pass a Lesson object via state.extra (normal in-app nav).
//   2. Deep link: pass only a lessonId path parameter — the screen fetches the
//      lesson from Firestore on first build.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

/// Read-only view of a single lesson with all recorded data.
/// Includes an overflow menu for editing and deleting the lesson.
///
/// [lesson] and [lessonId] are mutually exclusive:
///   - Provide [lesson] for normal in-app navigation.
///   - Provide [lessonId] for deep-link navigation.
class LessonDetailScreen extends ConsumerWidget {
  final Lesson? lesson;
  final String? lessonId;

  const LessonDetailScreen({
    super.key,
    this.lesson,
    this.lessonId,
  }) : assert(
          lesson != null || lessonId != null,
          'Either lesson or lessonId must be provided',
        );

  Future<void> _deleteLessonById(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: const Text(
          'Are you sure you want to delete this lesson? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.deleteLesson(uid, id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lesson deleted'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete lesson. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _editLessonObj(BuildContext context, Lesson l) {
    final compositeId = compositeExerciseId(l.exerciseId, l.subExercise);
    context.push('/exercises/$compositeId/debrief/edit', extra: l);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lesson != null) {
      return _LessonDetailBody(
        lesson: lesson!,
        onEdit: (l) => _editLessonObj(context, l),
        onDelete: (id) => _deleteLessonById(context, ref, id),
      );
    }

    final fetchAsync = ref.watch(_lessonByIdProvider(lessonId!));
    return fetchAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Lesson Detail'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Lesson Detail'), elevation: 0),
        body: const Center(
          child: Text('Lesson not found. Please go back and try again.'),
        ),
      ),
      data: (fetched) {
        if (fetched == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lesson Detail'), elevation: 0),
            body: const Center(
              child: Text('Lesson not found. Please go back and try again.'),
            ),
          );
        }
        return _LessonDetailBody(
          lesson: fetched,
          onEdit: (l) => _editLessonObj(context, l),
          onDelete: (id) => _deleteLessonById(context, ref, id),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Provider — fetches a single lesson by Firestore document ID.
// ---------------------------------------------------------------------------

final _lessonByIdProvider =
    FutureProvider.family<Lesson?, String>((ref, lessonId) async {
  final uid = ref.read(currentUserIdProvider);
  if (uid == null) return null;
  final firestore = ref.read(firestoreServiceProvider);
  return firestore.getLesson(uid, lessonId);
});

// ---------------------------------------------------------------------------
// Body widget
// ---------------------------------------------------------------------------

class _LessonDetailBody extends ConsumerWidget {
  final Lesson lesson;
  final void Function(Lesson) onEdit;
  final void Function(String) onDelete;

  const _LessonDetailBody({
    required this.lesson,
    required this.onEdit,
    required this.onDelete,
  });

  Color _ratingColor(int? rating) {
    if (rating == null) return AppColors.onSurfaceVariant;
    if (rating <= 2) return AppColors.error;
    if (rating <= 4) return AppColors.warning;
    return AppColors.success;
  }

  String _ratingMessage(int? rating) {
    if (rating == null) return '';
    if (rating <= 2) return 'Needs more practice';
    if (rating <= 4) return 'Nearly there';
    return 'Perfect';
  }

  IconData _ratingIcon(int? rating) {
    if (rating == null) return Icons.help_outline_rounded;
    if (rating <= 2) return Icons.replay_rounded;
    if (rating <= 4) return Icons.trending_up_rounded;
    return Icons.check_circle_rounded;
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryKey = lesson.subExercise.isNotEmpty
        ? '${lesson.exerciseId}_${lesson.subExercise}'
        : lesson.exerciseId;

    FirebaseAnalytics.instance.logEvent(
      name: 'lesson_detail_viewed',
      parameters: {'exercise_id': primaryKey},
    );

    final primaryName = exerciseLongName(primaryKey);
    final date = lesson.lessonDate ?? lesson.scheduledDate ?? lesson.createdAt;
    final ratingColor = _ratingColor(lesson.studentRating);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Detail'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit(lesson);
                case 'delete':
                  onDelete(lesson.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_rounded),
                  title: Text('Edit'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_rounded, color: AppColors.error),
                  title: Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ratingColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryName,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (lesson.additionalExerciseIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: lesson.additionalExerciseIds.map((id) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exerciseLongName(id),
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        color: AppColors.onSurfaceVariant, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(date),
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.timer_rounded,
                          color: AppColors.onSurfaceVariant, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(lesson.lessonDuration),
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ratings
          if (lesson.studentRating != null ||
              lesson.instructorRating != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ratingColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ratingColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  if (lesson.studentRating != null)
                    Row(
                      children: [
                        Icon(_ratingIcon(lesson.studentRating),
                            color: ratingColor, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ratingMessage(lesson.studentRating),
                                style: TextStyle(
                                  color: ratingColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  ...List.generate(5, (i) {
                                    return Icon(
                                      (i + 1) <= lesson.studentRating!
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: ratingColor,
                                      size: 20,
                                    );
                                  }),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your rating',
                                    style: TextStyle(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  if (lesson.studentRating != null &&
                      lesson.instructorRating != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: ratingColor.withValues(alpha: 0.2),
                        height: 1,
                      ),
                    ),
                  if (lesson.instructorRating != null)
                    Row(
                      children: [
                        Icon(Icons.person_rounded,
                            color: _ratingColor(lesson.instructorRating),
                            size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instructor Rating',
                                style: TextStyle(
                                  color: AppColors.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    (i + 1) <= lesson.instructorRating!
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: _ratingColor(lesson.instructorRating),
                                    size: 20,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Session score
          if (lesson.sessionScore != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.military_tech_rounded,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Score',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${lesson.sessionScore}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' / 100',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Quiz',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${lesson.quizScore}%',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Instructor comments
          if (lesson.instructorNotes.isNotEmpty) ...[
            _buildDetailCard(
              icon: Icons.person_rounded,
              title: "Instructor's Comments",
              body: lesson.instructorNotes,
            ),
            const SizedBox(height: 12),
          ],

          // AI debrief
          if (lesson.aiDebriefWell.isNotEmpty ||
              lesson.aiDebriefImprove.isNotEmpty ||
              lesson.aiDebriefFocus.isNotEmpty) ...[
            _buildAiDebriefCard(lesson),
            const SizedBox(height: 12),
          ],

          // Personal reflection
          if (lesson.personalReflection.isNotEmpty) ...[
            _buildDetailCard(
              icon: Icons.edit_note_rounded,
              title: 'Your Reflection',
              body: lesson.personalReflection,
            ),
            const SizedBox(height: 12),
          ],


          // Empty state if no notes
          if (lesson.instructorNotes.isEmpty &&
              lesson.personalReflection.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No notes recorded for this lesson.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.onSurfaceVariant, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDebriefCard(Lesson lesson) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 16),
              SizedBox(width: 6),
              Text(
                'AI Debrief',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.dividerDark, height: 1),
          const SizedBox(height: 12),
          if (lesson.aiDebriefWell.isNotEmpty) ...[
            _aiDebriefRow(
              Icons.check_circle_outline_rounded,
              AppColors.success,
              'What went well',
              lesson.aiDebriefWell,
            ),
            const SizedBox(height: 10),
          ],
          if (lesson.aiDebriefImprove.isNotEmpty) ...[
            _aiDebriefRow(
              Icons.trending_up_rounded,
              AppColors.warning,
              'What to improve',
              lesson.aiDebriefImprove,
            ),
            const SizedBox(height: 10),
          ],
          if (lesson.aiDebriefFocus.isNotEmpty)
            _aiDebriefRow(
              Icons.flag_outlined,
              AppColors.primary,
              'Focus next lesson',
              lesson.aiDebriefFocus,
            ),
        ],
      ),
    );
  }

  Widget _aiDebriefRow(
    IconData icon,
    Color color,
    String label,
    String text,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
