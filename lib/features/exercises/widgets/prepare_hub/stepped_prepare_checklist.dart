import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/tools/data/aircraft_data.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

// ---------------------------------------------------------------------------
// Step data class
// ---------------------------------------------------------------------------

enum _StepAction { route, weather, selfBrief, beforeYouFly }

class _StepItem {
  final int stepNumber;
  final IconData icon;
  final String label;
  final bool done;
  final String route;
  final String statusLabel;
  final _StepAction action;

  const _StepItem({
    required this.stepNumber,
    required this.icon,
    required this.label,
    required this.done,
    required this.route,
    required this.statusLabel,
    this.action = _StepAction.route,
  });
}

/// Public alias kept for any code that references [PrepareStepItem] externally.
typedef PrepareStepItem = _StepItem;

// ---------------------------------------------------------------------------
// Stepped prepare checklist
// ---------------------------------------------------------------------------

class SteppedPrepareChecklist extends ConsumerStatefulWidget {
  final String compositeExerciseId;
  final LessonType lessonType;
  final UserExercise? userExercise;
  final bool quizPassed;
  final bool locked;
  final ExerciseContent content;

  const SteppedPrepareChecklist({
    super.key,
    required this.compositeExerciseId,
    required this.lessonType,
    required this.userExercise,
    required this.quizPassed,
    required this.content,
    this.locked = false,
  });

  @override
  ConsumerState<SteppedPrepareChecklist> createState() =>
      _SteppedPrepareChecklistState();
}

