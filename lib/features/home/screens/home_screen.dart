// Home screen — exercise-centric dashboard showing current exercise progress.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/constants/whats_new_data.dart';
import 'package:flight_path/shared/providers/walkthrough_provider.dart';
import 'package:flight_path/shared/widgets/app_tour_dialog.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/services/whats_new_service.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/home/providers/daily_question_provider.dart';
import 'package:flight_path/features/home/providers/home_provider.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/quiz_question.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// ---------------------------------------------------------------------------
// Helper: greeting based on hour of day
// ---------------------------------------------------------------------------

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

// ---------------------------------------------------------------------------
// Helper: build the route path for an exercise + optional sub-exercise
// ---------------------------------------------------------------------------

String _exerciseRoute(String exerciseId, String? subExerciseId) {
  if (subExerciseId != null) {
    return '/exercises/${exerciseId}_$subExerciseId';
  }
  return '/exercises/$exerciseId';
}

// ---------------------------------------------------------------------------
// Helper: format hours and minutes
// ---------------------------------------------------------------------------

String _formatHoursMinutes(double hours) {
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '${m}min';
  if (m == 0) return '${h}hr';
  return '${h}hr ${m}min';
}

// ---------------------------------------------------------------------------
// Helper: check for app update and show What's New bottom sheet
// ---------------------------------------------------------------------------

