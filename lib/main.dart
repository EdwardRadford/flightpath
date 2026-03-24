// App entry point — initialises Firebase, Hive, notifications, and RevenueCat
// before launching the root [FlightPathApp] widget.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/services/firestore_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/subscription_service.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/router.dart';
import 'firebase_options.dart';
import 'shared/providers/accessibility_provider.dart';
import 'shared/providers/theme_provider.dart';

/// Initialises all services and starts the app.
///
/// Performance: Firebase must init first (dependency), then all other
/// services run in parallel via Future.wait to minimise startup time.
/// Cache invalidation is fire-and-forget so it never blocks the UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must init first — other services depend on it.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register the FCM background message handler (must be top-level function).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Enable Firestore offline persistence so cached data is available offline.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Crashlytics — capture Flutter errors (sync, no await needed).
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Hive must init first — SyncService depends on Hive.initFlutter().
  await HiveService.init();

  // Run remaining independent init tasks in parallel.
  await Future.wait([
    // App Check — protect backend resources from abuse.
    // ignore: deprecated_member_use
    FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      // ignore: deprecated_member_use
      appleProvider: kReleaseMode
          ? AppleProvider.appAttest
          : AppleProvider.debug,
    ),
    // Sync queue — offline write queue (opens Hive boxes; safe now that initFlutter has run)
    SyncService.init(),
    // Notifications — initialise channel
    NotificationService.init(),
    // RevenueCat — subscription management
    SubscriptionService.init(),
    // Analytics — enable collection
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true),
  ]);

  // Cache invalidation — depends on Hive being ready (awaited above).
  // Fire-and-forget: don't block startup for a network call.
  FirestoreService().checkAndInvalidateCache();

  // FCM — initialise after Firebase is ready. Fire-and-forget so it doesn't
  // block startup. It will request permissions and store the token once the
  // user is signed in.
  NotificationService.initFcm();

  runApp(const ProviderScope(child: FlightPathApp()));
}

/// Root widget — configures [MaterialApp.router] with light/dark themes and GoRouter.
class FlightPathApp extends ConsumerWidget {
  const FlightPathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Flight Path',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Keep legacy AppColors accessors in sync with the active theme.
        AppColors.updateBrightness(Theme.of(context).brightness);
        // Apply accessibility settings via MediaQuery overrides.
        final accessibility = ref.watch(accessibilityProvider);
        final existing = MediaQuery.of(context);
        return MediaQuery(
          data: existing.copyWith(
            textScaler: accessibility.largerText
                ? TextScaler.linear(existing.textScaler.scale(1.0) * 1.15)
                : existing.textScaler,
            disableAnimations: accessibility.reduceAnimations,
            highContrast: accessibility.highContrast,
          ),
          child: child!,
        );
      },
    );
  }
}
