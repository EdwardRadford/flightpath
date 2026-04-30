// Brief screen — displays the exercise overview, aim, today's focus,
// CAA assessment criteria, and secondary detail sections behind a disclosure.
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
import 'package:go_router/go_router.dart';

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

  String? _openSectionKey = 'overview_aim';
  bool _secondaryExpanded = false;

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
    final updated = existing?.copyWith(
          briefViewed: true,
          status: existing.status == ExerciseStatus.notStarted
              ? ExerciseStatus.inProgress
              : existing.status,
        ) ??
        UserExercise(
          id: '',
          exerciseId: exerciseId,
          subExercise: subExerciseId,
          exerciseNumber: content.exerciseNumber,
          status: ExerciseStatus.inProgress,
          timesAttempted: 0,
          ratingHistory: const [],
          briefViewed: true,
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

        final exerciseLabel = content.subExercise != null
            ? 'Exercise ${content.subExercise}'
            : 'Exercise ${content.exerciseNumber}';

        final flashcardsAsync = ref.watch(
          flashcardsProvider(widget.compositeExerciseId),
        );
        final hasFlashcards =
            flashcardsAsync.whenOrNull(data: (list) => list.isNotEmpty) ??
                true;

        void openSection(String key) {
          setState(() {
            _openSectionKey = _openSectionKey == key ? null : key;
          });
        }

        final bool hasSecondarySections = content.commonMistakes.isNotEmpty ||
            content.oneThingToNail.isNotEmpty ||
            content.masteryCriteria.isNotEmpty ||
            showTip ||
            skillsTestStandards.containsKey(widget.compositeExerciseId);

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
              // Ask AI chip
              ActionChip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text('Ask AI about $exerciseLabel'),
                onPressed: () => context.push(
                  '/ask-ai',
                  extra:
                      'Tell me about $exerciseLabel: ${content.exerciseName}',
                ),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                ),
                iconTheme: const IconThemeData(color: AppColors.primary),
              ),
              const SizedBox(height: 16),

              // 1. Overview + Aim — collapsible, starts open
              if (content.overview.isNotEmpty || content.aim.isNotEmpty) ...[
                _AccordionSection(
                  sectionKey: 'overview_aim',
                  title: 'Overview & Aim',
                  isOpen: _openSectionKey == 'overview_aim',
                  onToggle: () => openSection('overview_aim'),
                  child: _OverviewAimBody(
                    overview: content.overview,
                    aim: content.aim,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 2. Today's Focus — keyFocusAreas + whatToExpect
              if (content.keyFocusAreas.isNotEmpty ||
                  content.whatToExpect.isNotEmpty) ...[
                _AccordionSection(
                  sectionKey: 'todays_focus',
                  title: "Today's Focus",
                  isOpen: _openSectionKey == 'todays_focus',
                  onToggle: () => openSection('todays_focus'),
                  child: _TodaysFocusBody(
                    keyFocusAreas: content.keyFocusAreas,
                    whatToExpect: content.whatToExpect,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 3. CAA Assessment Criteria — always shown if present
              if (ExerciseCriteria.exerciseCriteria
                  .containsKey(widget.compositeExerciseId)) ...[
                _AccordionSection(
                  sectionKey: 'caa_criteria',
                  title: 'CAA Assessment Criteria',
                  isOpen: _openSectionKey == 'caa_criteria',
                  onToggle: () => openSection('caa_criteria'),
                  child: _CriteriaList(
                    criteria: ExerciseCriteria
                        .exerciseCriteria[widget.compositeExerciseId]!,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // See more — secondary sections disclosed on demand
              if (hasSecondarySections) ...[
                _SeeMoreRow(
                  expanded: _secondaryExpanded,
                  onToggle: () =>
                      setState(() => _secondaryExpanded = !_secondaryExpanded),
                ),
                if (_secondaryExpanded) ...[
                  const SizedBox(height: 12),

                  if (content.commonMistakes.isNotEmpty) ...[
                    _AccordionSection(
                      sectionKey: 'common_mistakes',
                      title: 'Common Mistakes',
                      icon: Icons.warning_amber_rounded,
                      iconColor: AppColors.warning,
                      isOpen: _openSectionKey == 'common_mistakes',
                      onToggle: () => openSection('common_mistakes'),
                      child: _BulletList(
                        text: content.commonMistakes,
                        bulletColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (content.oneThingToNail.isNotEmpty) ...[
                    _AccordionSection(
                      sectionKey: 'one_thing',
                      title: 'One Thing to Nail',
                      isOpen: _openSectionKey == 'one_thing',
                      onToggle: () => openSection('one_thing'),
                      child: Text(
                        content.oneThingToNail,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (content.masteryCriteria.isNotEmpty) ...[
                    _AccordionSection(
                      sectionKey: 'mastery_criteria',
                      title: 'Mastery Criteria',
                      isOpen: _openSectionKey == 'mastery_criteria',
                      onToggle: () => openSection('mastery_criteria'),
                      child: Text(
                        content.masteryCriteria,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (showTip) ...[
                    _AccordionSection(
                      sectionKey: 'aircraft_tips',
                      title: 'Aircraft Tips',
                      icon: Icons.airplanemode_active_rounded,
                      iconColor: AppColors.primary,
                      isOpen: _openSectionKey == 'aircraft_tips',
                      onToggle: () => openSection('aircraft_tips'),
                      child: _AircraftTipBody(
                        aircraftType: aircraftType,
                        tip: aircraftTip,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (skillsTestStandards
                      .containsKey(widget.compositeExerciseId)) ...[
                    _AccordionSection(
                      sectionKey: 'skills_test',
                      title: 'Skills Test Standard',
                      icon: Icons.school_rounded,
                      iconColor: AppColors.primary,
                      isOpen: _openSectionKey == 'skills_test',
                      onToggle: () => openSection('skills_test'),
                      child: Text(
                        skillsTestStandards[widget.compositeExerciseId]!,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 12),
              ],

              // Active Recall — always at bottom before checklist
              _ActiveRecallCard(key: _recallKey),

              // Pre-flight checklist — static, read-only
              if (content.preFlightChecklist.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StaticChecklist(checklistText: content.preFlightChecklist),
              ],

              // Action buttons
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: hasFlashcards
                      ? () {
                          FirebaseAnalytics.instance.logEvent(
                            name: 'brief_next_tapped',
                            parameters: {
                              'exercise_id': widget.compositeExerciseId,
                              'destination': 'flashcards',
                            },
                          );
                          context.push(
                            '/exercises/${widget.compositeExerciseId}/flashcards',
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text('Next: Flashcards'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
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
                  icon: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
                  label: Text(
                    'Done — Back to Prepare',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
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

class _AccordionSection extends StatelessWidget {
  final String sectionKey;
  final String title;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;
  final bool isOpen;
  final VoidCallback onToggle;

  const _AccordionSection({
    required this.sectionKey,
    required this.title,
    required this.child,
    required this.isOpen,
    required this.onToggle,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOpen
                ? AppColors.primary.withValues(alpha: 0.4)
                : cs.outline,
            width: isOpen ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon,
                        color: iconColor ?? AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ),
            ),
            if (isOpen) ...[
              Divider(color: cs.outline, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: child,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Merged Overview + Aim card — always fully expanded (no accordion toggle).
class _OverviewAimBody extends StatelessWidget {
  final String overview;
  final String aim;

  const _OverviewAimBody({required this.overview, required this.aim});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overview.isNotEmpty)
          Text(
            overview,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        if (aim.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Aim',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            aim,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// Today's Focus section body — keyFocusAreas as bullets, whatToExpect as prose.
class _TodaysFocusBody extends StatelessWidget {
  final String keyFocusAreas;
  final String whatToExpect;

  const _TodaysFocusBody({
    required this.keyFocusAreas,
    required this.whatToExpect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (keyFocusAreas.isNotEmpty) ...[
          _BulletList(
            text: keyFocusAreas,
            bulletColor: AppColors.primary,
          ),
        ],
        if (keyFocusAreas.isNotEmpty && whatToExpect.isNotEmpty)
          const SizedBox(height: 12),
        if (whatToExpect.isNotEmpty)
          Text(
            whatToExpect,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 15,
              height: 1.6,
            ),
          ),
      ],
    );
  }
}

/// Disclosure row that toggles secondary sections.
class _SeeMoreRow extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _SeeMoreRow({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Divider(color: cs.outline, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expanded ? 'See less' : 'See more',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Divider(color: cs.outline, height: 1),
            ),
          ],
        ),
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

/// Read-only pre-flight checklist — numbered icon bullets, no interaction.
class _StaticChecklist extends StatelessWidget {
  final String checklistText;

  const _StaticChecklist({required this.checklistText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = checklistText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

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
          Text(
            'Pre-Flight Checklist',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outline, height: 1),
          const SizedBox(height: 10),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final text = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1, right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      text,
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
          }),
        ],
      ),
    );
  }
}

class _AircraftTipBody extends StatelessWidget {
  final String aircraftType;
  final String tip;

  const _AircraftTipBody({required this.aircraftType, required this.tip});

  String _aircraftLabel(String type) =>
      AppConstants.aircraftTypes[type] ?? type;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_aircraftLabel(aircraftType)} Tips',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tip,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
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

class _CriteriaList extends StatelessWidget {
  final List<ExerciseCriterion> criteria;

  const _CriteriaList({required this.criteria});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What your instructor will assess on this exercise',
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        ...criteria.map((c) => Padding(
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
                          c.label,
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.description,
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
            )),
      ],
    );
  }
}
