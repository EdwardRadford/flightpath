// Service to manage "Rate This App" prompts using the native in-app review
// dialog. Tracks lesson completion count, whether the user has rated, and
// enforces a 30-day cooldown between prompts.
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys.
const String _kLessonsCompletedCount = 'rate_app_lessons_completed_count';
const String _kHasRatedApp = 'rate_app_has_rated';
const String _kLastRatePromptDate = 'rate_app_last_prompt_date';

/// Minimum number of completed lessons before prompting.
const int _kMinLessonsBeforePrompt = 5;

/// Minimum days between prompts.
const int _kCooldownDays = 30;

class RateAppService {
  RateAppService._();
  static final RateAppService instance = RateAppService._();

  final InAppReview _inAppReview = InAppReview.instance;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Call after each successful lesson debrief save. Increments the counter
  /// and shows the native review dialog if all conditions are met.
  Future<void> onLessonCompleted() async {
    final prefs = await SharedPreferences.getInstance();

    // Increment counter
    final count = (prefs.getInt(_kLessonsCompletedCount) ?? 0) + 1;
    await prefs.setInt(_kLessonsCompletedCount, count);

    // Check conditions
    if (_shouldPrompt(prefs, count)) {
      await _requestReview(prefs);
    }
  }

  /// Opens the store listing directly — used from the Settings screen.
  Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(
      // App Store ID for Flight Path.
      // Found in App Store Connect → App Information → Apple ID (9-10 digit number).
      appStoreId: '0000000000',
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  bool _shouldPrompt(SharedPreferences prefs, int lessonsCompleted) {
    // Already rated — never show again
    if (prefs.getBool(_kHasRatedApp) ?? false) return false;

    // Not enough lessons yet
    if (lessonsCompleted < _kMinLessonsBeforePrompt) return false;

    // Cooldown check
    final lastPromptMs = prefs.getInt(_kLastRatePromptDate);
    if (lastPromptMs != null) {
      final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
      if (DateTime.now().difference(lastPrompt).inDays < _kCooldownDays) {
        return false;
      }
    }

    return true;
  }

  Future<void> _requestReview(SharedPreferences prefs) async {
    // Record that we showed a prompt (before attempting, in case it fails)
    await prefs.setInt(
      _kLastRatePromptDate,
      DateTime.now().millisecondsSinceEpoch,
    );

    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        // Mark as rated — the native dialog handles accept/dismiss internally
        // and we cannot distinguish, so treat any show as "rated".
        await prefs.setBool(_kHasRatedApp, true);
      } else {
        // Fallback: open store listing
        await openStoreListing();
        await prefs.setBool(_kHasRatedApp, true);
      }
    } catch (_) {
      // Non-critical — swallow and try again next time
    }
  }
}
