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
import 'shared/services/log_buffer_service.dart';
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
  //
  // LogBufferService.log() also captures a one-line summary so the in-app
  // bug report includes recent diagnostics even when Crashlytics consent is
  // off (the buffer is in-memory only — never leaves the device until the
  // user explicitly attaches it to a bug report).
  FlutterError.onError = (details) {
    LogBufferService.log(
        'FlutterError: ${details.exceptionAsString()} '
        '(library=${details.library ?? "?"})');
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogBufferService.log(
        'PlatformDispatcher.onError: ${error.runtimeType}: $error');
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Local Hive cache
  await HiveService.init();

  // RevenueCat
  await SubscriptionService.init();

  runApp(const ProviderScope(child: FlightPathApp()));
}

class FlightPathApp extends ConsumerStatefulWidget {
  const FlightPathApp({super.key});

  @override
  ConsumerState<FlightPathApp> createState() => _FlightPathAppState();
}

class _FlightPathAppState extends ConsumerState<FlightPathApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Seed AppColors with the current platform brightness so the 345 legacy
    // accessor sites resolve to the correct surface/onSurface variants on
    // first paint. _resolveActiveBrightness re-reads the persisted theme
    // mode preference once it loads.
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppColors.updateBrightness(platformBrightness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Only react when the user is on ThemeMode.system. For explicit light/
    // dark choices the AppColors brightness is driven by the themeMode
    // listener in build() below.
    final themeMode = ref.read(themeModeProvider);
    if (themeMode != ThemeMode.system) return;
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppColors.updateBrightness(platformBrightness);
    if (mounted) setState(() {});
  }

  /// Resolve the brightness that should drive the legacy [AppColors]
  /// accessors based on the user's [ThemeMode] preference and the OS
  /// brightness when the user picked "System".
  Brightness _resolveActiveBrightness(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accessibility = ref.watch(accessibilityProvider);

    // Keep the brightness-blind AppColors accessors in sync with the active
    // theme. Resolved here in build so it tracks both:
    //  - explicit ThemeMode changes from the settings toggle
    //  - platform brightness changes via didChangePlatformBrightness above
    //    (which calls setState → re-runs build → re-runs this line).
    AppColors.updateBrightness(_resolveActiveBrightness(themeMode));

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
        // Cap text scaling at 1.5x. iOS XXXL+ Larger Text can otherwise push
        // scaleFactor above 3x which breaks our many fixed-height layouts
        // (stat cards, exercise canvas, AppBar titles). 1.5x preserves
        // readability without overflow.
        final rawScale = accessibility.largerText
            ? (base.textScaler.scale(1.0) * 1.2)
            : base.textScaler.scale(1.0);
        final scaleFactor = rawScale.clamp(1.0, 1.5);
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
