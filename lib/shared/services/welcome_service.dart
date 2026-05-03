import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class WelcomeService {
  /// Cut-off for auto-completion: any AppUser whose [AppUser.createdAt] is
  /// strictly before this date is treated as an existing user and bypasses
  /// the welcome flow. Anyone created on or after this instant goes through
  /// it once.
  ///
  /// 2026-05-02T00:00:00Z is the date the welcome flow shipped.
  static final DateTime welcomeFlowShippedAt =
      DateTime.utc(2026, 5, 2);

  static String _key(String uid) => 'welcome_completed_$uid';

  /// Returns true if the welcome flow has already been completed for [uid].
  ///
  /// Pure SharedPreferences read — does not consider account creation date.
  /// Use [shouldShowWelcomeFlow] for the redirect decision.
  static Future<bool> hasCompletedWelcome(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(uid)) == true;
  }

  /// Returns true if [user] should be sent to the welcome flow.
  ///
  /// Skip rules:
  ///  - Persisted flag is set (already saw the flow / explicitly skipped).
  ///  - User account predates the welcome flow ship date — they're an
  ///    existing user, don't trap them. We mark the flag silently so this
  ///    check short-circuits on subsequent launches.
  static Future<bool> shouldShowWelcomeFlow(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key(user.uid)) == true) return false;
    if (user.createdAt.isBefore(welcomeFlowShippedAt)) {
      await prefs.setBool(_key(user.uid), true);
      return false;
    }
    return true;
  }

  static Future<void> markCompleted(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(uid), true);
  }
}
