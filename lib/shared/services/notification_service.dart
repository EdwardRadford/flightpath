// Hybrid notification service — local notifications for client-side scheduling
// (spaced repetition, check-in reminders) and Firebase Cloud Messaging (FCM)
// for server-triggered notifications (lesson reminders, trial expiry,
// inactivity nudges).
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:flight_path/core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// FCM background handler — must be a top-level function
// ---------------------------------------------------------------------------

/// Handles FCM messages received while the app is in the background or
/// terminated. Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are automatically displayed by the system on both
  // Android and iOS when the notification payload is present. No additional
  // handling needed here unless we want to process data-only messages.
}

// ---------------------------------------------------------------------------
// FCM topic constants
// ---------------------------------------------------------------------------

/// FCM topic names that the server can push notifications to.
class FcmTopics {
  static const String lessonReminders = 'lesson_reminders';
  static const String inactivity = 'inactivity';
}

// ---------------------------------------------------------------------------
// Notification preference keys
// ---------------------------------------------------------------------------

/// Keys for per-type notification preferences stored in SharedPreferences
/// and mirrored to the Firestore user document.
class NotificationPrefKeys {
  static const String masterEnabled = 'notif_master_enabled';
  static const String lessonReminders = 'notif_lesson_reminders';
  static const String preparationPrompts = 'notif_preparation_prompts';
  static const String spacedRepetition = 'notif_spaced_repetition';
  static const String inactivityNudges = 'notif_inactivity_nudges';
}

