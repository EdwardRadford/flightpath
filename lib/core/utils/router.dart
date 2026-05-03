// GoRouter configuration — auth-aware redirects, deep link handling, shell
// routes for bottom nav, and full-screen routes for exercise prep and debrief.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/screen_transitions.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/app_user_provider.dart';
import '../../shared/providers/welcome_provider.dart';
import '../../shared/services/deep_link_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/models/lesson.dart';
import '../../shared/widgets/main_shell.dart';

// Auth screens
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/welcome_flow_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/disclaimer_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';
import '../../features/exercises/screens/pre_skills_test_screen.dart';
import '../../features/exercises/screens/pre_qxc_screen.dart';
import '../../features/exercises/screens/pre_solo_readiness_screen.dart';
import '../../features/exercises/screens/test_prep_hub_screen.dart';

// Shell (bottom-nav) screens
import '../../features/home/screens/home_screen.dart';
import '../../features/exercises/screens/exercise_list_screen.dart';
import '../../features/logbook/screens/logbook_screen.dart';
import '../../features/learn/screens/learn_screen.dart';
import '../../features/tools/screens/tools_screen.dart';

// Ask AI (accessible from Learn tab)
import '../../features/ask_ai/screens/ask_ai_screen.dart';

// Settings
import '../../features/settings/screens/settings_screen.dart';

// Exercise prep + debrief screens
import '../../features/exercises/screens/prepare_hub_screen.dart';
import '../../features/exercises/screens/brief_screen.dart';
import '../../features/exercises/screens/visualisation_screen.dart';
import '../../features/exercises/screens/flashcard_screen.dart';
import '../../features/debrief/screens/debrief_screen.dart';

// Logbook
import '../../features/logbook/screens/logbook_entry_screen.dart';

// Progress sub-screens
import '../../features/progress/screens/completion_screen.dart';
import '../../features/progress/screens/goals_screen.dart';
import '../../features/progress/screens/share_progress_screen.dart';
import '../../features/progress/screens/achievements_screen.dart';
import '../../features/progress/screens/lesson_detail_screen.dart';

// Schedule screens
import '../../features/prepare/screens/schedule_screen.dart';
import '../../features/prepare/screens/lessons_calendar_screen.dart';

// Settings sub-screens
import '../../features/settings/screens/profile_edit_screen.dart';
import '../../features/settings/screens/notification_preferences_screen.dart';
import '../../features/settings/screens/whats_new_screen.dart';
import '../../features/settings/screens/privacy_policy_screen.dart';
import '../../features/settings/screens/bug_report_screen.dart';

// Learn sub-screens
import '../../features/learn/screens/rt_practice_screen.dart';
import '../../features/learn/screens/atis_screen.dart';
import '../../features/learn/screens/mandatory_readback_screen.dart';

// Tools sub-screens
import '../../features/tools/screens/metar_screen.dart';
import '../../features/tools/screens/qxc_guide_screen.dart';
import '../../features/tools/screens/airfield_screen.dart';
import '../../features/tools/screens/aircraft_data_screen.dart';
import '../../features/tools/screens/weather_screen.dart';
import '../../features/tools/screens/memory_drills_screen.dart';
import '../../features/tools/screens/emergency_drills_screen.dart';
import '../../features/tools/screens/mock_skills_test_screen.dart';
import '../../features/tools/screens/plog_screen.dart';

// Exercise content screens
import '../../features/exercises/screens/before_you_fly_screen.dart';
import '../../features/exercises/screens/debrief_screen.dart' as exercise_debrief;
import '../../features/exercises/screens/milestone_celebration_screen.dart';
import '../../features/exercises/screens/lesson_day_screen.dart';

// Progress sub-screens (stub replacements)
import '../../features/progress/screens/hours_minimums_screen.dart';

// ── Onboarding constant ──────────────────────────────────────────────────────
const String kHasSeenOnboardingKey = 'has_seen_onboarding';

/// Tracks whether the welcome onboarding has been completed.
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kHasSeenOnboardingKey) ?? false;
});

// ── Router notifier ──────────────────────────────────────────────────────────

