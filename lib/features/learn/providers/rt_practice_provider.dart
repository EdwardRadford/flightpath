// RT Practice provider — manages session state for the AI-powered ATC roleplay
// feature. Mirrors the Cloud Function call pattern from ask_ai_screen.dart.
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/services/subscription_service.dart';

// ---------------------------------------------------------------------------
// Scenario types
// ---------------------------------------------------------------------------

/// All available RT practice scenario types.
enum RtScenario {
  radioCheck('Radio Check', 'radio_check'),
  taxiForDeparture('Taxi for Departure', 'taxi_departure'),
  joiningCircuit('Joining the Circuit', 'joining_circuit'),
  circuitCalls('Circuit Calls (Downwind / Base / Final)', 'circuit_calls'),
  goingAround('Going Around', 'going_around'),
  matzTransit('MATZ Transit Request', 'matz_transit'),
  enRouteNavigation('En-Route Navigation Call', 'en_route_nav'),
  emergencyMayday('Emergency (MAYDAY)', 'emergency_mayday'),
  emergencyPanPan('Emergency (PAN PAN)', 'emergency_pan');

  const RtScenario(this.displayName, this.apiValue);
  final String displayName;
  final String apiValue;
}

// ---------------------------------------------------------------------------
// Score history — persisted to SharedPreferences
// ---------------------------------------------------------------------------

/// Maximum sessions kept per scenario.
const int kMaxRtHistory = 10;

/// Key prefix for SharedPreferences.
String _rtHistoryKey(RtScenario scenario) => 'rt_history_${scenario.apiValue}';

/// One completed session's averaged scores.
class RtSessionRecord {
  final DateTime date;
  final double phrasing;
  final double readback;
  final double format;

  const RtSessionRecord({
    required this.date,
    required this.phrasing,
    required this.readback,
    required this.format,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'phrasing': phrasing,
        'readback': readback,
        'format': format,
      };

  factory RtSessionRecord.fromJson(Map<String, dynamic> json) =>
      RtSessionRecord(
        date: DateTime.parse(json['date'] as String),
        phrasing: (json['phrasing'] as num).toDouble(),
        readback: (json['readback'] as num).toDouble(),
        format: (json['format'] as num).toDouble(),
      );
}

/// Reads the stored history for [scenario] from SharedPreferences.
Future<List<RtSessionRecord>> loadRtHistory(RtScenario scenario) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_rtHistoryKey(scenario));
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => RtSessionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Appends [record] for [scenario], keeping only the last [kMaxRtHistory].
Future<void> appendRtHistory(
  RtScenario scenario,
  RtSessionRecord record,
) async {
  final prefs = await SharedPreferences.getInstance();
  final history = await loadRtHistory(scenario);
  history.add(record);
  final trimmed = history.length > kMaxRtHistory
      ? history.sublist(history.length - kMaxRtHistory)
      : history;
  await prefs.setString(
    _rtHistoryKey(scenario),
    jsonEncode(trimmed.map((r) => r.toJson()).toList()),
  );
}

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

/// Immutable state for a single RT Practice session.
class RtPracticeState {
  /// The currently active scenario type.
  final RtScenario currentScenario;

  /// Conversation history: list of {role: 'user'|'atc', content: String}.
  final List<Map<String, String>> messages;

  /// True while waiting for a Cloud Function response.
  final bool isLoading;

  /// How many distinct scenarios have been started this session (for free tier).
  final int scenariosUsedThisSession;

  /// Non-null when an error should be displayed to the user.
  final String? errorMessage;

  const RtPracticeState({
    required this.currentScenario,
    required this.messages,
    required this.isLoading,
    required this.scenariosUsedThisSession,
    this.errorMessage,
  });

