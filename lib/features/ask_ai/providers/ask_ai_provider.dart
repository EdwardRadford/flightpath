// Ask AI daily limit provider — tracks free-tier message usage.
// Mirrors the METAR daily limit pattern (SharedPreferences + date key).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/shared/providers/subscription_provider.dart';

// ---------------------------------------------------------------------------
// SharedPreferences keys (UID-scoped to prevent cross-user leakage)
// ---------------------------------------------------------------------------

String _kDailyCountKey() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return 'ask_ai_daily_count_$uid';
}

String _kDailyDateKey() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return 'ask_ai_daily_date_$uid';
}

// ---------------------------------------------------------------------------
// Free-tier limit
// ---------------------------------------------------------------------------

const int kAskAiFreeDailyLimit = 3;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class AskAiLimitState {
  /// Number of messages sent today.
  final int dailyMessageCount;

  /// True when free-tier limit is reached and user is not premium.
  final bool limitReached;

  const AskAiLimitState({
    this.dailyMessageCount = 0,
    this.limitReached = false,
  });

  int get messagesRemaining =>
      (kAskAiFreeDailyLimit - dailyMessageCount).clamp(0, kAskAiFreeDailyLimit);

  AskAiLimitState copyWith({
    int? dailyMessageCount,
    bool? limitReached,
  }) {
    return AskAiLimitState(
      dailyMessageCount: dailyMessageCount ?? this.dailyMessageCount,
      limitReached: limitReached ?? this.limitReached,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AskAiLimitNotifier extends StateNotifier<AskAiLimitState> {
  final Ref _ref;

  AskAiLimitNotifier(this._ref) : super(const AskAiLimitState()) {
    _loadDailyCount();
  }

  // ── Daily usage ────────────────────────────────────────────────────────────

  Future<void> _loadDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_kDailyDateKey()) ?? '';
    final today = _todayString();
    if (storedDate != today) {
      // New day — reset counter.
      await prefs.setInt(_kDailyCountKey(), 0);
      await prefs.setString(_kDailyDateKey(), today);
      state = state.copyWith(dailyMessageCount: 0, limitReached: false);
    } else {
      final count = prefs.getInt(_kDailyCountKey()) ?? 0;
      state = state.copyWith(dailyMessageCount: count);
    }
  }

  Future<void> _incrementDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    await prefs.setString(_kDailyDateKey(), today);
    final newCount = (prefs.getInt(_kDailyCountKey()) ?? 0) + 1;
    await prefs.setInt(_kDailyCountKey(), newCount);
    state = state.copyWith(dailyMessageCount: newCount);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns true if the user may send a message right now.
  /// Premium users are always allowed. Free users are limited to
  /// [kAskAiFreeDailyLimit] messages per day.
  /// Refreshes the daily count on each call so midnight rollovers are handled
  /// even when the app has been open continuously across the day boundary.
  Future<bool> canSendMessage() async {
    await _loadDailyCount();
    if (state.dailyMessageCount < kAskAiFreeDailyLimit) return true;
    // Use the comprehensive check: AppUser.isPremium covers granted_access +
    // subscription_status, falling back to RevenueCat. SubscriptionService
    // alone misses the granted_access path.
    final premium = await _ref.read(premiumStatusProvider.future);
    if (premium) return true;
    state = state.copyWith(limitReached: true);
    return false;
  }

  /// Increments the daily message counter. Call after a message is sent.
  Future<void> incrementMessageCount() async {
    await _incrementDailyCount();
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final askAiLimitProvider =
    StateNotifierProvider<AskAiLimitNotifier, AskAiLimitState>(
  (ref) => AskAiLimitNotifier(ref),
);
