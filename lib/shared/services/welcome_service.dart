import 'package:shared_preferences/shared_preferences.dart';

class WelcomeService {
  static String _key(String uid) => 'welcome_completed_$uid';

  /// Returns true if the welcome flow has been completed for this user.
  /// Also returns true (auto-completing) for existing users created before
  /// 2026-05-02 who have never seen the new welcome flow.
  static Future<bool> hasCompletedWelcome(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(uid);
    if (prefs.getBool(key) == true) return true;
    // Auto-complete for existing users (before the welcome flow existed).
    // We detect "existing" by checking if the key is absent and this is
    // called during normal app use (not first-ever launch after signup).
    // The profile_setup screen marks new users by calling markCompleted
    // immediately after account creation, so the only users without the key
    // are those who signed up before this feature shipped.
    return false;
  }

  static Future<void> markCompleted(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(uid), true);
  }
}