/// Listens to auth + user state and notifies GoRouter to re-evaluate redirects.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (previous, next) {
      if (previous?.valueOrNull != null && next.valueOrNull == null) {
        _ref.read(pendingDeepLinkProvider.notifier).state = null;
      }
      notifyListeners();
    });
    // Only fire the redirect refresh when fields the redirect actually
    // depends on change. Firing on every appUserProvider snapshot (e.g.
    // when notification preferences are toggled) causes go_router's
    // refreshListenable to collapse the imperative push stack, popping
    // the user back to the shell's base location (/home).
    _ref.listen(appUserProvider, (prev, next) {
      final prevUser = prev?.valueOrNull;
      final nextUser = next.valueOrNull;
      // First load (null → user) and sign-out (user → null) must trigger.
      if ((prevUser == null) != (nextUser == null)) {
        notifyListeners();
        return;
      }
      // Otherwise only the fields the redirect reads matter.
      if (prevUser == null || nextUser == null) return;
      if (prevUser.aircraftType.isEmpty != nextUser.aircraftType.isEmpty ||
          prevUser.disclaimerAcknowledged != nextUser.disclaimerAcknowledged) {
        notifyListeners();
      }
    });
    _ref.listen(onboardingCompleteProvider, (prev, next) => notifyListeners());
    // Welcome-flow gate: re-evaluate when the result resolves so a freshly
    // signed-up user is sent to /welcome-flow as soon as the check returns.
    _ref.listen(shouldShowWelcomeFlowProvider, (prev, next) {
      if (prev?.valueOrNull != next.valueOrNull) notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authStateProvider);
    final userAsync = _ref.read(appUserProvider);
    final onboardingAsync = _ref.read(onboardingCompleteProvider);

    if (authAsync.isLoading) return null;
    if (onboardingAsync.isLoading) return null;

    final onboardingDone = onboardingAsync.valueOrNull ?? false;
    final isLoggedIn = authAsync.valueOrNull != null;
    final loc = state.matchedLocation;

    if (!onboardingDone) {
      return loc == '/welcome' ? null : '/welcome';
    }

    final isAuthRoute = loc.startsWith('/login') ||
        loc.startsWith('/signup') ||
        loc.startsWith('/disclaimer') ||
        loc.startsWith('/profile-setup') ||
        loc.startsWith('/password-reset') ||
        loc.startsWith('/welcome');

    if (!isLoggedIn) {
      if (!isAuthRoute && loc != '/home' && loc != '/') {
        _ref.read(pendingDeepLinkProvider.notifier).state = loc;
      }
      if (loc == '/welcome') return '/login';
      return isAuthRoute ? null : '/login';
    }

    if (userAsync.isLoading) return null;

    final user = userAsync.valueOrNull;
    if (user == null) {
      return loc == '/profile-setup' ? null : '/profile-setup';
    }

    if (user.aircraftType.isEmpty) {
      return loc == '/profile-setup' ? null : '/profile-setup';
    }

    if (!user.disclaimerAcknowledged) {
      return loc == '/disclaimer' ? null : '/disclaimer';
    }

    // Welcome flow — shown once per user account, after disclaimer.
    // The provider auto-completes existing accounts created before the
    // flow shipped (see WelcomeService.shouldShowWelcomeFlow).
    final welcomeAsync = _ref.read(shouldShowWelcomeFlowProvider);
    if (welcomeAsync.isLoading) return null;
    final shouldShowWelcome = welcomeAsync.valueOrNull ?? false;
    if (shouldShowWelcome) {
      return loc == '/welcome-flow' ? null : '/welcome-flow';
    }
    // User has completed (or auto-skipped) the flow — don't keep them
    // stuck on /welcome-flow if they navigate back to it.
    if (loc == '/welcome-flow') return '/home';

    final pendingLink = _ref.read(pendingDeepLinkProvider);
    if (pendingLink != null && isAuthRoute) {
      _ref.read(pendingDeepLinkProvider.notifier).state = null;
      return pendingLink;
    }

    if (isAuthRoute) return '/home';

    return null;
  }
}

final _routerNotifierProvider = ChangeNotifierProvider<_RouterNotifier>(
  (ref) => _RouterNotifier(ref),
);