  RtPracticeState copyWith({
    RtScenario? currentScenario,
    List<Map<String, String>>? messages,
    bool? isLoading,
    int? scenariosUsedThisSession,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RtPracticeState(
      currentScenario: currentScenario ?? this.currentScenario,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      scenariosUsedThisSession:
          scenariosUsedThisSession ?? this.scenariosUsedThisSession,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Free tier limit: number of scenarios allowed before the paywall.
const int kRtPracticeFreeScenarios = 5;

final rtPracticeProvider =
    StateNotifierProvider<RtPracticeNotifier, RtPracticeState>((ref) {
  return RtPracticeNotifier(ref);
});

class RtPracticeNotifier extends StateNotifier<RtPracticeState> {
  RtPracticeNotifier(this._ref)
      : super(const RtPracticeState(
          currentScenario: RtScenario.radioCheck,
          messages: [],
          isLoading: false,
          scenariosUsedThisSession: 0,
        ));

  final Ref _ref;

  String get _airfieldIcao => _ref.read(appUserProvider).valueOrNull?.airfieldIcao ?? '';

  // ── Rate-limit guard ────────────────────────────────────────────────────
  DateTime? _lastSendTime;
  static const _minSendInterval = Duration(seconds: 3);

  // ── Premium check ───────────────────────────────────────────────────────

  /// Returns true if the user is allowed to start another scenario.
  /// Premium users always pass. Free users get [kRtPracticeFreeScenarios].
  Future<bool> canStartNewScenario() async {
    if (await SubscriptionService.isPremium()) return true;
    return state.scenariosUsedThisSession < kRtPracticeFreeScenarios;
  }

  // ── Start / switch scenario ─────────────────────────────────────────────

  /// Switches to [scenario] and resets the conversation.
  /// Saves the current session's scores before clearing if there are any.
  /// Increments [scenariosUsedThisSession] only when starting a fresh scenario.
  /// Returns false if the free tier limit is reached (caller should show paywall).
  bool startScenario(RtScenario scenario) {
    if (state.scenariosUsedThisSession >= kRtPracticeFreeScenarios) return false;

    // Persist the current session before wiping it.
    _maybeSaveCurrentSession();

    state = state.copyWith(
      currentScenario: scenario,
      messages: const [],
      isLoading: false,
      scenariosUsedThisSession: state.scenariosUsedThisSession + 1,
      clearError: true,
    );

    FirebaseAnalytics.instance.logEvent(
      name: 'rt_practice_scenario_started',
      parameters: {'scenario': scenario.name},
    );
    return true;
  }

  // ── Save current session ────────────────────────────────────────────────

  /// Computes averaged scores from all scored ATC messages in the current
  /// session and persists them to SharedPreferences. No-op if there are no
  /// scored messages.
  Future<void> saveCurrentSession() async {
    await _maybeSaveCurrentSession();
  }

  Future<void> _maybeSaveCurrentSession() async {
    final scored = state.messages.where((m) {
      return m['role'] == 'atc' &&
          m['score_phrasing'] != null &&
          m['score_readback'] != null &&
          m['score_format'] != null;
    }).toList();

    if (scored.isEmpty) return;

    double avg(String key) {
      final sum = scored.fold<double>(
        0,
        (acc, m) => acc + (double.tryParse(m[key] ?? '0') ?? 0),
      );
      return sum / scored.length;
    }

    final record = RtSessionRecord(
      date: DateTime.now(),
      phrasing: avg('score_phrasing'),
      readback: avg('score_readback'),
      format: avg('score_format'),
    );

    await appendRtHistory(state.currentScenario, record);
  }

  // ── Send a student radio call ────────────────────────────────────────────

  /// Appends [studentCall] to the conversation, calls `getAiRtPractice`, and
  /// appends the ATC response.
  ///
  /// Returns `RtSendResult.rateLimited` if the rate guard fires.
  /// Returns `RtSendResult.ok` on success, `RtSendResult.error` on failure.
  Future<RtSendResult> sendStudentCall(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isLoading) return RtSendResult.noop;

    // Rate-limit guard
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _minSendInterval) {
      return RtSendResult.rateLimited;
    }
    _lastSendTime = now;

    // Enforce length (mirrors InputSanitiser.maxChat)
    final clipped = text.length > 2000 ? text.substring(0, 2000) : text;

    final updatedMessages = [
      ...state.messages,
      {'role': 'student', 'content': clipped},
    ];

    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      clearError: true,
    );

    FirebaseAnalytics.instance.logEvent(name: 'rt_practice_call_sent');

    try {
      // Force token refresh — same guard as ask_ai_screen.dart
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _appendAtcMessage(
          'You appear to be signed out. Please close the app and sign in again.',
        );
        return RtSendResult.error;
      }
      await currentUser.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('getAiRtPractice');

      // Cap history to last 20 exchanges to limit payload size
      final recent = state.messages.length > 20
          ? state.messages.sublist(state.messages.length - 20)
          : state.messages;

      final result = await callable.call<dynamic>({
        'scenario': state.currentScenario.apiValue,
        'messages': recent,
        'airfieldIcao': _airfieldIcao,
      });

      final data = result.data as Map<String, dynamic>?;
      final atcText = data?['reply'] as String? ??
          'Unable to generate ATC response. Please try again.';
      final feedbackData = data?['feedback'] as Map<String, dynamic>?;

      final atcMessage = <String, String>{'role': 'atc', 'content': atcText};
      if (feedbackData != null) {
        final p = feedbackData['phrasing'];
        final r = feedbackData['readback_accuracy'];
        final f = feedbackData['format'];
        if (p is num) atcMessage['score_phrasing'] = p.round().toString();
        if (r is num) atcMessage['score_readback'] = r.round().toString();
        if (f is num) atcMessage['score_format'] = f.round().toString();
      }
      state = state.copyWith(
        messages: [...state.messages, atcMessage],
        isLoading: false,
      );
      return RtSendResult.ok;
    } on FirebaseFunctionsException catch (e) {
      FirebaseCrashlytics.instance.recordError(e, e.stackTrace);
      String errorMsg;
      if (e.code == 'unauthenticated' ||
          e.code == 'permission-denied' ||
          e.code == 'failed-precondition') {
        errorMsg =
            'Authentication error. Please close and reopen the app, then try again.';
      } else {
        errorMsg = e.message ?? 'ATC service error. Please try again.';
      }
      _appendAtcMessage(errorMsg);
      state = state.copyWith(errorMessage: errorMsg, isLoading: false);
      return RtSendResult.error;
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
      const fallback = 'Something went wrong. Check your connection and try again.';
      _appendAtcMessage(fallback);
      state = state.copyWith(errorMessage: fallback, isLoading: false);
      return RtSendResult.error;
    }
  }