/// Manages local push notifications and Firebase Cloud Messaging.
///
/// Call [init] once at app startup (before [runApp]).
/// Call [initFcm] after Firebase Auth sign-in to register the FCM token
/// and subscribe to topics based on user preferences.
///
/// Local notifications handle client-side scheduled events (spaced repetition,
/// check-in reminders). FCM handles server-triggered events (lesson-eve
/// reminders, trial expiry, inactivity nudges).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _fcmInitialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;

  static const _channelId = 'lesson_checkin';
  static const _channelName = 'Lesson Check-in';

  static const _reminderChannelId = 'lesson_reminder';
  static const _reminderChannelName = 'Lesson Reminders';

  static const _spacedRepChannelId = 'spaced_rep';
  static const _spacedRepChannelName = 'Spaced Repetition';

  static const _fcmChannelId = 'fcm_default';
  static const _fcmChannelName = 'General Notifications';

  /// GoRouter navigatorKey — set by the app to enable notification-tap
  /// navigation. The app should call
  /// `NotificationService.navigatorKey = router.routerDelegate.navigatorKey`
  /// after creating the router.
  static var onNotificationRoute = <String Function(String? payload)>[];

  // ---------------------------------------------------------------------------
  // Init — local notifications
  // ---------------------------------------------------------------------------

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Reminders to check in after your flying lessons',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _reminderChannelId,
        _reminderChannelName,
        description: 'Reminders about upcoming lessons',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _spacedRepChannelId,
        _spacedRepChannelName,
        description: 'Spaced repetition review reminders',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _fcmChannelId,
        _fcmChannelName,
        description: 'Server-sent notifications from Flight Path',
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Init — Firebase Cloud Messaging
  // ---------------------------------------------------------------------------

  /// Initialises FCM: requests permission, retrieves the device token, stores
  /// it in Firestore, listens for token refresh, and sets up foreground /
  /// background message handlers.
  ///
  /// Call this after Firebase.initializeApp and after the user is signed in.
  static Future<void> initFcm() async {
    if (_fcmInitialized) return;

    final messaging = FirebaseMessaging.instance;

    // Request permission (required on iOS, no-op on Android 12 and below).
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User denied permissions — FCM will not deliver notifications.
      return;
    }

    // Get and store the FCM token.
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _storeFcmToken(token);
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to get FCM token',
      );
    }

    // Listen for token refresh — store subscription so it can be cancelled on sign-out.
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
      _storeFcmToken(newToken);
    });

    // Handle foreground messages — show as local notification.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if the app was opened by tapping a notification (cold start).
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Subscribe to FCM topics based on saved preferences.
    await _syncTopicSubscriptions();

    _fcmInitialized = true;
  }

  /// Stores the FCM token in the current user's Firestore document.
  static Future<void> _storeFcmToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcm_token': token});
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to store FCM token',
      );
    }
  }

  /// Cancels the token-refresh listener and removes the FCM token from
  /// Firestore. Call this on sign-out so the token isn't left orphaned.
  static Future<void> cleanupFcm() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _fcmInitialized = false;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcm_token': FieldValue.delete()});
      } catch (_) {
        // Best-effort — don't block sign-out if this fails.
      }
    }
  }

  /// Displays a foreground FCM message as a local notification.
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await init();

    final notification = message.notification;
    if (notification == null) return;

    await _plugin.show(
      notification.hashCode,
      notification.title ?? 'Flight Path',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _fcmChannelId,
          _fcmChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Handles notification tap when the app was in background/terminated.
  static void _handleMessageOpenedApp(RemoteMessage message) {
    FirebaseAnalytics.instance.logEvent(
      name: 'fcm_notification_tapped',
      parameters: {
        'type': message.data['type'] ?? 'unknown',
      },
    );

    // Navigate based on the notification type if a route handler is registered.
    final type = message.data['type'] as String?;
    _navigateFromPayload(type);
  }

  /// Routes the user to the appropriate screen based on notification data.
  static void _navigateFromPayload(String? type) {
    if (type == null) return;

    // Route mapping for FCM notification types.
    // The app sets up a callback via onNotificationRoute that receives
    // the target route string.
    String? route;
    switch (type) {
      case 'lesson_reminder':
        route = '/exercises';
        break;
      case 'spaced_rep':
        route = '/exercises';
        break;
      case 'inactivity':
        route = '/home';
        break;
      case 'prep_complete':
        route = '/exercises';
        break;
    }

    if (route != null) {
      for (final handler in onNotificationRoute) {
        handler(route);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FCM topic management
  // ---------------------------------------------------------------------------

  /// Subscribes or unsubscribes from an FCM topic.
  static Future<void> setTopicSubscription({
    required String topic,
    required bool subscribe,
  }) async {
    final messaging = FirebaseMessaging.instance;
    if (subscribe) {
      await messaging.subscribeToTopic(topic);
    } else {
      await messaging.unsubscribeFromTopic(topic);
    }
  }

  /// Syncs FCM topic subscriptions with saved preferences.
  static Future<void> _syncTopicSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final masterEnabled =
        prefs.getBool(NotificationPrefKeys.masterEnabled) ?? true;

    if (!masterEnabled) {
      // Unsubscribe from all topics when master toggle is off.
      await Future.wait([
        setTopicSubscription(
            topic: FcmTopics.lessonReminders, subscribe: false),
        setTopicSubscription(topic: FcmTopics.inactivity, subscribe: false),
      ]);
      return;
    }

    final lessonReminders =
        prefs.getBool(NotificationPrefKeys.lessonReminders) ?? true;
    final inactivityNudges =
        prefs.getBool(NotificationPrefKeys.inactivityNudges) ?? true;

    await Future.wait([
      setTopicSubscription(
          topic: FcmTopics.lessonReminders, subscribe: lessonReminders),
      setTopicSubscription(
          topic: FcmTopics.inactivity, subscribe: inactivityNudges),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Notification preferences
  // ---------------------------------------------------------------------------

  /// Loads notification preferences from SharedPreferences.
  /// Returns a map of preference key to enabled status.
  static Future<Map<String, bool>> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      NotificationPrefKeys.masterEnabled:
          prefs.getBool(NotificationPrefKeys.masterEnabled) ?? true,
      NotificationPrefKeys.lessonReminders:
          prefs.getBool(NotificationPrefKeys.lessonReminders) ?? true,
      NotificationPrefKeys.preparationPrompts:
          prefs.getBool(NotificationPrefKeys.preparationPrompts) ?? true,
      NotificationPrefKeys.spacedRepetition:
          prefs.getBool(NotificationPrefKeys.spacedRepetition) ?? true,
      NotificationPrefKeys.inactivityNudges:
          prefs.getBool(NotificationPrefKeys.inactivityNudges) ?? true,
    };
  }

  /// Saves a single notification preference to SharedPreferences and mirrors
  /// the full preference map to the Firestore user document.
  static Future<void> savePreference({
    required String key,
    required bool value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    // Sync topic subscriptions after any preference change.
    await _syncTopicSubscriptions();

    // Mirror to Firestore so Cloud Functions can respect preferences.
    await _mirrorPreferencesToFirestore();
  }

  /// Mirrors the full notification preferences map to Firestore.
  static Future<void> _mirrorPreferencesToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefs = await loadPreferences();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'notification_preferences': prefs});
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to mirror notification preferences to Firestore',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Schedule — check-in (local)
  // ---------------------------------------------------------------------------

  /// Schedules a check-in reminder after [lessonTime].
  ///
  /// Respects quiet hours — if the calculated notification time falls in the
  /// quiet window it is deferred to the next morning.
  ///
  /// Does nothing if the resulting time is already in the past.
  static Future<void> scheduleCheckinNotification({
    required int id,
    required String exerciseName,
    required DateTime lessonTime,
  }) async {
    await init();

    var notifyAt = lessonTime.add(
      const Duration(minutes: AppConstants.checkinReminderDelayMinutes),
    );

    notifyAt = _applyQuietHours(notifyAt);

    // Don't schedule if the time has already passed
    if (!notifyAt.isAfter(DateTime.now())) return;

    final tzNotifyAt = tz.TZDateTime.from(notifyAt, tz.local);

    await _plugin.zonedSchedule(
      id,
      'How did your lesson go?',
      'Tap to check in after your $exerciseName lesson.',
      tzNotifyAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ---------------------------------------------------------------------------
  // Lesson Reminder (evening before) — local
  // ---------------------------------------------------------------------------

  /// Schedules a reminder at 6pm the evening before [lessonDate].
  ///
  /// Respects quiet hours — if 6pm falls in the quiet window (shouldn't
  /// normally happen, but handled for safety) it defers to the next morning.
  static Future<void> scheduleLessonReminder({
    required int id,
    required String exerciseName,
    required DateTime lessonDate,
  }) async {
    await init();

    // 6pm the day before
    var notifyAt = DateTime(
      lessonDate.year,
      lessonDate.month,
      lessonDate.day - 1,
      18, // 6pm
    );

    notifyAt = _applyQuietHours(notifyAt);

    if (!notifyAt.isAfter(DateTime.now())) return;

    final tzNotifyAt = tz.TZDateTime.from(notifyAt, tz.local);

    await _plugin.zonedSchedule(
      id,
      'Lesson Tomorrow',
      'Your $exerciseName lesson is tomorrow. Time to review your brief!',
      tzNotifyAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ---------------------------------------------------------------------------
  // Evening Reminder — local (exercise-id-keyed, Europe/London)
  // ---------------------------------------------------------------------------

  /// Deterministic notification ID for the evening-before reminder, keyed on
  /// [exerciseId] so the same exercise never creates duplicate notifications.
  static int _eveningReminderId(String exerciseId) {
    return 'eveningReminder_$exerciseId'.hashCode.abs() % 0x7FFFFFFF;
  }

  /// Schedules a local notification at 7pm (Europe/London) the evening before
  /// [lessonDate].
  ///
  /// Uses a deterministic ID derived from [exerciseId], so calling this twice
  /// for the same exercise replaces the old notification rather than adding a
  /// duplicate. Does nothing if 7pm the day before has already passed.
  static Future<void> scheduleEveningReminder(
    String exerciseId,
    DateTime lessonDate,
    String exerciseName,
  ) async {
    await init();

    final london = tz.getLocation('Europe/London');

    // 7pm Europe/London the evening before the lesson.
    final dayBefore = lessonDate.subtract(const Duration(days: 1));
    final notifyAt = tz.TZDateTime(
      london,
      dayBefore.year,
      dayBefore.month,
      dayBefore.day,
      19, // 7pm
    );

    if (!notifyAt.isAfter(tz.TZDateTime.now(london))) return;

    final id = _eveningReminderId(exerciseId);

    await _plugin.zonedSchedule(
      id,
      'Lesson tomorrow — are you ready?',
      'Review $exerciseName before your lesson tomorrow.',
      notifyAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels a previously scheduled evening-before reminder for [exerciseId].
  static Future<void> cancelLessonReminder(String exerciseId) async {
    await init();
    await _plugin.cancel(_eveningReminderId(exerciseId));
  }

  // ---------------------------------------------------------------------------
  // Spaced Repetition — local
  // ---------------------------------------------------------------------------

  /// Calculates how many days until the next spaced-repetition review based
  /// on the student's most recent [rating] (1-5) and their [ratingHistory]
  /// (all ratings for this exercise, oldest first, NOT including the current
  /// rating).
  ///
  /// Base interval by rating:
  ///   5 -> 14 days, 4 -> 7 days, 3 -> 3 days, 1-2 -> 1 day
  ///
  /// Trend adjustment (applied after the base):
  ///   Improving (current > previous) -> +2 days bonus
  ///   Declining (current < previous) -> -2 days (minimum 1 day)
  ///   Flat or no history             -> no adjustment
  static int calculateSpacedRepInterval({
    required int rating,
    List<int> ratingHistory = const [],
  }) {
    // Base interval from current rating.
    int days;
    if (rating >= 5) {
      days = 14;
    } else if (rating == 4) {
      days = 7;
    } else if (rating == 3) {
      days = 3;
    } else {
      days = 1; // rating 1 or 2
    }

    // Trend adjustment: compare current rating against the most recent
    // entry in ratingHistory (which should not include the current rating).
    if (ratingHistory.isNotEmpty) {
      final previous = ratingHistory.last;
      if (rating > previous) {
        days += 2; // improving -- reward with a longer gap
      } else if (rating < previous) {
        days -= 2; // declining -- bring the review closer
      }
    }

    return days.clamp(1, 30); // guard against extreme values
  }

  /// Schedules a single spaced-repetition reminder based on the student's
  /// performance, at 8am on the calculated review day.
  ///
  /// [rating] is the student's self-assessment (1-5) from the lesson just
  /// completed. [ratingHistory] is the list of previous ratings for this
  /// exercise (oldest first, NOT including [rating]).
  ///
  /// When [rating] / [ratingHistory] are omitted the method falls back to the
  /// first fixed interval (1 day) so existing call-sites without rating data
  /// continue to work.
  ///
  /// Any previously scheduled spaced-rep notifications for this exercise are
  /// cancelled before the new one is created, so stale reminders never fire.
  ///
  /// Notification IDs are generated from a hash of the exercise ID and the
  /// chosen interval so they can be cancelled later with [cancelForExercise].
  static Future<void> scheduleSpacedRepetition({
    required String exerciseId,
    required String exerciseName,
    required DateTime completedAt,
    int? rating,
    List<int> ratingHistory = const [],
  }) async {
    await init();

    // Cancel any stale notifications from the previous session first.
    await cancelForExercise(exerciseId);

    final days = (rating != null)
        ? calculateSpacedRepInterval(
            rating: rating,
            ratingHistory: ratingHistory,
          )
        : AppConstants.spacedRepIntervals.first;

    var notifyAt = DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day + days,
      AppConstants.quietHourEnd, // 8am
    );

    notifyAt = _applyQuietHours(notifyAt);

    if (!notifyAt.isAfter(DateTime.now())) return;

    final notifId = _spacedRepNotificationId(exerciseId, days);
    final tzNotifyAt = tz.TZDateTime.from(notifyAt, tz.local);

    await _plugin.zonedSchedule(
      notifId,
      'Time to Review',
      'Time to review $exerciseName. Spaced repetition keeps knowledge fresh!',
      tzNotifyAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _spacedRepChannelId,
          _spacedRepChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ---------------------------------------------------------------------------
  // Cancel for exercise
  // ---------------------------------------------------------------------------

  /// Cancels all spaced-repetition notifications for a given [exerciseId].
  ///
  /// Iterates over every interval that [calculateSpacedRepInterval] could
  /// ever produce (1-30 days) so that notifications scheduled in a previous
  /// session -- regardless of which interval was chosen -- are always cleaned
  /// up.
  ///
  /// Call this before scheduling a fresh notification, or when a new lesson
  /// is logged for the exercise.
  static Future<void> cancelForExercise(String exerciseId) async {
    await init();

    // Cover the full range that calculateSpacedRepInterval can return (1-30).
    for (int days = 1; days <= 30; days++) {
      await _plugin.cancel(_spacedRepNotificationId(exerciseId, days));
    }
  }

  // ---------------------------------------------------------------------------
  // Inactivity Reminder — local
  // ---------------------------------------------------------------------------

  /// Fixed notification ID for the 7-day inactivity reminder.
  static const _inactivityId = 9001;

  /// Schedules a reminder 7 days after [lastLessonDate] at 9 am, nudging the
  /// student to fly again.
  ///
  /// Cancels any previously scheduled inactivity notification first.
  /// Does nothing if the calculated date is already in the past.
  static Future<void> scheduleInactivityReminder(
      DateTime lastLessonDate) async {
    await init();
    await _plugin.cancel(_inactivityId);

    var notifyAt = DateTime(
      lastLessonDate.year,
      lastLessonDate.month,
      lastLessonDate.day + 7,
      9, // 9 am
    );

    notifyAt = _applyQuietHours(notifyAt);

    if (!notifyAt.isAfter(DateTime.now())) return;

    final tzNotifyAt = tz.TZDateTime.from(notifyAt, tz.local);

    await _plugin.zonedSchedule(
      _inactivityId,
      "You haven't flown in a while",
      "You haven't flown in a while \u2014 check your progress and keep the momentum going!",
      tzNotifyAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels a previously scheduled notification by [id].
  static Future<void> cancel(int id) => _plugin.cancel(id);

  // ---------------------------------------------------------------------------
  // Notification tap handler
  // ---------------------------------------------------------------------------

  /// Fires the `notification_tapped` analytics event when the user taps a
  /// notification.
  static void _onNotificationTapped(NotificationResponse response) {
    FirebaseAnalytics.instance.logEvent(
      name: 'notification_tapped',
      parameters: {
        'notification_id': response.id ?? 0,
        'payload': response.payload ?? '',
      },
    );

    // Try to navigate based on payload data.
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromPayload(data['type'] as String?);
      } catch (_) {
        // Payload is not JSON — ignore.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Generates a deterministic notification ID for a spaced-rep reminder.
  static int _spacedRepNotificationId(String exerciseId, int dayOffset) {
    return 'spacedRep_${exerciseId}_$dayOffset'.hashCode.abs() % 0x7FFFFFFF;
  }

  /// Shifts [notifyAt] to the next 8am if it falls within quiet hours.
  static DateTime _applyQuietHours(DateTime notifyAt) {
    final hour = notifyAt.hour;
    if (hour >= AppConstants.quietHourStart ||
        hour < AppConstants.quietHourEnd) {
      var next = DateTime(
        notifyAt.year,
        notifyAt.month,
        notifyAt.day,
        AppConstants.quietHourEnd,
      );
      if (!next.isAfter(notifyAt)) {
        next = next.add(const Duration(days: 1));
      }
      return next;
    }
    return notifyAt;
  }
}
