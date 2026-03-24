// GoRouter configuration — auth-aware redirects, deep link handling, shell
// routes for bottom nav, and full-screen routes for exercise prep and debrief.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/deep_link_service.dart';
import '../../core/utils/screen_transitions.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/disclaimer_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';
import '../../features/progress/screens/completion_screen.dart';
import '../../features/progress/screens/goals_screen.dart';
import '../../features/progress/screens/share_progress_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/exercises/screens/exercise_list_screen.dart';
import '../../features/progress/screens/progress_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/profile_edit_screen.dart';
import '../../features/settings/screens/notification_preferences_screen.dart';
import '../../features/settings/screens/privacy_policy_screen.dart';
import '../../features/settings/screens/whats_new_screen.dart';
import '../../features/lesson_log/screens/logbook_screen.dart';
import '../../features/lesson_log/screens/logbook_entry_screen.dart';
import '../../features/prepare/screens/prepare_hub_screen.dart';
import '../../features/prepare/screens/revision_screen.dart';
import '../../features/prepare/screens/brief_screen.dart';
import '../../features/prepare/screens/quiz_screen.dart';
import '../../features/prepare/screens/visualisation_screen.dart';
import '../../features/prepare/screens/video_screen.dart';
import '../../features/prepare/screens/weather_briefing_screen.dart';
import '../../features/prepare/screens/schedule_screen.dart';
import '../../features/prepare/screens/flashcard_screen.dart';
import '../../features/debrief/screens/debrief_screen.dart';
import '../../features/progress/screens/weak_areas_screen.dart';
import '../../features/ask_ai/screens/ask_ai_screen.dart';
import '../../features/instructor/screens/instructor_home_screen.dart';
import '../../features/instructor/screens/invite_code_screen.dart';
import '../../features/instructor/screens/link_instructor_screen.dart';
import '../../features/instructor/screens/messaging_screen.dart';
import '../../features/instructor/screens/student_detail_screen.dart';
import '../../features/progress/screens/achievements_screen.dart';
import '../../features/progress/screens/hours_screen.dart';
import '../../features/progress/screens/lesson_detail_screen.dart';
import '../../shared/models/lesson.dart';
import '../../shared/providers/app_user_provider.dart';
import '../../shared/widgets/main_shell.dart';

/// Tracks whether the welcome onboarding has been completed.
///
/// Loaded once from SharedPreferences at startup. The [_RouterNotifier]
/// reads this to decide whether to show the onboarding screens.
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kHasSeenOnboardingKey) ?? false;
});

/// Listens to auth + user state and notifies GoRouter to re-evaluate redirects.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(appUserProvider, (_, _) => notifyListeners());
    _ref.listen(onboardingCompleteProvider, (_, _) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authStateProvider);
    final userAsync = _ref.read(appUserProvider);
    final onboardingAsync = _ref.read(onboardingCompleteProvider);

    // Don't redirect while loading
    if (authAsync.isLoading) return null;
    if (onboardingAsync.isLoading) return null;

    final onboardingDone = onboardingAsync.valueOrNull ?? false;
    final isLoggedIn = authAsync.valueOrNull != null;
    final loc = state.matchedLocation;

    // Show welcome flow for first-time users before anything else
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
      // If navigating to a deep-linked content route while not logged in,
      // save the deep link for after login.
      if (!isAuthRoute && loc != '/home' && loc != '/') {
        _ref.read(pendingDeepLinkProvider.notifier).state = loc;
      }
      // Welcome/onboarding is done — redirect away from it to login
      if (loc == '/welcome') return '/login';
      return isAuthRoute ? null : '/login';
    }

    // Logged in — wait for Firestore user to load
    if (userAsync.isLoading) return null;

    final user = userAsync.valueOrNull;
    if (user == null) {
      // Firestore doc not yet created (race condition on signup)
      return loc == '/profile-setup' ? null : '/profile-setup';
    }

    // Profile incomplete
    if (user.aircraftType.isEmpty) {
      return loc == '/profile-setup' ? null : '/profile-setup';
    }

    // Disclaimer not yet acknowledged
    if (!user.disclaimerAcknowledged) {
      return loc == '/disclaimer' ? null : '/disclaimer';
    }

    // Fully set up — check for pending deep link
    final pendingLink = _ref.read(pendingDeepLinkProvider);
    if (pendingLink != null && isAuthRoute) {
      _ref.read(pendingDeepLinkProvider.notifier).state = null;
      return pendingLink;
    }

    // Fully set up — bounce away from auth routes
    if (isAuthRoute) {
      // Instructors go to the instructor dashboard by default
      if (user.isInstructor) return '/instructor';
      return '/home';
    }

    // Students cannot access instructor routes
    if (!user.isInstructor && loc.startsWith('/instructor')) {
      return '/home';
    }

    return null;
  }
}

