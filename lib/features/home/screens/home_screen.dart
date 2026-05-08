// Home screen — exercise-centric dashboard showing current exercise progress.
// Presentational widgets extracted into lib/features/home/widgets/ during the
// 2026-04-13 refactor. This file is intentionally a slim shell: it owns the
// post-frame session gates (What's New, walkthrough) and composes the column
// of section widgets below.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flight_path/core/constants/whats_new_data.dart';
import 'package:flight_path/core/theme/app_icons.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/home/providers/home_provider.dart';
import 'package:flight_path/features/home/widgets/current_exercise_card.dart';
import 'package:flight_path/features/home/widgets/first_solo_milestone_card.dart';
import 'package:flight_path/features/home/widgets/greeting_header.dart';
import 'package:flight_path/features/home/widgets/home_footer_cards.dart';
import 'package:flight_path/features/home/widgets/lesson_day_card.dart';
import 'package:flight_path/features/home/widgets/mention_instructor_nudge_card.dart';
import 'package:flight_path/features/home/widgets/quick_stats_row.dart';
import 'package:flight_path/features/home/widgets/recent_activity_section.dart';
import 'package:flight_path/features/home/widgets/recency_warning_card.dart';
import 'package:flight_path/features/home/widgets/study_streak_card.dart';
import 'package:flight_path/features/home/widgets/test_prep_countdown_card.dart';
import 'package:flight_path/features/home/widgets/this_week_digest_card.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/providers/walkthrough_provider.dart';
import 'package:flight_path/shared/services/whats_new_service.dart';
import 'package:flight_path/shared/widgets/app_tour_dialog.dart';

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
    backgroundColor: cs.surfaceContainerHighest,
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
    if (user == null) return;

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
      floatingActionButton: Semantics(
        label: 'Open AI Instructor',
        button: true,
        child: FloatingActionButton.small(
          onPressed: () => context.push('/ask-ai'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.auto_awesome_rounded),
        ),
      ),
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
                // -- Aircraft type warning banner.
                // Single tappable target with a chevron — no embedded link CTA.
                appUserAsync.maybeWhen(
                  data: (user) {
                    if (user != null && user.aircraftType.isEmpty) {
                      return Semantics(
                        label: 'Set your aircraft type in Settings',
                        button: true,
                        child: GestureDetector(
                          onTap: () => context.push('/settings'),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(AppIcons.warning,
                                    color: AppColors.warning, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Set your aircraft type in Settings to unlock all features',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontWeight: FontWeight.w500,
                                          height: 1.5,
                                        ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  orElse: () => const SizedBox.shrink(),
                ),

                // -- Greeting header
                appUserAsync.when(
                  data: (user) => GreetingHeader(user: user),
                  loading: () => const GreetingHeader(user: null),
                  error: (_, __) => const GreetingHeader(user: null),
                ),

                // -- Quick Stats Row
                if (quickStats != null) ...[
                  QuickStatsRow(stats: quickStats),
                  const SizedBox(height: 20),
                ],

                // ───────────────────────────────────────────────────────────
                // Priority block — 3 full-size cards
                // ───────────────────────────────────────────────────────────

                // 1. Current Exercise (always full-size)
                CurrentExerciseCard(
                  suggestedExercise: suggestedExercise,
                  ref: ref,
                ),

                // 2. Lesson Day (always full-size)
                const LessonDayCard(),

                // 3. Debrief Nudge (only when applicable, full-size)
                const DebriefNudgeCard(),

                // ───────────────────────────────────────────────────────────
                // Secondary "more" stack — compact rows
                // ───────────────────────────────────────────────────────────

                // Test prep countdown (only when within 21 days of skills test)
                const TestPrepCountdownCard(),

                // Study streak (compact)
                const StudyStreakCard(),

                // This week digest (compact)
                const ThisWeekDigestCard(),

                // Recency warning (hidden when not applicable, compact)
                const RecencyWarningCard(),

                // First solo milestone (shown when ex12 done, ex14 not yet, compact)
                const FirstSoloMilestoneCard(),

                // Weather preview (compact)
                const WeatherPreviewCard(),

                // Ask AI (compact)
                const AskAiCard(),

                // Streak (compact)
                const StreakCard(),

                // Mention instructor nudge (compact)
                const MentionInstructorNudgeCard(),

                // Recent Activity (limited to 3)
                recentAsync.when(
                  data: (lessons) => RecentActivitySection(
                    lessons: lessons.take(3).toList(),
                  ),
                  loading: () => const RecentActivityLoading(),
                  error: (_, __) =>
                      const RecentActivitySection(lessons: []),
                ),

                // Upgrade prompt (shown for free users only)
                if (!(ref.watch(premiumStatusProvider).valueOrNull ?? false))
                  const UpgradePromptCard(),

                const SizedBox(height: 24),

                // -- 12. Feedback link
                Center(
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(
                        'mailto:contact@getflightpath.app'
                        '?subject=Flight%20Path%20Training%20Feedback',
                      ),
                    ),
                    child: Text(
                      'Send feedback',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant
                            .withValues(alpha: 0.55),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.onSurfaceVariant
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ),
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