class _SteppedPrepareChecklistState
    extends ConsumerState<SteppedPrepareChecklist> {
  Future<void> _markWeatherChecked() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);
    final existing = ref
        .read(userExercisesProvider)
        .valueOrNull
        ?.where(
          (ue) =>
              ue.exerciseId == exerciseId && ue.subExercise == subExerciseId,
        )
        .firstOrNull;
    if (existing == null) return;
    final firestore = ref.read(firestoreServiceProvider);
    await firestore.upsertUserExercise(
      uid,
      existing.copyWith(weatherChecked: true),
    );
  }

  Future<void> _markSelfBriefCompleted() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);
    final existing = ref
        .read(userExercisesProvider)
        .valueOrNull
        ?.where(
          (ue) =>
              ue.exerciseId == exerciseId && ue.subExercise == subExerciseId,
        )
        .firstOrNull;
    if (existing == null) return;
    final firestore = ref.read(firestoreServiceProvider);
    await firestore.upsertUserExercise(
      uid,
      existing.copyWith(selfBriefCompleted: true),
    );
  }

  void _openWeather() {
    _markWeatherChecked();
    context.push('/tools/weather');
  }

  void _openBeforeYouFly() {
    context.push('/exercises/${widget.compositeExerciseId}/before-you-fly');
  }

  void _openSelfBrief() {
    final aircraftType =
        ref.read(appUserProvider).valueOrNull?.aircraftType ?? '';
    final aircraft = aircraftDataForType(aircraftType);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelfBriefModal(
        content: widget.content,
        aircraft: aircraft,
        onConfirm: () {
          _markSelfBriefCompleted();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  List<PrepareStepItem> _buildSteps() {
    final bool briefDone = widget.userExercise?.briefViewed ?? false;
    final bool flashcardsDone =
        widget.userExercise?.flashcardsCompleted ?? false;
    final bool beforeYouFlyDone =
        widget.userExercise?.beforeYouFlyViewed ?? false;
    final bool weatherDone = widget.userExercise?.weatherChecked ?? false;
    final bool selfBriefDone =
        widget.userExercise?.selfBriefCompleted ?? false;
    final String briefStatusLabel =
        widget.userExercise?.briefStatus ?? 'Not Viewed';
    final String flashcardsStatusLabel =
        widget.userExercise?.flashcardsStatus ?? 'Not Started';
    final String quizStatusLabel =
        widget.userExercise?.quizStatus ?? 'Not Started';

    switch (widget.lessonType) {
      case LessonType.ground:
        return [
          PrepareStepItem(
            stepNumber: 1,
            icon: Icons.menu_book_rounded,
            label: 'Brief',
            done: briefDone,
            route: '/exercises/${widget.compositeExerciseId}/brief',
            statusLabel: briefStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 2,
            icon: Icons.edit_rounded,
            label: 'Quiz',
            done: widget.quizPassed,
            route: '/exercises/${widget.compositeExerciseId}/quiz',
            statusLabel: quizStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 3,
            icon: Icons.style_rounded,
            label: 'Flashcards',
            done: flashcardsDone,
            route: '/exercises/${widget.compositeExerciseId}/flashcards',
            statusLabel: flashcardsStatusLabel,
          ),
        ];

      case LessonType.milestone:
        // Exercise 14 (First Solo) is a milestone but students still need to
        // complete the full flight prep flow. Return the same steps as a
        // standard flight lesson. Other milestone exercises (none today, but
        // future-proof) keep the lightweight "Schedule Your Lesson" step.
        if (widget.compositeExerciseId == 'ex_14') {
          return [
            PrepareStepItem(
              stepNumber: 1,
              icon: Icons.menu_book_rounded,
              label: 'Brief',
              done: briefDone,
              route: '/exercises/${widget.compositeExerciseId}/brief',
              statusLabel: briefStatusLabel,
            ),
            PrepareStepItem(
              stepNumber: 2,
              icon: Icons.style_rounded,
              label: 'Flashcards',
              done: flashcardsDone,
              route: '/exercises/${widget.compositeExerciseId}/flashcards',
              statusLabel: flashcardsStatusLabel,
            ),
            PrepareStepItem(
              stepNumber: 3,
              icon: Icons.flight_takeoff_rounded,
              label: 'Before You Fly',
              done: beforeYouFlyDone,
              route: '/exercises/${widget.compositeExerciseId}/before-you-fly',
              statusLabel: beforeYouFlyDone ? 'Viewed' : 'Not Started',
              action: _StepAction.beforeYouFly,
            ),
            PrepareStepItem(
              stepNumber: 4,
              icon: Icons.cloud_rounded,
              label: 'Weather',
              done: weatherDone,
              route: '/tools/weather',
              statusLabel: weatherDone ? 'Checked' : 'Not Checked',
              action: _StepAction.weather,
            ),
            PrepareStepItem(
              stepNumber: 5,
              icon: Icons.record_voice_over_rounded,
              label: 'Self-Brief',
              done: selfBriefDone,
              route: '',
              statusLabel: selfBriefDone ? 'Completed' : 'Not Started',
              action: _StepAction.selfBrief,
            ),
          ];
        }
        return [
          PrepareStepItem(
            stepNumber: 1,
            icon: Icons.calendar_today_rounded,
            label: 'Schedule Your Lesson',
            done: false,
            route: '/exercises/${widget.compositeExerciseId}/schedule',
            statusLabel: 'Not Started',
          ),
        ];

      case LessonType.flight:
        return [
          PrepareStepItem(
            stepNumber: 1,
            icon: Icons.menu_book_rounded,
            label: 'Brief',
            done: briefDone,
            route: '/exercises/${widget.compositeExerciseId}/brief',
            statusLabel: briefStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 2,
            icon: Icons.style_rounded,
            label: 'Flashcards',
            done: flashcardsDone,
            route: '/exercises/${widget.compositeExerciseId}/flashcards',
            statusLabel: flashcardsStatusLabel,
          ),
          PrepareStepItem(
            stepNumber: 3,
            icon: Icons.flight_takeoff_rounded,
            label: 'Before You Fly',
            done: beforeYouFlyDone,
            route: '/exercises/${widget.compositeExerciseId}/before-you-fly',
            statusLabel: beforeYouFlyDone ? 'Viewed' : 'Not Started',
            action: _StepAction.beforeYouFly,
          ),
          PrepareStepItem(
            stepNumber: 4,
            icon: Icons.cloud_rounded,
            label: 'Weather',
            done: weatherDone,
            route: '/tools/weather',
            statusLabel: weatherDone ? 'Checked' : 'Not Checked',
            action: _StepAction.weather,
          ),
          PrepareStepItem(
            stepNumber: 5,
            icon: Icons.record_voice_over_rounded,
            label: 'Self-Brief',
            done: selfBriefDone,
            route: '',
            statusLabel: selfBriefDone ? 'Completed' : 'Not Started',
            action: _StepAction.selfBrief,
          ),
        ];
    }
  }

  void _handleStepTap(PrepareStepItem step) {
    switch (step.action) {
      case _StepAction.weather:
        _openWeather();
      case _StepAction.selfBrief:
        _openSelfBrief();
      case _StepAction.beforeYouFly:
        _openBeforeYouFly();
      case _StepAction.route:
        context.push(step.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final completedCount = steps.where((s) => s.done).length;
    final totalCount = steps.length;
    final allDone = completedCount == totalCount;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    final firstIncomplete = steps.where((s) => !s.done).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: allDone
                  ? AppColors.success.withValues(alpha: 0.5)
                  : AppColors.divider,
              width: allDone ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    allDone ? 'All Steps Complete!' : 'Preparation Progress',
                    style: TextStyle(
                      color:
                          allDone ? AppColors.success : AppColors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$completedCount of $totalCount steps',
                    style: TextStyle(
                      color: allDone
                          ? AppColors.success
                          : AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    allDone ? AppColors.success : AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
              if (allDone) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Great work! You\'re fully prepared for this lesson.',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Step list
        ...steps.map((step) {
          const viewableLabels = {'Brief'};
          final isStepLocked =
              widget.locked && !viewableLabels.contains(step.label);
          final isNext = !isStepLocked &&
              firstIncomplete != null &&
              step == firstIncomplete;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: isStepLocked
                ? _LockedStepCard(step: step, totalSteps: totalCount)
                : _StepCard(
                    step: step,
                    totalSteps: totalCount,
                    isNextStep: isNext,
                    onTap: () => _handleStepTap(step),
                  ),
          );
        }),

        // Start Next Step button
        if (firstIncomplete != null &&
            !({
              'Quiz',
              'Flashcards',
              'Schedule Your Lesson',
            }.contains(firstIncomplete.label) &&
                widget.locked)) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleStepTap(firstIncomplete),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                'Continue to Step ${firstIncomplete.stepNumber}: ${firstIncomplete.label}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step card
// ---------------------------------------------------------------------------

class _StepCard extends StatelessWidget {
  final _StepItem step;
  final int totalSteps;
  final bool isNextStep;
  final VoidCallback onTap;

  const _StepCard({
    required this.step,
    required this.totalSteps,
    required this.isNextStep,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = step.done
        ? AppColors.success.withValues(alpha: 0.5)
        : isNextStep
            ? AppColors.primary.withValues(alpha: 0.6)
            : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isNextStep ? 2 : 1.5,
          ),
          boxShadow: isNextStep
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Step number circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: step.done
                    ? AppColors.success
                    : isNextStep
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: step.done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : Text(
                        '${step.stepNumber}',
                        style: TextStyle(
                          color: isNextStep
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Icon
            Icon(
              step.icon,
              color: step.done
                  ? AppColors.success
                  : isNextStep
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Text(
                'Step ${step.stepNumber} of $totalSteps: ${step.label}',
                style: TextStyle(
                  color: step.done
                      ? AppColors.success
                      : isNextStep
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight:
                      isNextStep ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),

            // Status indicator
            if (step.done)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20)
            else if (step.statusLabel == 'Unsatisfactory')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Unsatisfactory',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (isNextStep)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked step card
// ---------------------------------------------------------------------------

class _LockedStepCard extends StatelessWidget {
  final _StepItem step;
  final int totalSteps;

  const _LockedStepCard({
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          // Step number circle (greyed)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${step.stepNumber}',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Label (greyed)
          Expanded(
            child: Text(
              'Step ${step.stepNumber} of $totalSteps: ${step.label}',
              style: TextStyle(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Pro badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, color: AppColors.primary, size: 11),
                const SizedBox(width: 3),
                Text(
                  'Pro',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

// ---------------------------------------------------------------------------
// Self-brief modal
// ---------------------------------------------------------------------------

class _SelfBriefModal extends StatefulWidget {
  final ExerciseContent content;
  final AircraftData? aircraft;
  final VoidCallback onConfirm;

  const _SelfBriefModal({
    required this.content,
    required this.aircraft,
    required this.onConfirm,
  });

  @override
  State<_SelfBriefModal> createState() => _SelfBriefModalState();
}

class _SelfBriefModalState extends State<_SelfBriefModal> {
  int _page = 0;

  static const int _totalPages = 4;

  String get _pageTitle => switch (_page) {
        0 => 'Exercise',
        1 => 'Key Speeds',
        2 => 'Limits & Considerations',
        _ => 'Ready to Fly',
      };

  Widget _buildPageContent() {
    switch (_page) {
      case 0:
        return _BriefPageText(text: widget.content.overview);
      case 1:
        return _KeySpeedsPage(aircraft: widget.aircraft);
      case 2:
        final text = widget.content.commonMistakes.isNotEmpty
            ? widget.content.commonMistakes
            : widget.content.keyFocusAreas;
        return _BriefPageText(text: text.isNotEmpty ? text : 'No specific limitations noted for this exercise.');
      case 3:
        return _ReadyToFlyPage(onConfirm: widget.onConfirm);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _page == _totalPages - 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.record_voice_over_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Self-Brief',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _pageTitle,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Step indicator
                    Text(
                      '${_page + 1} / $_totalPages',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_page + 1) / _totalPages,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: AppColors.divider, height: 1),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: _buildPageContent(),
                ),
              ),

              // Bottom button
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _page++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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

class _BriefPageText extends StatelessWidget {
  final String text;

  const _BriefPageText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.onSurface,
        fontSize: 15,
        height: 1.6,
      ),
    );
  }
}

class _KeySpeedsPage extends StatelessWidget {
  final AircraftData? aircraft;

  const _KeySpeedsPage({required this.aircraft});

  @override
  Widget build(BuildContext context) {
    if (aircraft == null) {
      return Text(
        'Set your aircraft type in your profile to see specific speeds.',
        style: TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 14,
          height: 1.5,
        ),
      );
    }

    final a = aircraft!;
    final speeds = [
      ('Vx — Best Angle of Climb', '${a.vx} kt'),
      ('Vy — Best Rate of Climb', '${a.vy} kt'),
      ('Va — Manoeuvring Speed', '${a.va} kt'),
      ('Vfe — Max Flap Extended', '${a.vfe} kt'),
      ('Approach Speed', '${a.approachSpeed} kt'),
      ('VS1 — Stall (Clean)', '${a.vs1} kt'),
      ('VS0 — Stall (Landing Config)', '${a.vs0} kt'),
      ('Best Glide', '${a.bestGlide} kt'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.displayName,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...speeds.map(
          (pair) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pair.$1,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pair.$2,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadyToFlyPage extends StatelessWidget {
  final VoidCallback onConfirm;

  const _ReadyToFlyPage({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'I have briefed myself on this exercise and am ready to fly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
