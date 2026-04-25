// Brief screen — displays the exercise overview, key focus areas, common
// mistakes, aircraft tips, active recall prompt, and skills test standards.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/constants/exercise_criteria.dart';
import 'package:flight_path/core/constants/skills_test_standards.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Pre-lesson briefing with expandable content sections and active recall.
class BriefScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  /// When true, the screen will auto-scroll to the Active Recall section.
  final bool scrollToRecall;

  const BriefScreen({
    super.key,
    required this.compositeExerciseId,
    this.scrollToRecall = false,
  });

  @override
  ConsumerState<BriefScreen> createState() => _BriefScreenState();
}

class _BriefScreenState extends ConsumerState<BriefScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _recallKey = GlobalKey();

  bool _hasMarkedInProgress = false;
  bool _analyticsLogged = false;
  final Stopwatch _readTimer = Stopwatch();

  @override
  void initState() {
    super.initState();
    _readTimer.start();
    if (widget.scrollToRecall) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToRecall());
    }
  }

  @override
  void dispose() {
    _readTimer.stop();
    if (_readTimer.elapsed.inSeconds >= 30) {
      FirebaseAnalytics.instance.logEvent(
        name: 'brief_read_completed',
        parameters: {
          'exercise_id': widget.compositeExerciseId,
          'duration_seconds': _readTimer.elapsed.inSeconds,
        },
      );
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToRecall() {
    final context = _recallKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Marks the UserExercise as inProgress if it was notStarted.
  Future<void> _markInProgressIfNeeded(
    ExerciseContent content,
    String uid,
  ) async {
    if (_hasMarkedInProgress) return;
    _hasMarkedInProgress = true;

    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    final exercisesAsync = ref.read(userExercisesProvider);
    final exercises = exercisesAsync.valueOrNull ?? [];

    final UserExercise? existing = exercises.where((ue) {
      return ue.exerciseId == exerciseId && ue.subExercise == subExerciseId;
    }).firstOrNull;

    final firestore = ref.read(firestoreServiceProvider);
    final updated = UserExercise(
      id: existing?.id ?? '',
      exerciseId: exerciseId,
      subExercise: subExerciseId,
      exerciseNumber: content.exerciseNumber,
      status: existing == null || existing.status == ExerciseStatus.notStarted
          ? ExerciseStatus.inProgress
          : existing.status,
      bestRating: existing?.bestRating,
      timesAttempted: existing?.timesAttempted ?? 0,
      ratingHistory: existing?.ratingHistory ?? [],
      lastAttempted: existing?.lastAttempted,
      videoWatched: existing?.videoWatched ?? false,
      briefViewed: true,
      flashcardsCompleted: existing?.flashcardsCompleted ?? false,
      weatherChecked: existing?.weatherChecked ?? false,
      quizPassed: existing?.quizPassed ?? false,
      quizAttempted: existing?.quizAttempted ?? false,
      visualisationViewed: existing?.visualisationViewed ?? false,
      spacedRepDue: existing?.spacedRepDue,
      checklistCompleted: existing?.checklistCompleted ?? [],
    );
    await firestore.upsertUserExercise(uid, updated);
  }

  @override
  Widget build(BuildContext context) {
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    final contentAsync =
        ref.watch(exerciseContentProvider((exerciseId, subExerciseId)));
    final appUserAsync = ref.watch(appUserProvider);
    final uid = ref.watch(currentUserIdProvider);

    return contentAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Brief')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Unable to load brief. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      data: (content) {
        if (content == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Brief')),
            body: Center(
              child: Text(
                'Content not available.',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ),
          );
        }

        if (!_analyticsLogged) {
          _analyticsLogged = true;
          FirebaseAnalytics.instance.logEvent(
            name: 'brief_viewed',
            parameters: {'exercise_id': widget.compositeExerciseId},
          );
        }

        if (uid != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _markInProgressIfNeeded(content, uid);
          });
        }

        final aircraftType = appUserAsync.valueOrNull?.aircraftType ?? '';
        final aircraftTip = content.tipsForAircraft(aircraftType);
        final bool showTip = aircraftTip.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.exerciseName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  'Brief',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // 1. Overview
              _BriefSection(
                title: 'Overview',
                child: Text(
                  content.overview,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Aim
              _BriefSection(
                title: 'Aim',
                child: Text(
                  content.aim,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. What to Expect
              if (content.whatToExpect.isNotEmpty) ...[
                _BriefSection(
                  title: 'What to Expect',
                  child: Text(
                    content.whatToExpect,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 4. CAA Assessment Criteria
              if (ExerciseCriteria.exerciseCriteria
                  .containsKey(widget.compositeExerciseId)) ...[
                _CaaStandardsSection(
                  criteria: ExerciseCriteria
                      .exerciseCriteria[widget.compositeExerciseId]!,
                ),
                const SizedBox(height: 24),
              ],

              // 5. Key Focus Areas
              if (content.keyFocusAreas.isNotEmpty) ...[
                _BriefSection(
                  title: 'Key Focus Areas',
                  child: Text(
                    content.keyFocusAreas,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 6. Pre-Flight Checklist
              if (content.preFlightChecklist.isNotEmpty) ...[
                _InteractiveChecklist(
                  checklistText: content.preFlightChecklist,
                  compositeExerciseId: widget.compositeExerciseId,
                ),
                const SizedBox(height: 24),
              ],

              // 6. Common Mistakes
              if (content.commonMistakes.isNotEmpty) ...[
                _BriefSection(
                  title: 'Common Mistakes',
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.warning,
                  child: _BulletList(
                    text: content.commonMistakes,
                    bulletColor: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 7. One Thing to Nail
              if (content.oneThingToNail.isNotEmpty) ...[
                _BriefSection(
                  title: 'One Thing to Nail',
                  child: Text(
                    content.oneThingToNail,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 8. Mastery Criteria
              if (content.masteryCriteria.isNotEmpty) ...[
                _BriefSection(
                  title: 'Mastery Criteria',
                  child: Text(
                    content.masteryCriteria,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 9. Aircraft-Specific Tips
              if (showTip) ...[
                _AircraftTipCard(
                  aircraftType: aircraftType,
                  tip: aircraftTip,
                ),
                const SizedBox(height: 24),
              ],

              // 10. Skills Test Standard
              if (skillsTestStandards
                  .containsKey(widget.compositeExerciseId)) ...[
                _SkillsTestStandardCard(
                  standard:
                      skillsTestStandards[widget.compositeExerciseId]!,
                ),
                const SizedBox(height: 24),
              ],

              // 11. Active Recall
              _ActiveRecallCard(key: _recallKey),

              // 12. Done button
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    FirebaseAnalytics.instance.logEvent(
                      name: 'brief_done_tapped',
                      parameters: {
                        'exercise_id': widget.compositeExerciseId,
                      },
                    );
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('Done — Back to Prepare'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _BriefSection extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;

  const _BriefSection({
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? AppColors.primary, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: cs.outline, height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Renders a block of text as a simple bullet list split on newlines.
class _BulletList extends StatelessWidget {
  final String text;
  final Color bulletColor;

  const _BulletList({required this.text, required this.bulletColor});

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: bulletColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Interactive pre-flight checklist with persistent checkboxes.
class _InteractiveChecklist extends ConsumerStatefulWidget {
  final String checklistText;
  final String compositeExerciseId;

  const _InteractiveChecklist({
    required this.checklistText,
    required this.compositeExerciseId,
  });

  @override
  ConsumerState<_InteractiveChecklist> createState() =>
      _InteractiveChecklistState();
}

class _InteractiveChecklistState extends ConsumerState<_InteractiveChecklist> {
  late final List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.checklistText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  Future<void> _toggle(int index, List<int> current) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    final exercises = ref.read(userExercisesProvider).valueOrNull ?? [];
    final existing = exercises
        .where(
            (ue) => ue.exerciseId == exerciseId && ue.subExercise == subExerciseId)
        .firstOrNull;

    if (existing == null) return;

    final updated = List<int>.from(current);
    if (updated.contains(index)) {
      updated.remove(index);
    } else {
      updated.add(index);
    }

    final firestore = ref.read(firestoreServiceProvider);
    await firestore.upsertUserExercise(
      uid,
      existing.copyWith(checklistCompleted: updated),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);

    final exercises = ref.watch(userExercisesProvider).valueOrNull ?? [];
    final userExercise = exercises
        .where(
            (ue) => ue.exerciseId == exerciseId && ue.subExercise == subExerciseId)
        .firstOrNull;

    final completed = userExercise?.checklistCompleted ?? [];
    final doneCount = completed.length;
    final totalCount = _items.length;
    final allDone = totalCount > 0 && doneCount >= totalCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone
              ? AppColors.success.withValues(alpha: 0.6)
              : cs.outline,
          width: allDone ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              if (allDone) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  'Pre-Flight Checklist',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress indicator
          Text(
            allDone
                ? 'All $totalCount items complete'
                : '$doneCount of $totalCount items complete',
            style: TextStyle(
              color: allDone ? AppColors.success : AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outline, height: 1),
          const SizedBox(height: 10),

          // Checklist items
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final text = entry.value;
            final isChecked = completed.contains(index);

            return InkWell(
              onTap: () => _toggle(index, completed),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1, right: 10),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: isChecked
                            ? Border.all(
                                color: AppColors.success.withValues(alpha: 0.4),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Center(
                        child: isChecked
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: AppColors.success,
                              )
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    // Item text
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isChecked
                              ? AppColors.onSurfaceVariant
                              : AppColors.onSurface,
                          fontSize: 14,
                          height: 1.55,
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AircraftTipCard extends StatelessWidget {
  final String aircraftType;
  final String tip;

  const _AircraftTipCard({required this.aircraftType, required this.tip});

  String _aircraftLabel(String type) =>
      AppConstants.aircraftTypes[type] ?? type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.airplanemode_active_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${_aircraftLabel(aircraftType)} Tips',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.primaryBrightSubtle, height: 1),
          const SizedBox(height: 16),
          Text(
            tip,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsTestStandardCard extends StatelessWidget {
  final String standard;

  const _SkillsTestStandardCard({required this.standard});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.school_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Skills Test Standard',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 16),
          Text(
            standard,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRecallCard extends StatelessWidget {
  const _ActiveRecallCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Active Recall',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Close your notes and mentally walk through the exercise. Consider:',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const _RecallPrompt(text: 'What are the key checks?'),
          const _RecallPrompt(text: 'What are the common errors?'),
          const _RecallPrompt(text: 'What would you do differently?'),
        ],
      ),
    );
  }
}

class _RecallPrompt extends StatelessWidget {
  final String text;
  const _RecallPrompt({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: Icon(
              Icons.arrow_right_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaaStandardsSection extends StatelessWidget {
  final List<ExerciseCriterion> criteria;

  const _CaaStandardsSection({required this.criteria});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'CAA Assessment Criteria',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'What your instructor will assess on this exercise',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outline, height: 1),
          const SizedBox(height: 12),
          ...criteria.map((c) => _CriterionRow(criterion: c)),
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  final ExerciseCriterion criterion;

  const _CriterionRow({required this.criterion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criterion.label,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  criterion.description,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
