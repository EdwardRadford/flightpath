// Student detail screen — shows an instructor a comprehensive view of a
// student's progress, lessons, and allows adding notes.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/models/exercise_assessment.dart';
import 'package:flight_path/shared/models/instructor_note.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import '../providers/instructor_provider.dart';

// ---------------------------------------------------------------------------
// Student profile provider (one-shot)
// ---------------------------------------------------------------------------

final _studentProfileProvider =
    FutureProvider.family<AppUser?, String>((ref, studentId) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(studentId)
      .get();
  if (!snap.exists) return null;
  return AppUser.fromFirestore(snap);
});

// ---------------------------------------------------------------------------
// StudentDetailScreen
// ---------------------------------------------------------------------------

class StudentDetailScreen extends ConsumerWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  /// Pre-compiled regex for UID validation.
  static final RegExp _uidPattern = RegExp(r'^[a-zA-Z0-9]+$');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Validate studentId format to prevent injection via deep links or
    // URL manipulation.
    if (studentId.isEmpty ||
        studentId.length > 128 ||
        !_uidPattern.hasMatch(studentId)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text(
            'Invalid student ID.',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    final profileAsync = ref.watch(_studentProfileProvider(studentId));
    final lessonsAsync = ref.watch(studentLessonsProvider(studentId));
    final exercisesAsync = ref.watch(studentExercisesProvider(studentId));
    final notesAsync = ref.watch(instructorNotesProvider(studentId));
    final assessmentsAsync =
        ref.watch(exerciseAssessmentsProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          profileAsync.valueOrNull?.displayName ?? 'Student',
        ),
        elevation: 0,
        actions: [
          if (profileAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.chat_rounded),
              tooltip: 'Message student',
              onPressed: () {
                final student = profileAsync.valueOrNull!;
                context.push(
                  '/instructor/messaging/${student.uid}'
                  '?name=${Uri.encodeComponent(student.displayName)}',
                );
              },
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => const Center(
          child: Text(
            'Failed to load student profile.',
            style: TextStyle(color: AppColors.error),
          ),
        ),
        data: (student) {
          if (student == null) {
            return Center(
              child: Text(
                'Student not found.',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Student profile card ──────────────────────────────────
              _StudentProfileCard(student: student),
              const SizedBox(height: 20),

              // ── Exercise progress ─────────────────────────────────────
              const _SectionHeader(label: 'Exercise Progress'),
              exercisesAsync.when(
                data: (exercises) => _ExerciseProgressSection(
                  exercises: exercises,
                  studentId: studentId,
                  assessments: assessmentsAsync.valueOrNull ?? [],
                ),
                loading: () => const _LoadingCard(),
                error: (_, __) =>
                    const _ErrorCard(message: 'Failed to load exercises.'),
              ),
              const SizedBox(height: 20),

              // ── Recent lessons ────────────────────────────────────────
              const _SectionHeader(label: 'Recent Lessons'),
              lessonsAsync.when(
                data: (lessons) => _RecentLessonsSection(lessons: lessons),
                loading: () => const _LoadingCard(),
                error: (_, __) =>
                    const _ErrorCard(message: 'Failed to load lessons.'),
              ),
              const SizedBox(height: 20),

              // ── Instructor notes ──────────────────────────────────────
              const _SectionHeader(label: 'Your Notes'),
              notesAsync.when(
                data: (notes) => _InstructorNotesSection(
                  notes: notes,
                  studentId: studentId,
                ),
                loading: () => const _LoadingCard(),
                error: (_, __) =>
                    const _ErrorCard(message: 'Failed to load notes.'),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecordDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.rate_review_rounded, color: Colors.white),
      ),
    );
  }

  void _showAddRecordDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Add Record',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select an exercise to assess',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: AppConstants.allExerciseIds.length,
                itemBuilder: (ctx, index) {
                  final id = AppConstants.allExerciseIds[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.assignment_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      exerciseLongName(id),
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.onSurfaceVariant,
                      size: 18,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(
                        '/instructor/student/$studentId/assess/$id',
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Student profile card
// ---------------------------------------------------------------------------

class _StudentProfileCard extends StatelessWidget {
  final AppUser student;
  const _StudentProfileCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final initial = student.displayName.isNotEmpty
        ? student.displayName[0].toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            student.displayName,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            student.email,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                label: 'Hours',
                value: student.hoursFlown.toStringAsFixed(1),
              ),
              _StatChip(
                label: 'Aircraft',
                value: _shortAircraftLabel(student.aircraftType),
              ),
              _StatChip(
                label: 'School',
                value: student.flightSchool.isNotEmpty
                    ? student.flightSchool
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortAircraftLabel(String type) {
    switch (type) {
      case 'cessna_152':
        return 'C152';
      case 'cessna_172':
        return 'C172';
      case 'pa28':
        return 'PA-28';
      case 'da40':
        return 'DA40';
      default:
        return type.isNotEmpty ? type : 'N/A';
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise progress section
// ---------------------------------------------------------------------------

class _ExerciseProgressSection extends StatelessWidget {
  final List<UserExercise> exercises;
  final String studentId;
  final List<ExerciseAssessment> assessments;

  const _ExerciseProgressSection({
    required this.exercises,
    required this.studentId,
    required this.assessments,
  });

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) {
      return _emptyCard('No exercise progress yet.');
    }

    // Sort by exercise number
    final sorted = List<UserExercise>.from(exercises)
      ..sort((a, b) => a.exerciseNumber.compareTo(b.exerciseNumber));

    final completed =
        sorted.where((e) => e.status.isCompleted).length;
    final total = AppConstants.allExerciseIds.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Summary bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '$completed / $total exercises completed',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  total > 0
                      ? '${(completed / total * 100).round()}%'
                      : '0%',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? completed / total : 0,
                backgroundColor: AppColors.divider,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ),
          Divider(color: AppColors.divider, height: 24),
          // Exercise list
          ...sorted.map((ex) {
            final compositeId = ex.subExercise != null
                ? '${ex.exerciseId}_${ex.subExercise}'
                : ex.exerciseId;
            final assessment = assessments.cast<ExerciseAssessment?>().firstWhere(
              (a) => a!.exerciseId == compositeId,
              orElse: () => null,
            );
            return _ExerciseRow(
              exercise: ex,
              studentId: studentId,
              assessment: assessment,
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final UserExercise exercise;
  final String studentId;
  final ExerciseAssessment? assessment;

  const _ExerciseRow({
    required this.exercise,
    required this.studentId,
    this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (exercise.status) {
      ExerciseStatus.completedUnsatisfactory => AppColors.warning,
      ExerciseStatus.completedSatisfactory => AppColors.success,
      ExerciseStatus.inProgress => AppColors.warning,
      ExerciseStatus.notStarted => AppColors.onSurfaceVariant,
    };
    final statusIcon = switch (exercise.status) {
      ExerciseStatus.completedUnsatisfactory =>
        Icons.check_circle_rounded,
      ExerciseStatus.completedSatisfactory => Icons.check_circle_rounded,
      ExerciseStatus.inProgress => Icons.timelapse_rounded,
      ExerciseStatus.notStarted => Icons.radio_button_unchecked,
    };

    final compositeId = exercise.subExercise != null
        ? '${exercise.exerciseId}_${exercise.subExercise}'
        : exercise.exerciseId;

    return InkWell(
      onTap: () {
        context.push(
          '/instructor/student/$studentId/assess/$compositeId',
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exerciseDisplayName(compositeId),
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
            // Assessment indicator
            if (assessment != null) ...[
              if (assessment!.signedOff)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: AppColors.success, size: 12),
                      SizedBox(width: 2),
                      Text(
                        'Signed Off',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (assessment!.overallRating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${assessment!.overallRating}/5',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const Icon(Icons.rate_review_outlined,
                    color: AppColors.primary, size: 14),
              const SizedBox(width: 6),
            ],
            if (exercise.bestRating != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.warning, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${exercise.bestRating}/5',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 8),
            Text(
              'x${exercise.timesAttempted}',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent lessons section
// ---------------------------------------------------------------------------

class _RecentLessonsSection extends StatelessWidget {
  final List<Lesson> lessons;
  const _RecentLessonsSection({required this.lessons});

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No lessons recorded yet.',
            style: TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 14),
          ),
        ),
      );
    }

    final recent = lessons.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: recent.map((lesson) => _LessonRow(lesson: lesson)).toList(),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final Lesson lesson;
  const _LessonRow({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final date = lesson.lessonDate ?? lesson.createdAt;
    final dateStr = '${date.day}/${date.month}/${date.year}';

    final compositeId = lesson.subExercise.isNotEmpty
        ? '${lesson.exerciseId}_${lesson.subExercise}'
        : lesson.exerciseId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exerciseDisplayName(compositeId),
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (lesson.studentRating != null)
            _RatingChip(
              label: 'Student',
              rating: lesson.studentRating!,
            ),
          if (lesson.instructorRating != null) ...[
            const SizedBox(width: 8),
            _RatingChip(
              label: 'Instructor',
              rating: lesson.instructorRating!,
            ),
          ],
          if (lesson.quizScore > 0) ...[
            const SizedBox(width: 8),
            Text(
              'Quiz: ${lesson.quizScore}%',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String label;
  final int rating;
  const _RatingChip({required this.label, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$rating/5',
        style: TextStyle(
          color: AppColors.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Instructor notes section
// ---------------------------------------------------------------------------

class _InstructorNotesSection extends StatelessWidget {
  final List<InstructorNote> notes;
  final String studentId;

  const _InstructorNotesSection({
    required this.notes,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No notes yet. Tap + to add one.',
            style: TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 14),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: notes.map((note) => _NoteRow(note: note)).toList(),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final InstructorNote note;
  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final date = note.createdAt;
    final dateStr = '${date.day}/${date.month}/${date.year}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_rounded,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                exerciseDisplayName(note.exerciseId),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.content,
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
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.error, fontSize: 14),
        ),
      ),
    );
  }
}
