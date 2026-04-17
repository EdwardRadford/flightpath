// RT Practice provider — manages session state for the AI-powered ATC roleplay
// feature. Mirrors the Cloud Function call pattern from ask_ai_screen.dart.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/providers/app_user_provider.dart';

// ---------------------------------------------------------------------------
// Scenario types
// ---------------------------------------------------------------------------

/// All available RT practice scenario types.
enum RtScenario {
  radioCheck('Radio Check'),
  taxiForDeparture('Taxi for Departure'),
  joiningCircuit('Joining the Circuit'),
  circuitCalls('Circuit Calls (Downwind / Base / Final)'),
  goingAround('Going Around'),
  matzTransit('MATZ Transit Request'),
  enRouteNavigation('En-Route Navigation Call'),
  emergencyMayday('Emergency (MAYDAY)'),
  emergencyPanPan('Emergency (PAN PAN)');

  const RtScenario(this.displayName);
  final String displayName;
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
  final Ref _ref;

  RtPracticeNotifier(this._ref)
      : super(const RtPracticeState(
          currentScenario: RtScenario.radioCheck,
          messages: [],
          isLoading: false,
          scenariosUsedThisSession: 0,
        ));

  // ── Rate-limit guard ────────────────────────────────────────────────────
  DateTime? _lastSendTime;
  static const _minSendInterval = Duration(seconds: 3);

  // ── Premium check ───────────────────────────────────────────────────────

  /// Returns true if the user is allowed to start another scenario.
  /// Premium users always pass. Free users get [kRtPracticeFreeScenarios].
  bool get canStartNewScenario {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user?.isPremium ?? false) return true;
    return state.scenariosUsedThisSession < kRtPracticeFreeScenarios;
  }

  // ── Start / switch scenario ─────────────────────────────────────────────

  /// Switches to [scenario] and resets the conversation.
  /// Increments [scenariosUsedThisSession] only when starting a fresh scenario.
  /// Returns false if the free tier limit is reached (caller should show paywall).
  bool startScenario(RtScenario scenario) {
    if (!canStartNewScenario) return false;

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
        'scenario': state.currentScenario.name,
        'messages': recent,
      });

      final data = result.data as Map<String, dynamic>?;
      final atcText = data?['reply'] as String? ??
          'Unable to generate ATC response. Please try again.';

      _appendAtcMessage(atcText);
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
        'scenario': state.currentScenario.name,
        'messages': recent,
        'hint': true,
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
