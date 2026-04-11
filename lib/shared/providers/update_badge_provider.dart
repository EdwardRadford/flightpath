// Tracks whether the user has seen the current app version.
// A badge dot is shown on the Settings tab until the user taps it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLastSeenVersion = 'update_badge_last_seen_version';

/// True when the current app version has not yet been seen by the user.
final updateBadgeProvider = StateNotifierProvider<UpdateBadgeNotifier, bool>(
  (ref) => UpdateBadgeNotifier(),
);

class UpdateBadgeNotifier extends StateNotifier<bool> {
  UpdateBadgeNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getString(_kLastSeenVersion);
    state = lastSeen != info.version;
  }

  /// Call when the user navigates to the Settings tab.
  Future<void> markSeen() async {
    if (!state) return;
    final info = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSeenVersion, info.version);
    state = false;
  }
}
