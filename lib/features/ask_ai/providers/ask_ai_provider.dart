// Ask AI daily limit provider — tracks free-tier message usage.
// Mirrors the METAR daily limit pattern (SharedPreferences + date key).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/shared/services/subscription_service.dart';

// ---------------------------------------------------------------------------
// SharedPreferences keys
// ---------------------------------------------------------------------------

const String _kDailyCountKey = 'ask_ai_daily_count';
const String _kDailyDateKey = 'ask_ai_daily_date';

// ---------------------------------------------------------------------------
// Free-tier limit
// ---------------------------------------------------------------------------

const int kAskAiFreeDailyLimit = 5;

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
  AskAiLimitNotifier() : super(const AskAiLimitState()) {
    _loadDailyCount();
  }

  // ── Daily usage ────────────────────────────────────────────────────────────

  Future<void> _loadDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_kDailyDateKey) ?? '';
    final today = _todayString();
    if (storedDate != today) {
      // New day — reset counter.
      await prefs.setInt(_kDailyCountKey, 0);
      await prefs.setString(_kDailyDateKey, today);
      state = state.copyWith(dailyMessageCount: 0, limitReached: false);
    } else {
      final count = prefs.getInt(_kDailyCountKey) ?? 0;
      state = state.copyWith(dailyMessageCount: count);
    }
  }

  Future<void> _incrementDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    await prefs.setString(_kDailyDateKey, today);
    final newCount = (prefs.getInt(_kDailyCountKey) ?? 0) + 1;
    await prefs.setInt(_kDailyCountKey, newCount);
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
  Future<bool> canSendMessage() async {
    if (state.dailyMessageCount < kAskAiFreeDailyLimit) return true;
    final premium = await SubscriptionService.isPremium();
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
  (_) => AskAiLimitNotifier(),
);
