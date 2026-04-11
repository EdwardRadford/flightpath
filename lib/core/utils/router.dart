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
import '../../shared/services/deep_link_service.dart';
import '../../shared/models/lesson.dart';
import '../../shared/widgets/main_shell.dart';

// Auth screens
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/instructor_login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/disclaimer_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';

// Shell (bottom-nav) screens
import '../../features/home/screens/home_screen.dart';
import '../../features/exercises/screens/exercise_list_screen.dart';
import '../../features/ask_ai/screens/ask_ai_screen.dart';
import '../../features/logbook/screens/logbook_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
// ProgressScreen merged into LogbookProgressScreen — /progress now redirects to /logbook.
import '../../features/instructor/screens/instructor_home_screen.dart';

// Exercise prep + debrief screens
import '../../features/exercises/screens/prepare_hub_screen.dart';
import '../../features/exercises/screens/brief_screen.dart';
import '../../features/exercises/screens/quiz_screen.dart';
import '../../features/exercises/screens/visualisation_screen.dart';
import '../../features/exercises/screens/video_screen.dart';
import '../../features/exercises/screens/flashcard_screen.dart';
import '../../features/debrief/screens/debrief_screen.dart';

// Logbook
import '../../features/logbook/screens/logbook_entry_screen.dart';

// Progress sub-screens
import '../../features/progress/screens/completion_screen.dart';
import '../../features/progress/screens/share_progress_screen.dart';
import '../../features/progress/screens/weak_areas_screen.dart';
import '../../features/progress/screens/achievements_screen.dart';
import '../../features/progress/screens/lesson_detail_screen.dart';

// Instructor sub-screens
import '../../features/instructor/screens/student_detail_screen.dart';
import '../../features/instructor/screens/exercise_assessment_screen.dart';
import '../../features/instructor/screens/messaging_screen.dart';
import '../../features/instructor/screens/invite_code_screen.dart';
import '../../features/instructor/screens/link_instructor_screen.dart';

// Settings sub-screens
import '../../features/settings/screens/profile_edit_screen.dart';
import '../../features/settings/screens/notification_preferences_screen.dart';
import '../../features/settings/screens/whats_new_screen.dart';
import '../../features/settings/screens/privacy_policy_screen.dart';

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
    _ref.listen(appUserProvider, (prev, next) => notifyListeners());
    _ref.listen(onboardingCompleteProvider, (prev, next) => notifyListeners());
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
        loc.startsWith('/instructor-login') ||
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

    final pendingLink = _ref.read(pendingDeepLinkProvider);
    if (pendingLink != null && isAuthRoute) {
      _ref.read(pendingDeepLinkProvider.notifier).state = null;
      return pendingLink;
    }

    if (isAuthRoute) {
      if (user.isInstructor) return '/instructor';
      return '/home';
    }

    if (user.isInstructor && loc == '/home') return '/instructor';

    if (!user.isInstructor && loc.startsWith('/instructor')) {
      return '/home';
    }

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

      // ── Auth routes (no bottom nav) ──────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/instructor-login',
        builder: (context, state) => const InstructorLoginScreen(),
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
            path: '/ask-ai',
            builder: (context, state) => const AskAiScreen(),
          ),
          GoRoute(
            path: '/logbook',
            builder: (context, state) => const LogbookScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
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
          GoRoute(
            path: '/revision',
            // Revision mode is accessed via the exercises prepare hub.
            redirect: (context, state) => '/exercises',
          ),
          GoRoute(
            path: '/instructor',
            builder: (context, state) => const InstructorHomeScreen(),
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
        builder: (context, state) => const LogbookEntryScreen(),
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
        path: '/exercises/:exerciseId/quiz',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: QuizScreen(
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
        path: '/exercises/:exerciseId/video',
        pageBuilder: (context, state) => slideTransition(
          state: state,
          child: VideoScreen(
            compositeExerciseId: state.pathParameters['exerciseId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/schedule',
        // Schedule redirects to the prepare hub.
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: PrepareHubScreen(
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
        path: '/weak-areas',
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: const WeakAreasScreen(),
        ),
      ),
      GoRoute(
        path: '/achievements',
        pageBuilder: (context, state) => fadeSlideTransition(
          state: state,
          child: const AchievementsScreen(),
        ),
      ),

      // ── Instructor sub-screens ────────────────────────────────────────────
      GoRoute(
        path: '/instructor/student/:studentId',
        builder: (context, state) => StudentDetailScreen(
          studentId: state.pathParameters['studentId']!,
        ),
      ),
      GoRoute(
        path: '/instructor/student/:studentId/assess/:exerciseId',
        builder: (context, state) => ExerciseAssessmentScreen(
          studentId: state.pathParameters['studentId']!,
          exerciseId: state.pathParameters['exerciseId']!,
        ),
      ),
      GoRoute(
        path: '/instructor/messaging/:otherUserId',
        builder: (context, state) => MessagingScreen(
          otherUserId: state.pathParameters['otherUserId']!,
          otherUserName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/instructor/invite-code',
        builder: (context, state) => const InviteCodeScreen(),
      ),
      GoRoute(
        path: '/link-instructor',
        builder: (context, state) => const LinkInstructorScreen(),
      ),

      // ── Settings sub-screens ──────────────────────────────────────────────
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/whats-new',
        builder: (context, state) => const WhatsNewScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
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
        ref.read(pendingDeepLinkProvider.notifier).state = route;
      }
    }
  });

  ref.onDispose(() {
    deepLinkSub?.cancel();
  });

  return router;
});
