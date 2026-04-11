// Exercise assessment screen — allows an instructor to rate a student's
// performance on individual criteria for an exercise on a 1-5 scale.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/constants/exercise_criteria.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/exercise_assessment.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import '../providers/instructor_provider.dart';

class ExerciseAssessmentScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String exerciseId;

  const ExerciseAssessmentScreen({
    super.key,
    required this.studentId,
    required this.exerciseId,
  });

  @override
  ConsumerState<ExerciseAssessmentScreen> createState() =>
      _ExerciseAssessmentScreenState();
}

class _ExerciseAssessmentScreenState
    extends ConsumerState<ExerciseAssessmentScreen> {
  final Map<String, int> _ratings = {};
  int? _overallRating;
  bool _signedOff = false;
  late final TextEditingController _notesController;
  bool _saving = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Pre-populate form from an existing assessment (called once).
  void _populateFromExisting(ExerciseAssessment assessment) {
    if (_initialised) return;
    _initialised = true;
    _ratings.addAll(assessment.criteriaRatings);
    _overallRating = assessment.overallRating;
    _signedOff = assessment.signedOff;
    _notesController.text = assessment.notes;
  }

  Future<void> _save() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      await saveExerciseAssessment(
        instructorId: uid,
        studentId: widget.studentId,
        exerciseId: widget.exerciseId,
        criteriaRatings: Map<String, int>.from(_ratings),
        overallRating: _overallRating,
        signedOff: _signedOff,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessment saved')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final criteria = ExerciseCriteria.forExercise(widget.exerciseId);
    final assessmentsAsync =
        ref.watch(exerciseAssessmentsProvider(widget.studentId));

    // Try to find an existing assessment for this exercise.
    final existing = assessmentsAsync.valueOrNull?.cast<ExerciseAssessment?>().firstWhere(
      (a) => a!.exerciseId == widget.exerciseId,
      orElse: () => null,
    );

    if (existing != null) {
      _populateFromExisting(existing);
    } else if (!_initialised) {
      _initialised = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(exerciseDisplayName(widget.exerciseId)),
        elevation: 0,
      ),
      body: criteria.isEmpty
          ? Center(
              child: Text(
                'No criteria defined for this exercise.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // Exercise title
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseLongName(widget.exerciseId),
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rate each criterion on a 1-5 scale',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Criteria list
                ...criteria.map((c) => _CriterionCard(
                      criterion: c,
                      rating: _ratings[c.key],
                      onRatingChanged: (rating) {
                        setState(() => _ratings[c.key] = rating);
                      },
                    )),

                const SizedBox(height: 20),

                // Overall rating
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Rating',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your holistic assessment of this exercise',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RatingSelector(
                        rating: _overallRating,
                        onChanged: (r) =>
                            setState(() => _overallRating = r),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        maxLength: InputSanitiser.maxMedium,
                        decoration: const InputDecoration(
                          hintText:
                              'Add any notes about the student\'s performance...',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sign-off toggle
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Sign Off Exercise',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Formally approve this exercise as complete',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    activeThumbColor: AppColors.success,
                    activeTrackColor: AppColors.success.withValues(alpha: 0.4),
                    value: _signedOff,
                    onChanged: (v) => setState(() => _signedOff = v),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: criteria.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Assessment'),
                ),
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Criterion card
// ---------------------------------------------------------------------------

class _CriterionCard extends StatelessWidget {
  final ExerciseCriterion criterion;
  final int? rating;
  final ValueChanged<int> onRatingChanged;

  const _CriterionCard({
    required this.criterion,
    required this.rating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              criterion.label,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              criterion.description,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _RatingSelector(
              rating: rating,
              onChanged: onRatingChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rating selector (1-5 tappable dots with colour coding)
// ---------------------------------------------------------------------------

class _RatingSelector extends StatelessWidget {
  final int? rating;
  final ValueChanged<int> onChanged;

  const _RatingSelector({
    required this.rating,
    required this.onChanged,
  });

  static const _ratingLabels = ['Poor', 'Below Avg', 'Average', 'Good', 'Excellent'];

  static Color _ratingColor(int value) {
    return switch (value) {
      1 => AppColors.error,
      2 => const Color(0xFFED8936), // orange
      3 => AppColors.warning,
      4 => const Color(0xFF68D391), // light green
      5 => AppColors.success,
      _ => AppColors.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final value = i + 1;
        final isSelected = rating != null && rating! >= value;
        final color = isSelected ? _ratingColor(value) : AppColors.divider;

        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? color : AppColors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          color: isSelected ? color : AppColors.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ratingLabels[i],
                    style: TextStyle(
                      color: isSelected
                          ? color
                          : AppColors.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
