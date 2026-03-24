// Home screen — lesson-centric dashboard answering "I have a lesson
// scheduled. Am I prepared? What's the weather?"
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/constants/whats_new_data.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/core/services/weather_service.dart';
import 'package:flight_path/core/services/whats_new_service.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/home/providers/daily_question_provider.dart';
import 'package:flight_path/features/home/providers/home_provider.dart';
import 'package:flight_path/features/home/providers/weather_preview_provider.dart';
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
// Helper: human-readable countdown
// ---------------------------------------------------------------------------

String _countdownLabel(DateTime target) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(target.year, target.month, target.day);
  final diff = targetDay.difference(today).inDays;

  if (diff < 0) return '${-diff} day${diff == -1 ? '' : 's'} ago';
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return 'In $diff days';
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});



  /// Tracks whether the What's New check has been performed this session.
  static bool _whatsNewChecked = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check for app update and show What's New bottom sheet (once per session).
    if (!_whatsNewChecked) {
      _whatsNewChecked = true;
      _checkWhatsNew(context);
    }

    final appUserAsync = ref.watch(appUserProvider);
    final nextLesson = ref.watch(nextScheduledLessonProvider);
    final recentAsync = ref.watch(recentLessonsProvider);
    final quickStats = ref.watch(quickStatsProvider);
    final suggestedExercise = ref.watch(suggestedExerciseProvider);


    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            // Refresh weather
            final user = ref.read(appUserProvider).valueOrNull;
            final icao = user?.airfieldIcao ?? '';
            if (icao.isNotEmpty) {
              await ref
                  .read(weatherPreviewProvider.notifier)
                  .refresh(icao);
            }
            // Invalidate data providers
            ref.invalidate(recentLessonsProvider);
            ref.invalidate(appUserProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // -- 1. Greeting header
                appUserAsync.when(
                  data: (user) => _GreetingHeader(user: user),
                  loading: () => const _GreetingHeader(user: null),
                  error: (_, _) => const _GreetingHeader(user: null),
                ),

                const SizedBox(height: 24),

                // -- 2. Next Lesson Card (hero)
                _NextLessonHeroCard(lesson: nextLesson, ref: ref),

                const SizedBox(height: 16),

                // -- 2b. Context-aware action prompt
                _ContextActionCard(
                  suggestedExercise: suggestedExercise,
                  nextLesson: nextLesson,
                  ref: ref,
                ),

                const SizedBox(height: 20),

                // -- 3. Weather Preview
                const _WeatherPreviewCard(),

                const SizedBox(height: 16),

                // -- 3b. Ask AI card
                const _AskAiCard(),

                const SizedBox(height: 20),

                // -- 4. Quick Stats Row
                if (quickStats != null) ...[
                  _QuickStatsRow(stats: quickStats),
                  const SizedBox(height: 20),
                ],

                // -- 5. Daily Question
                const _DailyQuestionCard(),

                const SizedBox(height: 20),

                // -- 6. Recent Activity
                recentAsync.when(
                  data: (lessons) => _RecentActivitySection(
                    lessons: lessons.take(3).toList(),
                  ),
                  loading: () => const _RecentActivityLoading(),
                  error: (_, _) =>
                      const _RecentActivitySection(lessons: []),
                ),

                const SizedBox(height: 20),

                // -- 7. Upgrade prompt (shown for free users only)
                appUserAsync.when(
                  data: (user) {
                    if (user == null || user.isPremium) return const SizedBox.shrink();
                    return const _UpgradePromptCard();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
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
// 2. Next Lesson Hero Card
// ---------------------------------------------------------------------------

class _NextLessonHeroCard extends StatelessWidget {
  final Lesson? lesson;
  final WidgetRef ref;
  const _NextLessonHeroCard({required this.lesson, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (lesson == null) return _buildNoLessonCard(context);
    return _buildScheduledCard(context);
  }

  Widget _buildNoLessonCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [AppColors.heroGradientStart, AppColors.heroGradientEnd]
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
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'No Upcoming Lesson',
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
            'Schedule your next lesson to get a personalised preparation plan.',
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
              onPressed: () => context.push('/exercises'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Schedule a Lesson',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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

  Widget _buildScheduledCard(BuildContext context) {
    final l = lesson!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compositeId = l.subExercise != null
        ? '${l.exerciseId}_${l.subExercise}'
        : l.exerciseId;
    final displayName = exerciseDisplayName(compositeId);
    final fullName = exerciseFullName(compositeId);
    final routePath = _exerciseRoute(l.exerciseId, l.subExercise);
    final date = l.scheduledDate ?? l.createdAt;
    final formattedDate = DateFormat('EEEE, d MMMM').format(date);
    final countdown = _countdownLabel(date);

    // Look up prep status
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

    final briefDone =
        matchingUe != null && matchingUe.timesAttempted > 0;
    final quizDone = l.quizPassed == true;
    final videoDone = matchingUe?.videoWatched ?? false;
    final isPrepared = l.status == LessonStatus.prepared;

    final prepItems = [
      (label: 'Brief', done: briefDone || isPrepared, icon: Icons.menu_book_rounded),
      (label: 'Quiz', done: quizDone || isPrepared, icon: Icons.quiz_rounded),
      (label: 'Video', done: videoDone || isPrepared, icon: Icons.play_circle_rounded),
    ];
    final doneCount = prepItems.where((item) => item.done).length;
    final allPrepped = doneCount == prepItems.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [AppColors.heroGradientStart, AppColors.heroGradientEnd]
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
            // Countdown pill + date row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(countdown,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(formattedDate,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                      )),
                ),
                if (l.scheduledTime != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded,
                          color: cs.onSurface.withValues(alpha: 0.5),
                          size: 13),
                      const SizedBox(width: 4),
                      Text(l.scheduledTime!,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Exercise name
            Text(displayName,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                )),
            if (fullName != displayName) ...[
              const SizedBox(height: 4),
              Text(fullName,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                  )),
            ],
            const SizedBox(height: 16),

            // Prep status indicators
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
                      allPrepped
                          ? "You're Ready!"
                          : 'Continue Preparing',
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
// 3. Weather Preview Card
// ---------------------------------------------------------------------------

class _WeatherPreviewCard extends ConsumerWidget {
  const _WeatherPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherState = ref.watch(weatherPreviewProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final icao = user?.airfieldIcao ?? '';
    final cs = Theme.of(context).colorScheme;

    // If no ICAO set, show setup prompt
    if (icao.isEmpty) {
      return _buildCard(
        context: context,
        child: Row(
          children: [
            Icon(Icons.cloud_outlined,
                color: cs.onSurface.withValues(alpha: 0.4), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Set your airfield in profile to see weather here.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Loading state
    if (weatherState.loading && weatherState.data == null) {
      return _buildCard(
        context: context,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Loading weather for $icao...',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Error state
    if (weatherState.error != null && weatherState.data == null) {
      return _buildCard(
        context: context,
        child: Row(
          children: [
             Icon(Icons.cloud_off_rounded,
                color: AppColors.onSurfaceVariant, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Weather unavailable',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(weatherPreviewProvider.notifier)
                  .refresh(icao),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Data state
    if (weatherState.data == null) {
      return const SizedBox.shrink();
    }
    final w = weatherState.data!;
    final (Color statusColor, String statusLabel) = _flyingConditionInfo(w);

    return InkWell(
      onTap: () {
        // Navigate to exercises so the user can find the weather screen
        context.push('/exercises');
      },
      borderRadius: BorderRadius.circular(14),
      child: _buildCard(
        context: context,
        borderColor: statusColor.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  _weatherIcon(w.conditionId),
                  color: statusColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Weather at $icao',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Weather details row
            Row(
              children: [
                _WeatherDetailChip(
                  icon: Icons.thermostat_rounded,
                  value: '${w.temperature.round()}\u00B0C',
                  semanticLabel: 'Temperature: ${w.temperature.round()} degrees Celsius',
                ),
                const SizedBox(width: 16),
                _WeatherDetailChip(
                  icon: Icons.air_rounded,
                  value: w.windSpeed,
                  semanticLabel: 'Wind speed: ${w.windSpeed}',
                ),
                const SizedBox(width: 16),
                _WeatherDetailChip(
                  icon: Icons.visibility_rounded,
                  value: w.visibility,
                  semanticLabel: 'Visibility: ${w.visibility}',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Conditions + tap hint
            Row(
              children: [
                Expanded(
                  child: Text(
                    w.conditions,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.3), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required Widget child,
    Color? borderColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? cs.outline,
        ),
      ),
      child: child,
    );
  }

  static (Color, String) _flyingConditionInfo(WeatherData w) {
    if (!w.isSuitable) return (AppColors.error, 'Not Suitable');
    if (w.flightCategory == FlightCategory.mvfr) {
      return (AppColors.warning, 'Marginal');
    }
    if (w.windSpeedKt > 12) return (AppColors.warning, 'Breezy');
    return (AppColors.success, 'Good to Fly');
  }

  static IconData _weatherIcon(int conditionId) {
    if (conditionId >= 200 && conditionId <= 232) {
      return Icons.thunderstorm_rounded;
    }
    if (conditionId >= 300 && conditionId <= 531) {
      return Icons.water_drop_rounded;
    }
    if (conditionId >= 600 && conditionId <= 622) {
      return Icons.ac_unit_rounded;
    }
    if (conditionId >= 700 && conditionId <= 781) {
      return Icons.foggy;
    }
    if (conditionId == 800) return Icons.wb_sunny_rounded;
    if (conditionId == 801 || conditionId == 802) {
      return Icons.cloud_queue_rounded;
    }
    return Icons.cloud_rounded;
  }
}

class _WeatherDetailChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? semanticLabel;

  const _WeatherDetailChip({
    required this.icon,
    required this.value,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? value,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cs.onSurface.withValues(alpha: 0.45), size: 14),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
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
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Hours Flown',
            value: stats.hoursFlown.toStringAsFixed(1),
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
    await ref
        .read(dailyQuestionProvider.notifier)
        .markAnswered();
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
      return _EmptyRecentActivity();
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
            separatorBuilder: (_, _) => Divider(
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
    final compositeId = lesson.subExercise != null
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        const Icon(Icons.star_rounded,
            color: AppColors.warning, size: 13),
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
// 2b. Context-Aware Action Card
// ---------------------------------------------------------------------------

class _ContextActionCard extends StatelessWidget {
  final AsyncValue<SuggestedExercise?> suggestedExercise;
  final Lesson? nextLesson;
  final WidgetRef ref;

  const _ContextActionCard({
    required this.suggestedExercise,
    required this.nextLesson,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return suggestedExercise.when(
      data: (suggested) => _buildCard(context, suggested),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _buildFallbackCard(context),
    );
  }

  Widget _buildCard(BuildContext context, SuggestedExercise? suggested) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine what to show based on context.
    String title;
    String subtitle;
    IconData icon;
    VoidCallback onTap;

    if (suggested != null) {
      final compositeId = suggested.subExerciseId != null
          ? '${suggested.exerciseId}_${suggested.subExerciseId}'
          : suggested.exerciseId;
      final displayName = exerciseDisplayName(compositeId);
      final routePath = _exerciseRoute(
        suggested.exerciseId,
        suggested.subExerciseId,
      );

      // Check if this exercise is in-progress vs not started.
      final userExercises =
          ref.read(userExercisesProvider).valueOrNull ?? [];
      UserExercise? matchingUe;
      for (final ue in userExercises) {
        if (compositeExerciseId(ue.exerciseId, ue.subExercise) ==
            compositeId) {
          matchingUe = ue;
          break;
        }
      }

      // Check if the next lesson needs prep and matches this exercise.
      final lessonNeedsPrep = nextLesson != null &&
          nextLesson!.status == LessonStatus.scheduled;
      final lessonCompositeId = nextLesson != null
          ? compositeExerciseId(
              nextLesson!.exerciseId, nextLesson!.subExercise)
          : '';

      if (lessonNeedsPrep && lessonCompositeId == compositeId) {
        // Case c: prep incomplete for scheduled lesson.
        title = 'Finish Preparing for Your Lesson';
        subtitle = displayName;
        icon = Icons.checklist_rounded;
        onTap = () => context.push(routePath);
      } else if (matchingUe != null &&
          matchingUe.status == ExerciseStatus.inProgress) {
        // Case a: in-progress exercise.
        title = 'Continue $displayName';
        subtitle = suggested.reason;
        icon = Icons.play_circle_outline_rounded;
        onTap = () => context.push(routePath);
      } else {
        // Case b: next exercise to start.
        title = 'Ready for $displayName?';
        subtitle = suggested.reason;
        icon = Icons.arrow_circle_right_outlined;
        onTap = () => context.push(routePath);
      }
    } else {
      // Case d: fallback — all exercises complete or no suggestion.
      title = 'Start Your Next Exercise';
      subtitle = 'Browse all exercises';
      icon = Icons.explore_outlined;
      onTap = () => context.push('/exercises');
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    AppColors.primary.withValues(alpha: 0.15),
                    cs.surface,
                  ]
                : [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primaryLight,
                  ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCard(BuildContext context) {
    // Reuse the same card with fallback content.
    return _buildCard(context, null);
  }
}

// ---------------------------------------------------------------------------
// 3b. Ask AI Card
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
// Trial Banner
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Upgrade Prompt Card
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
            'You\'re on the free plan. Upgrade once to unlock every exercise, AI debriefs, and weather briefings.',
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