Future<void> _checkWhatsNew(BuildContext context) async {
  final shouldShow = await WhatsNewService.instance.shouldShowWhatsNew();
  if (!shouldShow || !context.mounted) return;

  final cs = Theme.of(context).colorScheme;
  final latest = whatsNewEntries.first;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: ListView(
          controller: scrollController,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "What's New in v${latest.version}",
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              latest.date,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ...latest.changes.map((change) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          change,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// Resets the static walkthrough guard so the tour can be replayed
  /// within the same app session (called from Settings > Replay App Tour).
  static void resetWalkthroughGuard() {
    _HomeScreenState._walkthroughChecked = false;
  }

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Tracks whether the What's New check has been performed this session.
  static bool _whatsNewChecked = false;

  /// Tracks whether the walkthrough check has been performed this session.
  static bool _walkthroughChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_whatsNewChecked) {
        _whatsNewChecked = true;
        _checkWhatsNew(context);
      }
      _triggerWalkthrough();
    });
  }

  Future<void> _triggerWalkthrough() async {
    // Wait for What's New to clear
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final walkthroughDone = await ref.read(walkthroughCompleteProvider.future);
    if (walkthroughDone || _walkthroughChecked) return;

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null || user.isInstructor) return;

    _walkthroughChecked = true;
    if (!mounted) return;

    await showAppTourDialog(context);
    if (!mounted) return;
    await ref.read(walkthroughNotifierProvider.notifier).markComplete();
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(appUserProvider);
    final recentAsync = ref.watch(recentLessonsProvider);
    final quickStats = ref.watch(quickStatsProvider);
    final suggestedExercise = ref.watch(suggestedExerciseProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(recentLessonsProvider);
            ref.invalidate(appUserProvider);
            ref.invalidate(suggestedExerciseProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // -- 1. Greeting header
                appUserAsync.when(
                  data: (user) => _GreetingHeader(user: user),
                  loading: () => const _GreetingHeader(user: null),
                  error: (_, __) => const _GreetingHeader(user: null),
                ),

                const SizedBox(height: 20),

                // -- 2. Quick Stats Row
                if (quickStats != null) ...[
                  _QuickStatsRow(stats: quickStats),
                  const SizedBox(height: 20),
                ],

                // -- 3. Current Exercise card (replaces Next Lesson Hero)
                _CurrentExerciseCard(
                  suggestedExercise: suggestedExercise,
                  ref: ref,
                ),

                const SizedBox(height: 20),

                // -- 4. Daily Question
                const _DailyQuestionCard(),

                const SizedBox(height: 20),

                // -- 5. Recent Activity (limited to 3)
                recentAsync.when(
                  data: (lessons) => _RecentActivitySection(
                    lessons: lessons.take(3).toList(),
                  ),
                  loading: () => const _RecentActivityLoading(),
                  error: (_, __) =>
                      const _RecentActivitySection(lessons: []),
                ),

                const SizedBox(height: 20),

                // -- 6. Ask AI card
                const _AskAiCard(),

                const SizedBox(height: 20),

                // -- 7. Upgrade prompt (shown for free users only)
                appUserAsync.when(
                  data: (user) {
                    if (user == null || user.isPremium) {
                      return const SizedBox.shrink();
                    }
                    return const _UpgradePromptCard();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Greeting header
// ---------------------------------------------------------------------------

class _GreetingHeader extends StatelessWidget {
  final AppUser? user;
  const _GreetingHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstName = _extractFirstName(user?.displayName ?? '');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isNotEmpty
                    ? '${_greeting()}, $firstName'
                    : _greeting(),
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitleText(user),
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/settings/profile'),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  static String _extractFirstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').first;
  }

  static String _subtitleText(AppUser? user) {
    if (user == null) return 'Welcome to Flight Path';
    final aircraft =
        AppConstants.aircraftTypes[user.aircraftType] ?? '';
    if (aircraft.isNotEmpty) return 'Flying a $aircraft';
    return 'Welcome to Flight Path';
  }
}

// ---------------------------------------------------------------------------
// 2. Current Exercise Card (replaces Next Lesson Hero)
// ---------------------------------------------------------------------------

class _CurrentExerciseCard extends StatelessWidget {
  final AsyncValue<SuggestedExercise?> suggestedExercise;
  final WidgetRef ref;

  const _CurrentExerciseCard({
    required this.suggestedExercise,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return suggestedExercise.when(
      data: (suggested) => _buildCard(context, suggested),
      loading: () => _buildLoadingCard(context),
      error: (_, __) => _buildCard(context, null),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildCard(BuildContext context, SuggestedExercise? suggested) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // No suggested exercise — all complete or no data
    if (suggested == null) {
      return _buildAllCompleteCard(context, cs, isDark);
    }

    final compositeId = suggested.subExerciseId != null
        ? '${suggested.exerciseId}_${suggested.subExerciseId}'
        : suggested.exerciseId;
    final displayName = exerciseDisplayName(compositeId);
    final fullName = exerciseFullName(compositeId);
    final routePath =
        _exerciseRoute(suggested.exerciseId, suggested.subExerciseId);

    // Look up prep progress
    final userExercises =
        ref.watch(userExercisesProvider).valueOrNull ?? [];
    UserExercise? matchingUe;
    for (final ue in userExercises) {
      if (compositeExerciseId(ue.exerciseId, ue.subExercise) ==
          compositeId) {
        matchingUe = ue;
        break;
      }
    }

    final briefDone = matchingUe != null && matchingUe.timesAttempted > 0;
    final quizDone = matchingUe?.quizPassed ?? false;
    final videoDone = matchingUe?.videoWatched ?? false;

    final prepItems = [
      (label: 'Brief', done: briefDone, icon: Icons.menu_book_rounded),
      (label: 'Quiz', done: quizDone, icon: Icons.quiz_rounded),
      (label: 'Video', done: videoDone, icon: Icons.play_circle_rounded),
    ];
    final doneCount = prepItems.where((item) => item.done).length;
    final allPrepped = doneCount == prepItems.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  AppColors.heroGradientStart,
                  AppColors.heroGradientEnd,
                ]
              : [AppColors.primaryLight, AppColors.surfaceVariantLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT EXERCISE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        suggested.reason,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Exercise name
            Text(
              displayName,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (fullName != displayName) ...[
              const SizedBox(height: 4),
              Text(
                fullName,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Prep progress indicators
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        allPrepped
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        color: allPrepped
                            ? AppColors.success
                            : AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        allPrepped
                            ? 'Preparation Complete'
                            : '$doneCount of ${prepItems.length} completed',
                        style: TextStyle(
                          color: allPrepped
                              ? AppColors.success
                              : AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < prepItems.length; i++) ...[
                        if (i > 0) const Spacer(),
                        _PrepCheckItem(
                          label: prepItems[i].label,
                          done: prepItems[i].done,
                          icon: prepItems[i].icon,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(routePath),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      allPrepped ? AppColors.success : AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allPrepped
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      allPrepped ? "You're Ready!" : 'Continue Preparing',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCompleteCard(
      BuildContext context, ColorScheme cs, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  AppColors.heroGradientStart,
                  AppColors.heroGradientEnd,
                ]
              : [AppColors.primaryLight, AppColors.surfaceVariantLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'All Exercises Complete',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Great work! Review your progress or revisit any exercise from the exercises tab.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/progress'),
              icon: const Icon(Icons.insights_rounded, size: 18),
              label: const Text('View Progress',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prep check item
// ---------------------------------------------------------------------------

class _PrepCheckItem extends StatelessWidget {
  final String label;
  final bool done;
  final IconData icon;
  const _PrepCheckItem({
    required this.label,
    required this.done,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${done ? 'completed' : 'not completed'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? AppColors.success : AppColors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: done ? AppColors.success : AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Quick Stats Row
// ---------------------------------------------------------------------------

class _QuickStatsRow extends StatelessWidget {
  final QuickStats stats;
  const _QuickStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              label: 'Flown',
              value: _formatHoursMinutes(stats.hoursFlown),
              icon: Icons.flight_rounded,
              iconColor: AppColors.statHours,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Exercises',
              value: '${stats.exercisesCompleted}/${stats.totalExercises}',
              icon: Icons.menu_book_outlined,
              iconColor: AppColors.statExercises,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: stats.daysSinceLastLesson < 0
                  ? 'Lessons'
                  : 'Last Lesson',
              value: stats.daysSinceLastLesson < 0
                  ? '${stats.completedLessons}'
                  : stats.daysSinceLastLesson == 0
                      ? 'Today'
                      : '${stats.daysSinceLastLesson}d ago',
              icon: stats.daysSinceLastLesson < 0
                  ? Icons.check_circle_outline_rounded
                  : Icons.schedule_rounded,
              iconColor: stats.daysSinceLastLesson < 0
                  ? AppColors.success
                  : stats.daysSinceLastLesson > 14
                      ? AppColors.warning
                      : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(height: 8),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Daily Question Card
// ---------------------------------------------------------------------------

class _DailyQuestionCard extends ConsumerStatefulWidget {
  const _DailyQuestionCard();

  @override
  ConsumerState<_DailyQuestionCard> createState() =>
      _DailyQuestionCardState();
}

class _DailyQuestionCardState extends ConsumerState<_DailyQuestionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _onRevealTapped(QuizQuestion question) async {
    await ref.read(dailyQuestionProvider.notifier).markAnswered();
    _expandController.forward();
    FirebaseAnalytics.instance.logEvent(
      name: 'daily_question_answered',
      parameters: {
        'question_id': question.id,
        'exercise_id': question.exerciseId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyQuestionProvider);
    final cs = Theme.of(context).colorScheme;

    if (state.loading) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    if (state.error != null || state.question == null) {
      return const SizedBox.shrink();
    }

    final question = state.question!;

    if (state.answered && _expandController.isDismissed) {
      _expandController.value = 1.0;
    }

    String correctAnswerText;
    if (question.questionType == QuestionType.trueFalse) {
      correctAnswerText =
          question.correctAnswer == 'true' ? 'True' : 'False';
    } else {
      final match = question.options
          .where((e) => e.key == question.correctAnswer)
          .firstOrNull;
      correctAnswerText = match != null
          ? '${question.correctAnswer.toUpperCase()}. ${match.value}'
          : question.correctAnswer.toUpperCase();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.quiz_rounded,
                      color: AppColors.primary, size: 15),
                ),
                const SizedBox(width: 10),
                const Text('Daily Question',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    )),
              ],
            ),
            const SizedBox(height: 12),

            // Question text
            Text(question.question,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                )),
            const SizedBox(height: 14),

            // Answer reveal
            SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, thickness: 1, color: cs.outline),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CORRECT ANSWER',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: 4),
                        Text(correctAnswerText,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                  if (question.explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(question.explanation,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.5,
                        )),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Reveal button
            if (!state.answered)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _onRevealTapped(question),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reveal Answer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Recent Activity Section
// ---------------------------------------------------------------------------

class _RecentActivitySection extends StatelessWidget {
  final List<Lesson> lessons;
  const _RecentActivitySection({required this.lessons});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (lessons.isEmpty) {
      return const _EmptyRecentActivity();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with "View All"
        Row(
          children: [
            const Icon(Icons.history_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Recent Activity',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            TextButton(
              onPressed: () => context.push('/logbook'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Lesson list
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: lessons.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: cs.outline,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) =>
                _LessonListItem(lesson: lessons[index]),
          ),
        ),
      ],
    );
  }
}

class _EmptyRecentActivity extends StatelessWidget {
  const _EmptyRecentActivity();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flight_takeoff_rounded,
            color: AppColors.primary.withValues(alpha: 0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Ready for your first lesson?',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Start by exploring the exercises to build your preparation plan.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.55),
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => context.push('/exercises'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBright,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Browse Exercises',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityLoading extends StatelessWidget {
  const _RecentActivityLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _LessonListItem extends StatelessWidget {
  final Lesson lesson;
  const _LessonListItem({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compositeId = lesson.subExercise.isNotEmpty
        ? '${lesson.exerciseId}_${lesson.subExercise}'
        : lesson.exerciseId;
    final displayName = exerciseDisplayName(compositeId);
    final date =
        lesson.lessonDate ?? lesson.scheduledDate ?? lesson.createdAt;
    final formattedDate = DateFormat('dd MMM yyyy').format(date);

    return InkWell(
      onTap: () => context.push('/lesson-detail', extra: lesson),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _statusColor(lesson.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(formattedDate,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          )),
                      if (lesson.status == LessonStatus.completed &&
                          lesson.studentRating != null) ...[
                        const SizedBox(width: 10),
                        _StarRating(rating: lesson.studentRating!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(LessonStatus status) {
    switch (status) {
      case LessonStatus.scheduled:
        return AppColors.statusScheduled;
      case LessonStatus.prepared:
        return AppColors.warning;
      case LessonStatus.completed:
        return AppColors.success;
      case LessonStatus.cancelled:
        return AppColors.onSurfaceVariant;
      case LessonStatus.manualEntry:
        return AppColors.statusManualEntry;
    }
  }
}

class _StarRating extends StatelessWidget {
  final int rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: AppColors.warning, size: 13),
        const SizedBox(width: 2),
        Text('$rating/5',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              fontSize: 12,
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Ask AI Card
// ---------------------------------------------------------------------------

class _AskAiCard extends StatelessWidget {
  const _AskAiCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => context.push('/ask-ai'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask Your AI Instructor',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Get answers to any PPL question',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Upgrade Prompt Card
// ---------------------------------------------------------------------------

class _UpgradePromptCard extends ConsumerWidget {
  const _UpgradePromptCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(appUserProvider).valueOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unlock All 19 Exercises',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "You're on the free plan. Upgrade once to unlock every exercise, AI debriefs, and instructor sharing.",
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.65),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                showPremiumPaywall(
                  context,
                  source: 'home_upgrade_prompt',
                  freeWindowStart: user?.freeWindowStart ?? 1,
                  freeWindowEnd: user?.freeWindowEnd ?? 3,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Upgrade to Pro — £${AppConstants.premiumPriceGbp.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