final _routerNotifierProvider = ChangeNotifierProvider<_RouterNotifier>(
  (ref) => _RouterNotifier(ref),
);

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);
  final deepLinkService = ref.watch(deepLinkServiceProvider);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Root redirect ─────────────────────────────────────────────────
      GoRoute(path: '/', redirect: (_, _) => '/home'),

      // ── Welcome flow (first-time users only) ──────────────────────────
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),

      // ── Auth routes (no shell / no bottom nav) ──────────────────────────
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/disclaimer', builder: (_, _) => const DisclaimerScreen()),
      GoRoute(path: '/profile-setup', builder: (_, _) => const ProfileSetupScreen()),
      GoRoute(path: '/password-reset', builder: (_, _) => const PasswordResetScreen()),

      // ── Shell routes (bottom nav) ────────────────────────────────────────
      ShellRoute(
        builder: (_, _, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/exercises', builder: (_, _) => const ExerciseListScreen()),
          GoRoute(path: '/logbook', builder: (_, _) => const LogbookScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/ask-ai', builder: (_, _) => const AskAiScreen()),
          GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
          GoRoute(path: '/hours', builder: (_, _) => const HoursScreen()),
          GoRoute(path: '/goals', builder: (_, _) => const GoalsScreen()),
          GoRoute(path: '/revision', builder: (_, _) => const RevisionScreen()),
          // Instructor home (inside shell for bottom nav)
          GoRoute(path: '/instructor', builder: (_, _) => const InstructorHomeScreen()),
        ],
      ),

      // ── Logbook manual entry (full screen, no bottom nav) ──────────────
      GoRoute(
        path: '/logbook/add',
        builder: (_, _) => const LogbookEntryScreen(),
      ),

      // ── Exercise / prepare / debrief routes (full screen, no bottom nav) ─
      // These use fade+slide transitions for polished navigation.
      GoRoute(
        path: '/exercises/:exerciseId',
        pageBuilder: (_, state) => fadeSlideTransition(
          state: state,
          child: PrepareHubScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/brief',
        pageBuilder: (_, state) => slideTransition(
          state: state,
          child: BriefScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/quiz',
        pageBuilder: (_, state) => slideTransition(
          state: state,
          child: QuizScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/visualisation',
        pageBuilder: (_, state) => slideTransition(
          state: state,
          child: VisualisationScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/video',
        pageBuilder: (_, state) => slideTransition(
          state: state,
          child: VideoScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/weather',
        pageBuilder: (_, state) => slideTransition(
          state: state,
          child: WeatherBriefingScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/schedule',
        pageBuilder: (_, state) => slideTransition(
          state: state,
          child: ScheduleScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/flashcards',
        pageBuilder: (_, state) => slideTransition(
          state: state,
          child: FlashcardScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/debrief',
        pageBuilder: (_, state) => slideTransition(
          state: state,
          child: DebriefScreen(
            exerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/debrief/edit',
        pageBuilder: (_, state) {
          final lesson = state.extra is Lesson ? state.extra as Lesson : null;
          return slideTransition(
            state: state,
            child: DebriefScreen(
              exerciseId: state.pathParameters['exerciseId']!,
              existingLesson: lesson,
            ),
          );
        },
      ),

      // ── Lesson detail ─────────────────────────────────────────────────────
      // In-app navigation: Lesson object passed via state.extra.
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

      // Deep-link / URL-based route: only the lesson ID is available.
      // The screen fetches the Lesson from Firestore by ID.
      GoRoute(
        path: '/lesson/:lessonId',
        pageBuilder: (_, state) => fadeSlideTransition(
          state: state,
          child: LessonDetailScreen(
            lessonId: state.pathParameters['lessonId']!,
          ),
        ),
      ),

      // ── Completion celebration (full screen, no bottom nav) ────────────────
      GoRoute(
        path: '/completion',
        pageBuilder: (_, state) => fadeSlideTransition(
          state: state,
          child: const CompletionScreen(),
        ),
      ),

      // ── Share progress (full screen, no bottom nav) ────────────────────────
      GoRoute(
        path: '/share-progress',
        pageBuilder: (_, state) => fadeSlideTransition(
          state: state,
          child: const ShareProgressScreen(),
        ),
      ),

      // ── Weak areas (full screen, no bottom nav) ────────────────────────────
      GoRoute(
        path: '/weak-areas',
        pageBuilder: (_, state) => fadeSlideTransition(
          state: state,
          child: const WeakAreasScreen(),
        ),
      ),

      // ── Achievements (full screen, no bottom nav) ─────────────────────────
      GoRoute(
        path: '/achievements',
        pageBuilder: (_, state) => fadeSlideTransition(
          state: state,
          child: const AchievementsScreen(),
        ),
      ),

      // ── Instructor routes (full screen, no bottom nav) ──────────────────
      GoRoute(
        path: '/instructor/student/:studentId',
        builder: (_, state) => StudentDetailScreen(
          studentId: state.pathParameters['studentId']!,
        ),
      ),
      GoRoute(
        path: '/instructor/messaging/:otherUserId',
        builder: (_, state) => MessagingScreen(
          otherUserId: state.pathParameters['otherUserId']!,
          otherUserName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/instructor/invite-code',
        builder: (_, _) => const InviteCodeScreen(),
      ),
      GoRoute(
        path: '/link-instructor',
        builder: (_, _) => const LinkInstructorScreen(),
      ),

      // ── Settings sub-routes (full screen, no bottom nav) ─────────────────
      GoRoute(
        path: '/settings/profile',
        builder: (_, _) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/whats-new',
        builder: (_, _) => const WhatsNewScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (_, _) => const PrivacyPolicyScreen(),
      ),
    ],
  );

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
        // Store as pending — the redirect logic will navigate after auth.
        ref.read(pendingDeepLinkProvider.notifier).state = route;
      }
    }
  });

  ref.onDispose(() {
    deepLinkSub?.cancel();
  });

  return router;
});