// ── Router provider ──────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);
  final deepLinkService = ref.watch(deepLinkServiceProvider);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Root redirect ────────────────────────────────────────────────────
      GoRoute(path: '/', redirect: (context, state) => '/home'),

      // ── Welcome flow ─────────────────────────────────────────────────────
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/welcome-flow',
        builder: (context, state) => const WelcomeFlowScreen(),
      ),

      // ── Auth routes (no bottom nav) ──────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/disclaimer',
        builder: (context, state) => const DisclaimerScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/password-reset',
        builder: (context, state) => const PasswordResetScreen(),
      ),

      // ── Shell routes (bottom nav) ────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/exercises',
            builder: (context, state) => const ExerciseListScreen(),
          ),
          GoRoute(
            path: '/logbook',
            builder: (context, state) {
              final exerciseId = state.uri.queryParameters['exerciseId'];
              return LogbookScreen(initialExerciseId: exerciseId);
            },
          ),
          GoRoute(
            path: '/learn',
            builder: (context, state) => const LearnScreen(),
          ),
          GoRoute(
            path: '/tools',
            builder: (context, state) => const ToolsScreen(),
          ),
          GoRoute(
            path: '/progress',
            redirect: (context, state) => '/logbook',
          ),
          GoRoute(
            path: '/hours',
            // Hours is a tab within LogbookProgressScreen — redirect there.
            redirect: (context, state) => '/logbook',
          ),
        ],
      ),

      // ── Logbook manual entry (full screen) ────────────────────────────────
      GoRoute(
        path: '/logbook/add',
        builder: (context, state) => const LogbookEntryScreen(),
      ),
      GoRoute(
        path: '/logbook/edit',
        builder: (context, state) => LogbookEntryScreen(
          existingLesson: state.extra is Lesson ? state.extra as Lesson : null,
        ),
      ),

      // ── Special exercise routes (must come before /:exerciseId) ─────────
      GoRoute(
        path: '/exercises/pre-skills-test',
        builder: (context, state) => const PreSkillsTestScreen(),
      ),
      GoRoute(
        path: '/exercises/pre-qxc',
        builder: (context, state) => const PreQxcScreen(),
      ),
      // /exercises/pre-solo-readiness is registered further below with
      // query-string handling so prepare_hub can pass the composite
      // exercise id. The handler defaults to 'ex_14' when no query is
      // supplied, so plain /exercises/pre-solo-readiness from the home
      // milestone card still works.
      GoRoute(
        path: '/test-prep',
        builder: (context, state) => const TestPrepHubScreen(),
      ),

      // ── Exercise prep routes (full screen) ────────────────────────────────
      GoRoute(
        path: '/exercises/:exerciseId',
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: PrepareHubScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/brief',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: BriefScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/visualisation',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: VisualisationScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/schedule',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: ScheduleScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/schedule/calendar',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: const LessonsCalendarScreen(),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/before-you-fly',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: BeforeYouFlyScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/flashcards',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: FlashcardScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/debrief',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: DebriefScreen(
            exerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/debrief/edit',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: DebriefScreen(
            exerciseId: state.pathParameters['exerciseId']!,
            existingLesson: state.extra is Lesson ? state.extra as Lesson : null,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/notes',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return slideTransition(
            state: state,
            child: exercise_debrief.ExerciseDebriefScreen(
              exerciseId: extra?['exerciseId'] as String? ??
                  state.pathParameters['exerciseId']!,
              subExercise: extra?['subExercise'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/milestone',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final firstSolo = extra?['firstSolo'] as bool? ?? false;
          return fadeSlideTransition(
            state: state,
            child: MilestoneCelebrationScreen(isFirstSolo: firstSolo),
          );
        },
      ),

      // ── Lesson detail ──────────────────────────────────────────────────────
      GoRoute(
        path: '/lesson-detail',
        pageBuilder: (context, state) {
          final lesson = state.extra;
          if (lesson is! Lesson) {
            return fadeSlideTransition(
              state: state,
              child: const Scaffold(
                body: Center(
                  child: Text('Lesson not found. Please go back and try again.'),
                ),
              ),
            );
          }
          return fadeSlideTransition(
            state: state,
            child: LessonDetailScreen(lesson: lesson),
          );
        },
      ),
      GoRoute(
        path: '/lesson/:lessonId',
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: LessonDetailScreen(
            lessonId: state.pathParameters['lessonId']!,
          ),
        ),
      ),

      // ── Progress sub-screens ─────────────────────────────────────────────
      GoRoute(
        path: '/goals',
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: const GoalsScreen(),
        ),
      ),
      GoRoute(
        path: '/completion',
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: const CompletionScreen(),
        ),
      ),
      GoRoute(
        path: '/share-progress',
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: const ShareProgressScreen(),
        ),
      ),
      GoRoute(
        path: '/achievements',
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: const AchievementsScreen(),
        ),
      ),

      // ── Ask AI (full screen, accessed from Learn tab) ─────────────────────
      GoRoute(
        path: '/ask-ai',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            // Two map shapes are accepted:
            //  - {'prefill': String}            → prefill the input field
            //  - {'exerciseId': ..., 'subExercise': ...} → debrief mode
            final prefill = extra['prefill'];
            if (prefill is String) {
              return AskAiScreen(initialMessage: prefill);
            }
            return AskAiScreen(
              debriefExerciseId: extra['exerciseId'] as String?,
              debriefSubExercise: extra['subExercise'] as String?,
            );
          }
          return AskAiScreen(
            initialMessage: extra is String ? extra : null,
          );
        },
      ),

      // ── Settings (full screen, accessed via AppBar icon) ─────────────────
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: const SettingsScreen(),
        ),
      ),

      // ── Settings sub-screens ──────────────────────────────────────────────
      GoRoute(
        path: '/settings/profile',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: const ProfileEditScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: const NotificationPreferencesScreen(),
        ),
      ),
      GoRoute(
        path: '/whats-new',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: const WhatsNewScreen(),
        ),
      ),
      GoRoute(
        path: '/privacy-policy',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: const PrivacyPolicyScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/bug-report',
        builder: (context, state) => const BugReportScreen(),
      ),

      // ── Learn sub-routes ─────────────────────────────────────────────────
      GoRoute(
        path: '/learn/rt-practice',
        builder: (context, state) => const RtPracticeScreen(),
      ),
      GoRoute(
        path: '/learn/atis',
        builder: (context, state) => const AtisScreen(),
      ),
      GoRoute(
        path: '/learn/mandatory-readback',
        builder: (context, state) => const MandatoryReadbackScreen(),
      ),

      // ── Tools sub-routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/tools/memory-drills',
        builder: (context, state) => const MemoryDrillsScreen(),
      ),
      GoRoute(
        path: '/tools/emergency-drills',
        builder: (context, state) => const EmergencyDrillsScreen(),
      ),
      GoRoute(
        path: '/tools/mock-skills-test',
        builder: (context, state) => const MockSkillsTestScreen(),
      ),
      GoRoute(
        path: '/tools/weather',
        builder: (context, state) => const WeatherScreen(),
      ),
      GoRoute(
        path: '/tools/metar',
        builder: (context, state) => const MetarScreen(),
      ),
      GoRoute(
        path: '/tools/qxc',
        builder: (context, state) => const QxcGuideScreen(),
      ),
      GoRoute(
        path: '/tools/airfield',
        builder: (context, state) => const AirfieldScreen(),
      ),
      GoRoute(
        path: '/tools/aircraft',
        builder: (context, state) => const AircraftDataScreen(),
      ),
      GoRoute(
        path: '/tools/plog',
        builder: (context, state) => const PlogScreen(),
      ),

      // ── Lesson day flow ───────────────────────────────────────────────────
      GoRoute(
        path: '/lesson-day',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: const LessonDayScreen(),
        ),
      ),

      // ── Pre-solo readiness check ──────────────────────────────────────────
      GoRoute(
        path: '/exercises/pre-solo-readiness',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: PreSoloReadinessScreen(
            compositeExerciseId:
                state.uri.queryParameters['exerciseId'] ?? 'ex_14',
          ),
        ),
      ),

      // ── Progress sub-routes ───────────────────────────────────────────────
      GoRoute(
        path: '/progress/minimums',
        builder: (context, state) => const HoursMinimumsScreen(),
      ),
    ],
  );

  // Wire notification tap routing.
  NotificationService.onNotificationRoute = [(route) {
    if (route != null) router.go(route);
    return route ?? '/home';
  }];

  // Listen for incoming deep links while the app is running.
  StreamSubscription<Uri>? deepLinkSub;
  deepLinkSub = deepLinkService.onLink.listen((uri) {
    final route = DeepLinkService.uriToRoute(uri);
    if (route != null) {
      router.go(route);
    }
  });

  // Handle the initial deep link (app launched via deep link).
  deepLinkService.getInitialLink().then((uri) {
    if (uri != null) {
      final route = DeepLinkService.uriToRoute(uri);
      if (route != null) {
        ref.read(pendingDeepLinkProvider.notifier).state = route;
      }
    }
  });

  ref.onDispose(() {
    deepLinkSub?.cancel();
  });

  return router;
});