  // ── Hint ────────────────────────────────────────────────────────────────

  /// Asks the AI what the correct next radio call should be.
  /// Injects a special "hint" message so the Cloud Function can recognise it.
  Future<void> requestHint() async {
    if (state.isLoading) return;

    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _minSendInterval) {
      return;
    }
    _lastSendTime = now;

    state = state.copyWith(isLoading: true, clearError: true);

    FirebaseAnalytics.instance.logEvent(name: 'rt_practice_hint_requested');

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _appendAtcMessage('You appear to be signed out. Please sign in again.');
        return;
      }
      await currentUser.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('getAiRtPractice');

      final recent = state.messages.length > 20
          ? state.messages.sublist(state.messages.length - 20)
          : state.messages;

      final result = await callable.call<dynamic>({
        'scenario': state.currentScenario.apiValue,
        'messages': recent,
        'hint': true,
        'airfieldIcao': _airfieldIcao,
      });

      final data = result.data as Map<String, dynamic>?;
      final hintText = data?['reply'] as String? ??
          'Unable to generate a hint right now. Try again.';

      // Hint reply is shown as a system/hint bubble (role: 'hint')
      final updated = [
        ...state.messages,
        {'role': 'hint', 'content': hintText},
      ];
      state = state.copyWith(messages: updated, isLoading: false);
    } on FirebaseFunctionsException catch (e) {
      FirebaseCrashlytics.instance.recordError(e, e.stackTrace);
      _appendAtcMessage(e.message ?? 'Hint unavailable. Please try again.');
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
      _appendAtcMessage('Something went wrong. Please try again.');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _appendAtcMessage(String content) {
    final updated = [
      ...state.messages,
      {'role': 'atc', 'content': content},
    ];
    state = state.copyWith(messages: updated, isLoading: false);
  }
}

/// Result codes returned by [RtPracticeNotifier.sendStudentCall].
enum RtSendResult { ok, error, noop, rateLimited }
