// Pre-Solo Readiness screen (/exercises/pre-solo-readiness) — self-assessment
// checklist the student works through before their first solo flight.
//
// Persists checked items to Firestore at
// users/{uid}/exercises/{exerciseId}.checklist_completed (List<int> of indices)
// using the existing UserExercise.checklistCompleted slot. Milestone exercises
// don't otherwise use that field, so there's no collision.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

class PreSoloReadinessScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const PreSoloReadinessScreen({
    super.key,
    this.compositeExerciseId = 'ex_14',
  });

  @override
  ConsumerState<PreSoloReadinessScreen> createState() =>
      _PreSoloReadinessScreenState();
}

class _PreSoloReadinessScreenState
    extends ConsumerState<PreSoloReadinessScreen> {
  static const _items = [
    'I can consistently achieve and maintain circuit height (1000ft QFE)',
    'My approach speed is stable and I don\'t balloon or float excessively',
    'I can judge the flare and touchdown point reliably',
    'I can perform a go-around at any point without prompting',
    'My radio calls are fluent — I know what to say and when',
    'I understand the emergency procedures for engine failure on take-off',
    'I can maintain coordinated flight throughout the circuit',
    'I know the circuit joining procedure at my home airfield',
    'I feel confident to fly alone without instructor input',
    'My instructor has expressed confidence in my readiness',
  ];

  /// Local checked state, hydrated from Firestore on first frame.
  late List<bool> _checked = List<bool>.filled(_items.length, false);
  bool _hydrated = false;

  void _hydrate(UserExercise? existing) {
    if (_hydrated) return;
    _hydrated = true;
    if (existing == null) return;
    final next = List<bool>.filled(_items.length, false);
    for (final i in existing.checklistCompleted) {
      if (i >= 0 && i < _items.length) next[i] = true;
    }
    if (mounted) setState(() => _checked = next);
  }

  Future<void> _persist() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final firestore = ref.read(firestoreServiceProvider);
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    final indices = <int>[
      for (var i = 0; i < _checked.length; i++)
        if (_checked[i]) i,
    ];

    final existing = ref.read(userExercisesProvider).valueOrNull?.where((ue) {
      return ue.exerciseId == exerciseId && ue.subExercise == subExerciseId;
    }).firstOrNull;

    if (existing != null) {
      await firestore.updateUserExerciseFields(uid, existing.id, {
        'checklist_completed': indices,
      });
    } else {
      await firestore.upsertUserExercise(
        uid,
        UserExercise(
          id: subExerciseId == null
              ? exerciseId
              : '${exerciseId}_$subExerciseId',
          exerciseId: exerciseId,
          subExercise: subExerciseId,
          exerciseNumber: 14,
          status: ExerciseStatus.notStarted,
          timesAttempted: 0,
          ratingHistory: const [],
          checklistCompleted: indices,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Watch user exercises so we hydrate once data arrives.
    final ueAsync = ref.watch(userExercisesProvider);
    ueAsync.whenData((list) {
      final (exerciseId, subExerciseId) =
          parseExerciseId(widget.compositeExerciseId);
      final match = list.where((ue) {
        return ue.exerciseId == exerciseId && ue.subExercise == subExerciseId;
      }).firstOrNull;
      _hydrate(match);
    });

    final checkedCount = _checked.where((v) => v).length;
    final allDone = checkedCount == _items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-Solo Readiness'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Honest self-assessment before your first solo flight. '
                  'Your instructor makes the final call — this is for your own reflection.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outline, width: 0.5),
                  ),
                  child: Column(
                    children: List.generate(_items.length, (i) {
                      final isChecked = _checked[i];
                      return Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.only(
                              topLeft:
                                  i == 0 ? const Radius.circular(14) : Radius.zero,
                              topRight:
                                  i == 0 ? const Radius.circular(14) : Radius.zero,
                              bottomLeft: i == _items.length - 1
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                              bottomRight: i == _items.length - 1
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                            ),
                            onTap: () {
                              setState(() => _checked[i] = !_checked[i]);
                              _persist();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Checkbox(
                                    value: isChecked,
                                    onChanged: (v) {
                                      setState(
                                          () => _checked[i] = v ?? false);
                                      _persist();
                                    },
                                    activeColor: AppColors.success,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _items[i],
                                      style: TextStyle(
                                        color: isChecked
                                            ? AppColors.success
                                            : AppColors.onSurface,
                                        fontSize: 14,
                                        height: 1.5,
                                        fontWeight: isChecked
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (i < _items.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: cs.outline.withValues(alpha: 0.5),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                _SummaryCard(checkedCount: checkedCount, allDone: allDone),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int checkedCount;
  final bool allDone;

  const _SummaryCard({required this.checkedCount, required this.allDone});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allDone
            ? AppColors.success.withValues(alpha: 0.1)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: allDone
              ? AppColors.success.withValues(alpha: 0.5)
              : cs.outline.withValues(alpha: 0.5),
          width: allDone ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            '$checkedCount / 10 complete',
            style: TextStyle(
              color: allDone ? AppColors.success : AppColors.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (allDone) ...[
            const SizedBox(height: 6),
            Text(
              'Talk to your instructor when you\'re ready.',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
