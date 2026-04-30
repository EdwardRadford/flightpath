// Exercise debrief screen — captures instructor notes, what went well, and focus for next time; saves to Firestore via exercise_provider helpers.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

class ExerciseDebriefScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String? subExercise;

  const ExerciseDebriefScreen({
    super.key,
    required this.exerciseId,
    this.subExercise,
  });

  @override
  ConsumerState<ExerciseDebriefScreen> createState() =>
      _ExerciseDebriefScreenState();
}

class _ExerciseDebriefScreenState extends ConsumerState<ExerciseDebriefScreen> {
  final _instructorController = TextEditingController();
  final _wentWellController = TextEditingController();
  final _focusController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(userExercisesProvider).valueOrNull?.where((ue) {
      return ue.exerciseId == widget.exerciseId &&
          ue.subExercise == widget.subExercise;
    }).firstOrNull;
    if (existing != null) {
      _instructorController.text = existing.instructorNotes ?? '';
      _wentWellController.text = existing.debriefNotes ?? '';
      _focusController.text = existing.focusNextTime ?? '';
    }
  }

  @override
  void dispose() {
    _instructorController.dispose();
    _wentWellController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  String _shortName() {
    final composite = compositeExerciseId(widget.exerciseId, widget.subExercise);
    return exerciseDisplayName(composite);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await Future.wait([
        saveInstructorNotes(
          ref,
          widget.exerciseId,
          widget.subExercise,
          _instructorController.text.isEmpty ? null : _instructorController.text,
        ),
        saveDebrief(
          ref,
          widget.exerciseId,
          widget.subExercise,
          _wentWellController.text.isEmpty ? null : _wentWellController.text,
          _focusController.text.isEmpty ? null : _focusController.text,
        ),
      ]);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How did it go?'),
        elevation: 0,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(
              _shortName(),
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () => context.push(
                '/ask-ai',
                extra: <String, dynamic>{
                  'exerciseId': widget.exerciseId,
                  'subExercise': widget.subExercise,
                },
              ),
              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text('AI Debrief'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'What did your instructor say?',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instructorController,
              maxLines: 4,
              maxLength: 500,
              style: TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Optional — feedback from your instructor',
                hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle:
                    TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'What went well',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _wentWellController,
              maxLines: 4,
              maxLength: 500,
              style: TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Optional — what clicked today?',
                hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle:
                    TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Focus for next time',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _focusController,
              maxLines: 4,
              maxLength: 500,
              style: TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Optional — one thing to concentrate on',
                hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle:
                    TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
              ),
            ),
            const SizedBox(height: 32),

            Builder(builder: (context) {
              final aiNotes = ref
                  .watch(userExercisesProvider)
                  .valueOrNull
                  ?.where((ue) =>
                      ue.exerciseId == widget.exerciseId &&
                      ue.subExercise == widget.subExercise)
                  .firstOrNull
                  ?.aiDebriefNotes;
              if (aiNotes == null || aiNotes.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Debrief',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      aiNotes,
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save & Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
