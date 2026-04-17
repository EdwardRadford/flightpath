// Home screen — exercise-centric dashboard showing current exercise progress.
// Presentational widgets extracted into lib/features/home/widgets/ during the
// 2026-04-13 refactor. This file is intentionally a slim shell: it owns the
// post-frame session gates (What's New, walkthrough) and composes the column
// of section widgets below.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/constants/whats_new_data.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/home/providers/home_provider.dart';
import 'package:flight_path/features/home/widgets/current_exercise_card.dart';
import 'package:flight_path/features/home/widgets/daily_question_card.dart';
import 'package:flight_path/features/home/widgets/greeting_header.dart';
import 'package:flight_path/features/home/widgets/home_footer_cards.dart';
import 'package:flight_path/features/home/widgets/quick_stats_row.dart';
import 'package:flight_path/features/home/widgets/recent_activity_section.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
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
                  data: (user) => GreetingHeader(user: user),
                  loading: () => const GreetingHeader(user: null),
                  error: (_, __) => const GreetingHeader(user: null),
                ),

                const SizedBox(height: 20),

                // -- 2. Quick Stats Row
                if (quickStats != null) ...[
                  QuickStatsRow(stats: quickStats),
                  const SizedBox(height: 20),
                ],

                // -- 3. Current Exercise card (replaces Next Lesson Hero)
                CurrentExerciseCard(
                  suggestedExercise: suggestedExercise,
                  ref: ref,
                ),

                const SizedBox(height: 20),

                // -- 4. Daily Question
                const DailyQuestionCard(),

                const SizedBox(height: 20),

                // -- 5. Recent Activity (limited to 3)
                recentAsync.when(
                  data: (lessons) => RecentActivitySection(
                    lessons: lessons.take(3).toList(),
                  ),
                  loading: () => const RecentActivityLoading(),
                  error: (_, __) =>
                      const RecentActivitySection(lessons: []),
                ),

                const SizedBox(height: 20),

                // -- 6. Weather preview
                const WeatherPreviewCard(),

                const SizedBox(height: 20),

                // -- 7. Debrief nudge (shown when > 3 days since last debrief)
                const DebriefNudgeCard(),

                const SizedBox(height: 20),

                // -- 8. Streak card
                const StreakCard(),

                const SizedBox(height: 20),

                // -- 9. Ask AI card
                const AskAiCard(),

                const SizedBox(height: 20),

                // -- 10. Upgrade prompt (shown for free users only)
                appUserAsync.when(
                  data: (user) {
                    if (user == null || user.isPremium) {
                      return const SizedBox.shrink();
                    }
                    return const UpgradePromptCard();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 20),

                // -- 11. Share card
                const ShareCard(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
