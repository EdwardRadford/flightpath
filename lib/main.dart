import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/router.dart';
import 'firebase_options.dart';
import 'shared/providers/accessibility_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/services/consent_service.dart';
import 'shared/services/hive_service.dart';
import 'shared/services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check — debug provider in debug builds, device attestation in release.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );

  // Apply persisted consent state BEFORE any optional service is wired up.
  // Analytics + Crashlytics + FCM start in the off position (UK GDPR / PECR
  // require opt-in for non-essential analytics + tracking). The consent
  // dialog (shown once after the safety disclaimer is acknowledged) flips
  // these on if the user opts in.
  await ConsentService.applyAll();

  // Crashlytics handlers must always be installed so crashes are captured
  // the moment consent is granted — but collection itself is gated by
  // setCrashlyticsCollectionEnabled, which ConsentService.applyAll has just
  // set to the persisted value (defaulting to off).
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Local Hive cache
  await HiveService.init();

  // RevenueCat
  await SubscriptionService.init();

  runApp(const ProviderScope(child: FlightPathApp()));
}

class FlightPathApp extends ConsumerWidget {
  const FlightPathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accessibility = ref.watch(accessibilityProvider);

    return MaterialApp.router(
      title: 'Flight Path Training',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // Apply accessibility overrides via MediaQuery builder.
      // largerText: increases text scale by 20%.
      // highContrast: tells the OS-level media query high contrast is active.
      // reduceAnimations is read directly from accessibilityProvider in
      // animation widgets (micro_animations.dart, screen_transitions.dart).
      builder: (context, child) {
        final base = MediaQuery.of(context);
        final scaleFactor = accessibility.largerText
            ? (base.textScaler.scale(1.0) * 1.2)
            : base.textScaler.scale(1.0);
        return MediaQuery(
          data: base.copyWith(
            textScaler: TextScaler.linear(scaleFactor),
            highContrast: accessibility.highContrast || base.highContrast,
            disableAnimations:
                accessibility.reduceAnimations || base.disableAnimations,
          ),
          child: child!,
        );
      },
    );
  }
}
