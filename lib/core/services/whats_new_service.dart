// Service to detect app version changes and trigger the "What's New" display.
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLastSeenVersion = 'whats_new_last_seen_version';

class WhatsNewService {
  WhatsNewService._();
  static final WhatsNewService instance = WhatsNewService._();

  /// Returns `true` if the current app version differs from the last seen
  /// version (i.e. the app was just updated). Also updates the stored version
  /// so subsequent calls return `false`.
  Future<bool> shouldShowWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final lastSeen = prefs.getString(_kLastSeenVersion);

    if (lastSeen == null) {
      // First install — store version but don't show (user already sees onboarding)
      await prefs.setString(_kLastSeenVersion, currentVersion);
      return false;
    }

    if (lastSeen != currentVersion) {
      // App was updated — mark as seen and return true
      await prefs.setString(_kLastSeenVersion, currentVersion);
      return true;
    }

    return false;
  }
}
