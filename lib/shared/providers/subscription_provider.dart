import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/services/subscription_service.dart';

/// Returns true if the user has Pro access via either RevenueCat (live
/// purchases) or Firestore granted access (test accounts / manual grants).
final premiumStatusProvider = FutureProvider<bool>((ref) async {
  final firestoreUser = await ref.watch(appUserProvider.future);
  if (firestoreUser != null && firestoreUser.isPremium) return true;
  return SubscriptionService.isPremium();
});
