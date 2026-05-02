// Consent service — gates the activation of optional, non-essential
// telemetry / messaging services behind explicit user consent.
//
// Three independently-toggleable services are guarded:
//   - Firebase Analytics
//   - Firebase Crashlytics
//   - Firebase Cloud Messaging (push notifications)
//
// Defaults are opt-out (UK GDPR + PECR). The dialog is shown once on first
// launch after the safety disclaimer is acknowledged; users can change their
// choices at any time from Settings -> Privacy.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for consent decisions.
class ConsentKeys {
  /// True when the user has consented to Firebase Analytics collection.
  static const String analytics = 'consent_analytics';

  /// True when the user has consented to Firebase Crashlytics collection.
  static const String crashlytics = 'consent_crashlytics';

  /// True when the user has consented to FCM push notifications.
  static const String notifications = 'consent_notifications';

  /// True once the consent dialog has been shown to the user at least once,
  /// regardless of whether they granted or declined any service. Prevents
  /// the dialog from re-appearing on every launch.
  static const String prompted = 'consent_prompted';
}

/// Manages the gating of optional telemetry / messaging services behind
/// explicit user consent.
class ConsentService {
  /// Loads the current consent state for [key] from SharedPreferences.
  /// Defaults to `false` (opt-out) if the key has never been written.
  static Future<bool> isGranted(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  /// Returns true once the consent dialog has been shown at least once.
  static Future<bool> hasBeenPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(ConsentKeys.prompted) ?? false;
  }

  /// Marks the consent dialog as shown so it does not re-appear next launch.
  static Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ConsentKeys.prompted, true);
  }

  /// Persists a single consent decision and immediately activates or
  /// deactivates the corresponding service.
  static Future<void> setConsent(String key, bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, granted);
    await _applyConsent(key, granted);
  }

  /// Applies the persisted consent state to the live SDKs. Call once at
  /// startup before [runApp] so disabled services never collect even briefly.
  /// Safe to call repeatedly.
  static Future<void> applyAll() async {
    final analytics = await isGranted(ConsentKeys.analytics);
    final crash = await isGranted(ConsentKeys.crashlytics);
    final notifications = await isGranted(ConsentKeys.notifications);

    await _applyConsent(ConsentKeys.analytics, analytics);
    await _applyConsent(ConsentKeys.crashlytics, crash);
    // Don't request notification permission at startup — only when the user
    // has explicitly opted in. The token request triggers a system prompt on
    // iOS, so we never want this to happen without consent.
    await _applyConsent(ConsentKeys.notifications, notifications);
  }

  // ---------------------------------------------------------------------------
  // Internal — actually flip the SDKs on or off.
  // ---------------------------------------------------------------------------

  static Future<void> _applyConsent(String key, bool granted) async {
    try {
      switch (key) {
        case ConsentKeys.analytics:
          await FirebaseAnalytics.instance
              .setAnalyticsCollectionEnabled(granted);
          break;
        case ConsentKeys.crashlytics:
          await FirebaseCrashlytics.instance
              .setCrashlyticsCollectionEnabled(granted);
          break;
        case ConsentKeys.notifications:
          if (granted) {
            // Request OS permission and obtain an FCM token. The full FCM
            // wiring (token storage, topic subscriptions, message handlers)
            // lives in NotificationService.initFcm and is invoked from there
            // when the user is signed in.
            await FirebaseMessaging.instance.requestPermission();
          } else {
            // Drop the existing token so the device stops receiving pushes.
            try {
              await FirebaseMessaging.instance.deleteToken();
            } catch (_) {
              // Token may not exist yet on a fresh device — safe to ignore.
            }
          }
          break;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ConsentService: failed to apply $key=$granted — $e');
      }
      // Note: only reports if the user has *also* granted Crashlytics consent;
      // if they declined Crashlytics this is a no-op, which is the desired
      // privacy-respecting behaviour.
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'ConsentService: failed to apply consent for $key',
        fatal: false,
      );
    }
  }
}
