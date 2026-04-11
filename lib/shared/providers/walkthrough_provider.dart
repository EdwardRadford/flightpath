import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kHasSeenWalkthroughKey = 'has_seen_walkthrough';

/// Whether the home-screen walkthrough has been completed (or skipped).
///
/// Mirrors the [onboardingCompleteProvider] pattern in `router.dart`.
final walkthroughCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kHasSeenWalkthroughKey) ?? false;
});

/// Notifier that persists walkthrough completion state to SharedPreferences.
final walkthroughNotifierProvider =
    AsyncNotifierProvider<WalkthroughNotifier, bool>(WalkthroughNotifier.new);

class WalkthroughNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kHasSeenWalkthroughKey) ?? false;
  }

  /// Mark the walkthrough as complete (user finished or skipped it).
  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasSeenWalkthroughKey, true);
    state = const AsyncData(true);
    // Invalidate the simple provider so any listener picks up the new value.
    ref.invalidate(walkthroughCompleteProvider);
  }

  /// Reset the flag so the walkthrough will show again (useful for testing or
  /// a "replay walkthrough" option in settings).
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kHasSeenWalkthroughKey);
    state = const AsyncData(false);
    ref.invalidate(walkthroughCompleteProvider);
  }
}
