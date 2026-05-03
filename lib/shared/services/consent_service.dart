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
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/shared/services/notification_service.dart';

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
  ///
  /// Notifications are intentionally NOT applied here because FCM
  /// initialisation needs an authenticated user (token storage writes to
  /// `users/{uid}`) and we don't want the iOS native notification prompt
  /// firing before sign-in. [MainShell] runs the post-sign-in init via
  /// [NotificationService.initFcm] gated on the persisted consent state.
  static Future<void> applyAll() async {
    final analytics = await isGranted(ConsentKeys.analytics);
    final crash = await isGranted(ConsentKeys.crashlytics);

    await _applyConsent(ConsentKeys.analytics, analytics);
    await _applyConsent(ConsentKeys.crashlytics, crash);
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
            // The user has explicitly opted in via the in-app consent flow.
            // Hand off to NotificationService.initFcm, which owns the OS
            // permission request, token storage, topic subscriptions, and
            // message handlers. This is the only path that can trigger the
            // iOS native notification prompt — Apple Guideline 5.1.1.
            //
            // Idempotent: if FCM is already initialised this is a no-op.
            // Covers the late-grant path where the user toggles notifications
            // on from Settings after first launch.
            await NotificationService.initFcm();
          } else {
            // Tear down the FCM listener and delete the stored token so the
            // device stops receiving pushes. cleanupFcm also clears the
            // _fcmInitialized flag so a future re-grant re-runs initFcm.
            await NotificationService.cleanupFcm();
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
