// RevenueCat subscription management — handles one-time lifetime purchase
// and restore flows.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:flight_path/core/constants/app_constants.dart';

/// Wraps RevenueCat Purchases SDK for a one-time (non-consumable) purchase.
class SubscriptionService {
  /// Initialise RevenueCat. Call once in main() before runApp.
  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.warn);
    final config = PurchasesConfiguration(
      Platform.isIOS
          ? AppConstants.revenueCatApiKeyIos
          : AppConstants.revenueCatApiKeyAndroid,
    );
    await Purchases.configure(config);
  }

  /// Returns true if the user currently has the 'pro' entitlement
  /// (lifetime purchase).
  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(AppConstants.entitlementId);
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat isPremium error: $e');
      return false;
    }
  }

  /// Fetches available offerings and purchases the lifetime package.
  /// Returns true on success, false if cancelled or error.
  static Future<bool> purchaseLifetime() async {
    try {
      final offerings = await Purchases.getOfferings();
      final lifetime = offerings.current?.lifetime;
      if (lifetime == null) {
        if (kDebugMode) debugPrint('RevenueCat: No lifetime package found in current offering');
        return false;
      }
      final result = await Purchases.purchase(PurchaseParams.package(lifetime));
      return result.customerInfo.entitlements.active
          .containsKey(AppConstants.entitlementId);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      if (kDebugMode) debugPrint('RevenueCat purchase error: $e');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat purchase error: $e');
      return false;
    }
  }

  /// Restores previous purchases. Returns true if entitlement is active.
  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(AppConstants.entitlementId);
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat restore error: $e');
      return false;
    }
  }

  /// Sets the RevenueCat user ID to match the Firebase UID.
  static Future<void> identifyUser(String uid) async {
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat identify error: $e');
    }
  }

  /// Resets the RevenueCat user (call on sign-out).
  static Future<void> resetUser() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat reset error: $e');
    }
  }
}
