// Ask AI daily limit provider — tracks free-tier message usage.
//
// Source of truth is the server (Cloud Functions enforce the cap and write
// `ai_message_counts/{uid}` in Firestore). This provider subscribes to that
// doc so the UI shows the canonical count even after a reinstall.
//
// SharedPreferences is kept as an offline / pre-subscription fallback so the
// "X of 3 left" hint is responsive on cold start before the snapshot lands.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/shared/providers/subscription_provider.dart';

// ---------------------------------------------------------------------------
// SharedPreferences keys (UID-scoped to prevent cross-user leakage).
// Retained as a UX fallback only — not the enforcement gate.
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
// Free-tier limit. Mirrors AI_MESSAGE_DAILY_LIMIT in functions/index.js —
// keep both in sync if the cap changes.
// ---------------------------------------------------------------------------

const int kAskAiFreeDailyLimit = 3;

/// Premium-tier monthly soft cap. The server tracks monthly usage and
/// returns `softCapWarning: true` once a premium user crosses this number;
/// the client shows a one-time-per-day informational SnackBar. Mirrors
/// `AI_MESSAGE_PREMIUM_MONTHLY_SOFT_CAP` in functions/index.js — keep in sync.
const int kAskAiPremiumMonthlySoftCap = 1000;

// ---------------------------------------------------------------------------
// Soft-cap SnackBar — once per day per user.
// ---------------------------------------------------------------------------

String _kSoftCapShownDateKey() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return 'ask_ai_soft_cap_shown_$uid';
}

String _todayUtcString() {
  final now = DateTime.now().toUtc();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Returns true if the soft-cap SnackBar has NOT yet been shown today
/// (per-user, UTC day). Marks today as "shown" as a side effect — callers
/// should treat this as a one-shot consume.
Future<bool> consumeSoftCapWarningGate() async {
  final prefs = await SharedPreferences.getInstance();
  final key = _kSoftCapShownDateKey();
  final today = _todayUtcString();
  if (prefs.getString(key) == today) return false;
  await prefs.setString(key, today);
  return true;
}

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _serverSub;

  AskAiLimitNotifier(this._ref) : super(const AskAiLimitState()) {
    _loadDailyCount();
    _attachServerSubscription();
  }

  // ── Server subscription (source of truth) ─────────────────────────────────

  void _attachServerSubscription() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _serverSub?.cancel();
    _serverSub = FirebaseFirestore.instance
        .doc('ai_message_counts/$uid')
        .snapshots()
        .listen(
      (snap) {
        if (!snap.exists) {
          // Doc not created yet — first call hasn't happened today. Treat
          // as 0; SharedPreferences fallback may already show a higher
          // count, which we override only when the server has data.
          return;
        }
        final data = snap.data() ?? {};
        final today = _todayString();
        final docDate = data['date'] as String?;
        final serverCount =
            docDate == today ? (data['count'] as num?)?.toInt() ?? 0 : 0;
        // Only mark limitReached when free user — premium check is done
        // server-side and at canSendMessage(); UI banner driven by state.
        state = state.copyWith(
          dailyMessageCount: serverCount,
          limitReached: serverCount >= kAskAiFreeDailyLimit,
        );
      },
      onError: (_) {
        // Silent — fall back to SharedPreferences UX.
      },
    );
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
    // Server uses UTC; client should match so the daily reset lines up.
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// UX gate: returns true if the user *appears* to be allowed to send
  /// based on the local snapshot. NOT authoritative — the server enforces
  /// the cap and may still reject with a 429 on race conditions or a
  /// freshly-installed client whose snapshot hasn't arrived yet.
  Future<bool> canSendMessage() async {
    await _loadDailyCount();
    if (state.dailyMessageCount < kAskAiFreeDailyLimit) return true;
    final premium = await _ref.read(premiumStatusProvider.future);
    if (premium) return true;
    state = state.copyWith(limitReached: true);
    return false;
  }

  /// Local-only increment for instant UX feedback. The Firestore listener
  /// will overwrite this with the canonical server count shortly after.
  Future<void> incrementMessageCount() async {
    await _incrementDailyCount();
  }

  /// Called when the server returns a 429 daily_limit_reached. Forces the
  /// state into limit-reached mode so the UI banner appears immediately.
  Future<void> markServerLimitReached() async {
    state = state.copyWith(
      dailyMessageCount: kAskAiFreeDailyLimit,
      limitReached: true,
    );
  }

  @override
  void dispose() {
    _serverSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final askAiLimitProvider =
    StateNotifierProvider<AskAiLimitNotifier, AskAiLimitState>(
  (ref) => AskAiLimitNotifier(ref),
);
