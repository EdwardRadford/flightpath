// Provider that resolves whether the signed-in user should be routed
// through the welcome flow. Wraps [WelcomeService.shouldShowWelcomeFlow]
// so the router redirect can read the result synchronously once the
// underlying SharedPreferences check has resolved.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/welcome_service.dart';
import 'app_user_provider.dart';

/// True if the welcome flow needs to be shown for the current user.
///
/// `null` while loading or signed out (the redirect treats these the same
/// way as "not yet known" — no redirect).
final shouldShowWelcomeFlowProvider = FutureProvider<bool>((ref) async {
  final userAsync = ref.watch(appUserProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return false;
  return WelcomeService.shouldShowWelcomeFlow(user);
});

/// Marks the welcome flow as complete for [user] and invalidates the
/// provider so any active redirects re-evaluate.
///
/// Accepts both [Ref] (for use inside providers) and [WidgetRef] (for use
/// inside widgets) — both expose [invalidate]. Callers pass `ref` from
/// either context.
Future<void> markWelcomeCompletedAndRefresh(
    WidgetRef ref, AppUser user) async {
  await WelcomeService.markCompleted(user.uid);
  // Invalidate so the next read returns false without reloading the box.
  ref.invalidate(shouldShowWelcomeFlowProvider);
}
