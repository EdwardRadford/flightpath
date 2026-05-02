// Smoke tests — verify critical screens render without crashing.
// These do not hit Firebase, RevenueCat, or any real network.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flight_path/features/auth/screens/login_screen.dart';
import 'package:flight_path/features/ask_ai/screens/ask_ai_screen.dart';
import 'package:flight_path/features/ask_ai/providers/ask_ai_provider.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart'
    show PremiumPaywallSheet;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A premium [AppUser] used across tests.
final _premiumUser = AppUser(
  uid: 'test-uid',
  displayName: 'Test Pilot',
  email: 'test@example.com',
  hoursFlown: 10,
  aircraftType: 'pa28',
  flightSchool: 'Test School',
  airfieldIcao: 'EGTC',
  subscriptionStatus: 'lifetime',
  hasPurchased: true,
  disclaimerAcknowledged: true,
  createdAt: DateTime(2025, 1, 1),
);

/// Wraps [child] in a bare [MaterialApp] + [ProviderScope] with optional
/// provider overrides. Sufficient for smoke-testing individual screens.
Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// 1. App boots to login screen (unauthenticated)
// ---------------------------------------------------------------------------

void main() {
  testWidgets('login screen renders sign-in elements', (tester) async {
    // Override authStateProvider so the app believes no user is logged in.
    await tester.pumpWidget(
      _wrap(
        const LoginScreen(),
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
      ),
    );

    // Allow any async initState work (e.g. SharedPreferences.getString for
    // remembered email) to settle.
    await tester.pumpAndSettle();

    // The login screen shows "Sign In" button and the subtitle text.
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign in to continue your training'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // 2. Paywall renders price and upgrade button
  // ---------------------------------------------------------------------------

  testWidgets('premium paywall renders £49 and upgrade button', (tester) async {
    // Pump PremiumPaywallSheet directly to avoid FirebaseAnalytics calls
    // inside showPremiumPaywall() which require a live Firebase app.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const PremiumPaywallSheet(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The price appears inside the upgrade button label.
    expect(find.textContaining('£49'), findsWidgets);

    // There must be at least one ElevatedButton (the purchase button).
    expect(find.byType(ElevatedButton), findsWidgets);
  });

  // ---------------------------------------------------------------------------
  // 3. Ask AI screen renders input field for a premium user
  // ---------------------------------------------------------------------------

  // TODO v1.1: rewrite this test for the new Firestore-counter state stream.
  // The screen now subscribes to ai_message_counts/{uid} which test
  // infrastructure doesn't provide, so the TextField never renders.
  testWidgets('ask ai screen renders text field for premium user',
      skip: true,
      (tester) async {
    // Build a static AskAiLimitState that does not call SharedPreferences.
    final limitOverride = askAiLimitProvider.overrideWith(
      (_) => _StaticAskAiLimitNotifier(),
    );

    // Override the app user stream to emit a premium user immediately.
    final userOverride = appUserProvider.overrideWith(
      (ref) => Stream.value(_premiumUser),
    );

    await tester.pumpWidget(
      _wrap(
        const AskAiScreen(),
        overrides: [limitOverride, userOverride],
      ),
    );

    await tester.pumpAndSettle();

    // The chat input TextField should be present and enabled.
    expect(find.byType(TextField), findsOneWidget);

    // The placeholder hint text from the input decoration.
    expect(
      find.text('Ask anything about flying...'),
      findsOneWidget,
    );
  });
}

// ---------------------------------------------------------------------------
// Static notifier — avoids SharedPreferences I/O in test 3
// ---------------------------------------------------------------------------

class _StaticAskAiLimitNotifier extends StateNotifier<AskAiLimitState>
    implements AskAiLimitNotifier {
  _StaticAskAiLimitNotifier() : super(const AskAiLimitState());

  @override
  Future<bool> canSendMessage() async => true;

  @override
  Future<void> incrementMessageCount() async {}

  @override
  Future<void> markServerLimitReached() async {}
}
