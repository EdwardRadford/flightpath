// RevenueCat subscription management — handles one-time lifetime purchase
// and restore flows.
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat SDK keys, supplied at compile time via --dart-define so they
/// are never committed to source control. See CLAUDE.md "Build flags" for
/// the exact flags required when building or running the app.
const String _revenueCatApiKeyIos =
    String.fromEnvironment('REVENUECAT_IOS_KEY');
const String _revenueCatApiKeyAndroid =
    String.fromEnvironment('REVENUECAT_ANDROID_KEY');

/// RevenueCat entitlement ID for lifetime / pro access.
const String _entitlementId = 'pro';

/// Returns the platform-appropriate RevenueCat SDK key and asserts that it
/// was provided at build time. In debug builds this throws a loud
/// [StateError] so a misconfigured `--dart-define` is caught immediately
/// rather than silently failing at the Purchases.configure call.
String _resolveRevenueCatKey() {
  final key = Platform.isIOS ? _revenueCatApiKeyIos : _revenueCatApiKeyAndroid;
  if (key.isEmpty) {
    final flag =
        Platform.isIOS ? 'REVENUECAT_IOS_KEY' : 'REVENUECAT_ANDROID_KEY';
    final message =
        'RevenueCat SDK key missing. Pass --dart-define=$flag=<key> when '
        'running or building the app. See CLAUDE.md "Build flags".';
    if (kDebugMode) {
      throw StateError(message);
    } else {
      debugPrint('SubscriptionService: $message');
    }
  }
  return key;
}

/// Wraps RevenueCat Purchases SDK for a one-time (non-consumable) purchase.
class SubscriptionService {
  /// Initialise RevenueCat. Call once in main() before runApp.
  ///
  /// Retries up to 3 times with exponential back-off on failure (e.g. network
  /// timeout on first launch) before giving up silently — the app remains
  /// usable in free-tier mode if RevenueCat is unavailable.
  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.warn);
    final config = PurchasesConfiguration(_resolveRevenueCatKey());

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await Purchases.configure(config);
        return;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('RevenueCat init attempt $attempt failed: $e');
        }
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        } else {
          // Final attempt failed — record so we can see if RevenueCat is
          // chronically unavailable on real devices (revenue impact).
          FirebaseCrashlytics.instance.recordError(
            e, st,
            reason: 'SubscriptionService.init: RevenueCat configure failed after retries',
            fatal: false,
          );
        }
      }
    }
  }

  /// Returns true if the user currently has the 'pro' entitlement
  /// (lifetime purchase).
  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_entitlementId);
    } catch (e, st) {
      if (kDebugMode) debugPrint('RevenueCat isPremium error: $e');
      // Defaults to false on failure — record so a recurring downgrade-on-error
      // bug is visible (paying users incorrectly seeing the paywall).
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'SubscriptionService.isPremium: RevenueCat lookup failed',
        fatal: false,
      );
      return false;
    }
  }

  /// Fetches available offerings and purchases the lifetime package.
  /// Returns true on success, false if cancelled or error.
  static Future<bool> purchaseLifetime() async {
    try {
      final offerings = await Purchases.getOfferings();
      final lifetime = offerings.current?.lifetime;
      if (lifetime == null) {
        if (kDebugMode) {
          debugPrint(
              'RevenueCat: No lifetime package found in current offering');
        }
        return false;
      }
      final result =
          await Purchases.purchase(PurchaseParams.package(lifetime));
      return result.customerInfo.entitlements.active
          .containsKey(_entitlementId);
    } on PurchasesErrorCode catch (e, st) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      if (kDebugMode) debugPrint('RevenueCat purchase error: $e');
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'SubscriptionService.purchaseLifetime: PurchasesErrorCode',
        fatal: false,
      );
      return false;
    } catch (e, st) {
      if (kDebugMode) debugPrint('RevenueCat purchase error: $e');
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'SubscriptionService.purchaseLifetime: unexpected error',
        fatal: false,
      );
      return false;
    }
  }

  /// Restores previous purchases. Returns true if entitlement is active.
  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(_entitlementId);
    } catch (e, st) {
      if (kDebugMode) debugPrint('RevenueCat restore error: $e');
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'SubscriptionService.restorePurchases: failed',
        fatal: false,
      );
      return false;
    }
  }

  /// Sets the RevenueCat user ID to match the Firebase UID.
  static Future<void> identifyUser(String uid) async {
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat identify error: $e');
    }
  }

  /// Resets the RevenueCat user (call on sign-out).
  static Future<void> resetUser() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat reset error: $e');
    }
  }
}
