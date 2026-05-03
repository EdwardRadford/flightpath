// Ask AI screen — free-form chat with an AI flight training assistant
// powered by Claude via a Firebase Cloud Function.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/ask_ai/providers/ask_ai_provider.dart';
import 'package:flight_path/features/ask_ai/widgets/ask_ai_shared_widgets.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/services/connectivity_service.dart';
import 'package:flight_path/shared/services/hive_service.dart';
import 'package:flight_path/shared/services/log_buffer_service.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

/// Internal sentinel for non-200 HTTP responses from the AI stream endpoint.
/// Lets the outer catch branch cleanly on status code without re-parsing
/// generic Exception strings.
class _AiStreamHttpException implements Exception {
  final int statusCode;
  _AiStreamHttpException(this.statusCode);
  @override
  String toString() => '_AiStreamHttpException($statusCode)';
}

// Cap persisted history so the Hive box can't grow unbounded across sessions.
const int _kMaxPersistedMessages = 50;
// Schema version — bump if the persisted shape changes so old payloads are
// silently discarded rather than crashing the screen.
const int _kHistorySchemaVersion = 1;
// Hive key — namespaced by UID so different accounts on the same device get
// separate chat histories. Returns null when no signed-in user exists, in
// which case persistence is skipped and the chat lives only in memory.
String? _askAiHistoryKey() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return null;
  return 'messages_v${_kHistorySchemaVersion}_$uid';
}

const String _kStreamUrl =
    'https://europe-west2-flight-path-fed56.cloudfunctions.net/getAiChatStream';

/// Chat interface for asking PPL(A) training questions to an AI assistant.
class AskAiScreen extends ConsumerStatefulWidget {
  final String? initialMessage;

  /// When set, the screen opens in debrief mode — primes the AI with
  /// exercise-specific context and auto-sends the opening prompt.
  final String? debriefExerciseId;
  final String? debriefSubExercise;

  const AskAiScreen({
    super.key,
    this.initialMessage,
    this.debriefExerciseId,
    this.debriefSubExercise,
  });

  @override
  ConsumerState<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends ConsumerState<AskAiScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  DateTime? _lastSendTime;
  static const _minSendInterval = Duration(seconds: 3);
  String? _lastUserMessage;
  bool _hasError = false;
  bool _debriefAutoSent = false;
  bool _isSavingDebrief = false;

  // Streaming
  int? _streamingMessageIndex;

  // STT
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttReady = false;
  bool _isListening = false;
  late final AnimationController _micPulse;

  @override
  void initState() {
    super.initState();
    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initStt();
    // Restore persisted chat history before anything else, so the user sees
    // their previous conversation immediately when re-entering the screen.
    // Skipped for debrief sessions — those are intentionally fresh.
    if (widget.debriefExerciseId == null) {
      _loadPersistedHistory();
    }
    // Only pre-fill the text field for generic links — debrief mode auto-sends.
    if (widget.initialMessage != null && widget.debriefExerciseId == null) {
      _controller.text = widget.initialMessage!;
    }
    // Debrief mode auto-sends the opening prompt once the screen is ready.
    // Generic mode just opens to an empty (or restored) chat.
    if (widget.debriefExerciseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _debriefAutoSent) return;
        _debriefAutoSent = true;
        _sendDebriefIntro();
      });
    } else {
      // Generic mode: drop in a personalised greeting once the frame is up.
      // Only fires if hydration left _messages empty (i.e. true first use or
      // post-Clear state). The greeting is itself persisted, so re-opening
      // the screen restores it rather than re-adding a duplicate.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_messages.isNotEmpty) return;
        _maybeAddGreetingWhenUserReady();
      });
    }
  }

  /// Schedules the personalised greeting once the [appUserProvider] has
  /// emitted a value. We wait so the greeting includes the real first name,
  /// current exercise number, and aircraft type instead of the fallback
  /// `Hi there, working on Exercise 1: ...` that fires when the provider
  /// is still in `AsyncValue.loading`.
  ///
  /// On a cold start the provider can take a few hundred ms to resolve while
  /// Firestore returns the user doc. If it's already resolved (warm start
  /// after sign-in earlier in the session) the greeting fires immediately.
  void _maybeAddGreetingWhenUserReady() {
    if (!mounted) return;
    final userAsync = ref.read(appUserProvider);
    if (userAsync.valueOrNull != null) {
      _addGreeting();
      return;
    }
    // Provider not yet resolved — listen for the first non-null emission,
    // drop the greeting, then close the subscription so it doesn't re-fire
    // on later Firestore updates to the user doc.
    ProviderSubscription<AsyncValue<dynamic>>? sub;
    var done = false;
    void finish() {
      if (done) return;
      done = true;
      sub?.close();
      if (!mounted) return;
      if (_messages.isEmpty) _addGreeting();
    }

    sub = ref.listenManual<AsyncValue<dynamic>>(
      appUserProvider,
      (prev, next) {
        if (next.hasValue) finish();
      },
    );
    // Safety net: if the provider never resolves (e.g. signed-out edge case
    // or Firestore offline) drop the greeting with fallbacks after 1.5s so
    // the screen isn't perpetually empty.
    Timer(const Duration(milliseconds: 1500), finish);
  }

  // ---------------------------------------------------------------------------
  // Hive persistence
  //
  // Stored shape (single key per user, JSON-encoded):
  //   [{"role": "user"|"assistant", "content": "...", "timestamp": <ms>}, ...]
  // Resilient: any read failure is logged and silently swallowed so the
  // screen always opens with at least an empty list.
  // ---------------------------------------------------------------------------

  void _loadPersistedHistory() {
    try {
      final key = _askAiHistoryKey();
      // Anonymous / signed-out users: no persistence — chat is in-memory only.
      if (key == null) return;
      final raw = HiveService().askAiHistoryBox.get(key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = <ChatMessage>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final role = entry['role'];
        final content = entry['content'];
        final ts = entry['timestamp'];
        if (role is! String || content is! String) continue;
        if (role != 'user' && role != 'assistant') continue;
        if (content.isEmpty) continue;
        final timestamp = ts is int
            ? DateTime.fromMillisecondsSinceEpoch(ts)
            : DateTime.now();
        restored.add(ChatMessage(
          role: role,
          content: content,
          timestamp: timestamp,
        ));
      }
      if (restored.isEmpty) return;
      // Trim to cap before showing.
      if (restored.length > _kMaxPersistedMessages) {
        restored.removeRange(0, restored.length - _kMaxPersistedMessages);
      }
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(restored);
        });
        _scrollToBottom();
      } else {
        _messages
          ..clear()
          ..addAll(restored);
      }
    } catch (e, stack) {
      debugPrint('AskAi: failed to restore chat history: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
    }
  }

  Future<void> _persistHistory() async {
    // Debrief sessions are ephemeral — never write them to disk.
    if (widget.debriefExerciseId != null) return;
    final key = _askAiHistoryKey();
    // Anonymous / signed-out users: in-memory only.
    if (key == null) return;
    try {
      // Only persist completed (non-empty) messages — skip the placeholder
      // bubble that streaming uses while a delta is in flight.
      final source = _messages.where((m) => m.content.isNotEmpty).toList();
      final start = source.length > _kMaxPersistedMessages
          ? source.length - _kMaxPersistedMessages
          : 0;
      final encoded = jsonEncode(
        source.sublist(start).map((m) => {
              'role': m.role,
              'content': m.content,
              'timestamp': m.timestamp.millisecondsSinceEpoch,
            }).toList(),
      );
      await HiveService().askAiHistoryBox.put(key, encoded);
    } catch (e, stack) {
      debugPrint('AskAi: failed to persist chat history: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
    }
  }

  Future<void> _clearPersistedHistory() async {
    final key = _askAiHistoryKey();
    if (key == null) return;
    try {
      await HiveService().askAiHistoryBox.delete(key);
    } catch (e, stack) {
      debugPrint('AskAi: failed to clear chat history: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
    }
  }

  String _buildDebriefPrompt() {
    final label = _exerciseLabel(
      widget.debriefExerciseId!,
      widget.debriefSubExercise,
    );
    final name = label.isNotEmpty ? label : 'this exercise';
    return 'I\'d like a debrief on $name. Use my notes and lesson history from your '
        'context to give me a structured debrief directly — what went well, what to '
        'improve, and what to focus on next time. Only ask me a follow-up question '
        'if you genuinely need more information that isn\'t in my context. Maximum '
        '2 questions if you do ask. Most of the time you should be able to debrief '
        'me without asking anything.';
  }

  Future<void> _sendDebriefIntro() async {
    if (!mounted) return;
    _controller.text = _buildDebriefPrompt();
    await _sendMessage();
  }

  Future<void> _saveDebriefToNotes() async {
    final lastAi = _messages.lastWhere(
      (m) => m.role == 'assistant' && m.content.isNotEmpty,
      orElse: () => ChatMessage(role: '', content: '', timestamp: DateTime.now()),
    );
    if (lastAi.role.isEmpty || lastAi.content.isEmpty) return;
    setState(() => _isSavingDebrief = true);
    try {
      await saveAiDebrief(
        ref,
        widget.debriefExerciseId!,
        widget.debriefSubExercise,
        lastAi.content,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debrief saved to exercise notes')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingDebrief = false);
    }
  }

  String _exerciseLabel(String exerciseId, String? subExercise) {
    final compositeId = (subExercise != null && subExercise.isNotEmpty)
        ? '${exerciseId}_$subExercise'
        : exerciseId;
    return AppConstants.exerciseTitles[compositeId] ??
        AppConstants.exerciseTitles[exerciseId] ??
        '';
  }

  Future<void> _initStt() async {
    try {
      final ready = await _stt.initialize(
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
          _micPulse.stop();
        },
        onStatus: (status) {
          if (status == stt.SpeechToText.doneStatus ||
              status == stt.SpeechToText.notListeningStatus) {
            if (mounted) setState(() => _isListening = false);
            _micPulse.stop();
          }
        },
      );
      if (mounted) setState(() => _sttReady = ready);
    } catch (e, st) {
      // STT init failure is recoverable — text-only fallback — but report so
      // we can spot a regression on a particular device class.
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'AskAi: STT init failed',
        fatal: false,
      );
      if (mounted) setState(() => _sttReady = false);
    }
  }

  Future<void> _toggleListening() async {
    if (!_sttReady) return;
    if (_isListening) {
      await _stt.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      _micPulse.stop();
      return;
    }
    setState(() => _isListening = true);
    _micPulse.repeat(reverse: true);
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          if (mounted) {
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_GB',
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'AskAi: STT listen failed',
        fatal: false,
      );
      if (mounted) setState(() => _isListening = false);
      _micPulse.stop();
    }
  }

  void _addGreeting() {
    if (!mounted) return;
    if (_messages.isNotEmpty) return;
    final user = ref.read(appUserProvider).valueOrNull;
    final firstName = (user?.displayName ?? '').split(' ').first;
    final name = firstName.isNotEmpty ? firstName : 'there';
    final exNum = user?.currentExerciseNumber ?? 1;
    final exId = 'ex_${exNum.toString().padLeft(2, '0')}';
    final exTitle = AppConstants.exerciseTitles[exId] ?? 'your exercise';
    final aircraft =
        AppConstants.aircraftTypes[user?.aircraftType ?? ''] ?? 'your aircraft';

    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content:
            'Hi $name, working on Exercise $exNum: $exTitle in your $aircraft. What can I help with?',
        timestamp: DateTime.now(),
      ));
    });
    // Persist the greeting so the next visit to the screen restores it
    // instead of re-adding a duplicate. Skipped for anon users + debrief
    // mode inside _persistHistory.
    unawaited(_persistHistory());
  }

  /// Confirms the destructive Clear action with a dialog before wiping the
  /// Hive box, resetting `_messages`, and re-adding the greeting (so the
  /// post-Clear state matches a true first-open).
  Future<void> _confirmClearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
          "This can't be undone. Your previous messages will be removed from "
          'this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _hasError = false;
      _streamingMessageIndex = null;
      _lastUserMessage = null;
    });
    await _clearPersistedHistory();
    if (!mounted) return;
    // Re-add the greeting so the screen feels like a fresh first-open.
    // _addGreeting persists itself, matching the empty-then-greeting state.
    _addGreeting();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _micPulse.dispose();
    if (_isListening) _stt.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty || _isLoading) return;

    final allowed =
        await ref.read(askAiLimitProvider.notifier).canSendMessage();
    if (!mounted) return;
    if (!allowed) return;

    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _minSendInterval) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before sending another message.'),
        ),
      );
      return;
    }
    _lastSendTime = now;

    final text = InputSanitiser.sanitise(
      rawText,
      maxLength: InputSanitiser.maxChat,
    );
    if (text.isEmpty) return;

    if (_isListening) {
      await _stt.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      _micPulse.stop();
    }

    _lastUserMessage = text;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _hasError = false;
    });
    _scrollToBottom();
    // Persist the user's message immediately so it survives even if the
    // AI request fails or the user leaves the screen mid-flight.
    unawaited(_persistHistory());

    await ref.read(askAiLimitProvider.notifier).incrementMessageCount();
    if (!mounted) return;

    final userMessages = _messages.where((m) => m.role == 'user').length;
    if (userMessages == 1) {
      FirebaseAnalytics.instance.logEvent(name: 'ai_chat_started');
    }
    FirebaseAnalytics.instance.logEvent(name: 'ai_chat_message_sent');
    FirebaseAnalytics.instance.logEvent(
      name: 'ai_message_sent',
      parameters: {'message_length': text.length},
    );

    try {
      final recentMessages = _messages.length > 20
          ? _messages.sublist(_messages.length - 20)
          : _messages;
      final history = recentMessages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content:
                'You appear to be signed out. Please close the app and sign in again.',
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        return;
      }

      await _sendMessageStreaming(
        history: history,
        currentUser: currentUser,
      );
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
      if (mounted) {
        setState(() {
          _hasError = true;
          _streamingMessageIndex = null;
          _messages.add(ChatMessage(
            role: 'assistant',
            content: _classifyAiError(e),
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Maps a thrown error from the AI request into actionable user copy.
  /// Three cases: offline, auth/App Check failure, generic server error.
  String _classifyAiError(Object error) {
    // 1. Offline — check connectivity provider first, then fall back to
    //    socket/handshake failures that can fire even when Connectivity says
    //    we're online (e.g. captive portal, DNS down).
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline ||
        error is SocketException ||
        error is HandshakeException ||
        error is HttpException ||
        error is http.ClientException ||
        error is TimeoutException) {
      LogBufferService.log(
          'AskAi: classified as offline (${error.runtimeType})');
      return "You're offline. The AI needs an internet connection — try "
          'again when you\'re reconnected.';
    }

    // 2. Auth / App Check / Firebase auth issues — surface a sign-out hint.
    if (error is FirebaseAuthException) {
      LogBufferService.log(
          'AskAi: FirebaseAuthException code=${error.code}');
      return "Couldn't verify your account. Try signing out and back in if "
          'this keeps happening.';
    }
    if (error is FirebaseFunctionsException) {
      const authCodes = {
        'unauthenticated',
        'internal',
        'permission-denied',
      };
      LogBufferService.log(
          'AskAi: FirebaseFunctionsException code=${error.code}');
      if (authCodes.contains(error.code)) {
        return "Couldn't verify your account. Try signing out and back in if "
            'this keeps happening.';
      }
    }
    if (error is _AiStreamHttpException) {
      LogBufferService.log(
          'AskAi: stream HTTP ${error.statusCode}');
      if (error.statusCode == 401 || error.statusCode == 403) {
        return "Couldn't verify your account. Try signing out and back in if "
            'this keeps happening.';
      }
    }

    // 3. Server / unknown — calmer "have a moment" copy + retry banner.
    LogBufferService.log(
        'AskAi: unclassified error ${error.runtimeType}: $error');
    return 'The AI service is having a moment. Tap to retry.';
  }

  Future<void> _sendMessageStreaming({
    required List<Map<String, String>> history,
    required User currentUser,
  }) async {
    final token = await currentUser.getIdToken(true);
    if (!mounted) return;

    // Insert a placeholder assistant message; streaming text will fill it.
    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
      ));
      _streamingMessageIndex = _messages.length - 1;
    });

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(_kStreamUrl));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      // Server fetches student context from Firestore; client no longer
      // sends it in the body. We do flag examiner mode when the student
      // is inside their skills-test prep window so the function flips
      // tone (rigorous, CAA tolerances, less encouragement).
      final body = <String, dynamic>{'messages': history};
      final user = ref.read(appUserProvider).valueOrNull;
      if (user != null && user.isInTestPrepWindow) {
        body['mode'] = 'examiner';
      }
      request.body = jsonEncode(body);

      final response = await client.send(request);
      if (!mounted) return;

      if (response.statusCode != 200) {
        // Drain the body — small JSON, safe to await — so we can detect
        // server-side daily-limit responses and switch the UI accordingly.
        final raw = await response.stream.bytesToString();
        if (response.statusCode == 429) {
          Map<String, dynamic>? parsed;
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) parsed = decoded;
          } catch (e, st) {
            // Malformed 429 body — fall through to generic error below, but
            // record so a server-side regression is visible.
            FirebaseCrashlytics.instance.recordError(
              e, st,
              reason: 'AskAi: malformed 429 JSON body from getAiChatStream',
              fatal: false,
            );
          }
          if (parsed != null && parsed['type'] == 'daily_limit_reached') {
            await ref
                .read(askAiLimitProvider.notifier)
                .markServerLimitReached();
            if (mounted) {
              setState(() {
                _isLoading = false;
                final idx = _streamingMessageIndex;
                if (idx != null && _messages[idx].content.isEmpty) {
                  _messages.removeAt(idx);
                }
                _streamingMessageIndex = null;
              });
            }
            return;
          }
        }
        throw _AiStreamHttpException(response.statusCode);
      }

      final buffer = StringBuffer();
      bool firstDelta = true;

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload.isEmpty) continue;

        Map<String, dynamic> event;
        try {
          event = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final type = event['type'] as String?;

        if (type == 'delta') {
          final chunk = event['text'] as String? ?? '';
          buffer.write(chunk);
          if (firstDelta) {
            firstDelta = false;
            if (mounted) setState(() => _isLoading = false);
          }
          final idx = _streamingMessageIndex;
          if (idx != null && mounted) {
            setState(() {
              _messages[idx] = ChatMessage(
                role: 'assistant',
                content: buffer.toString(),
                timestamp: _messages[idx].timestamp,
              );
            });
            _scrollToBottom();
          }
        } else if (type == 'done') {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _streamingMessageIndex = null;
              _hasError = false;
            });
            _scrollToBottom();
          }
          // Persist the completed assistant reply.
          unawaited(_persistHistory());
          break;
        } else if (type == 'error') {
          final msg = event['message'] as String? ??
              'AI service error. Please try again.';
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              final idx = _streamingMessageIndex;
              if (idx != null && _messages[idx].content.isEmpty) {
                _messages.removeAt(idx);
              }
              _streamingMessageIndex = null;
              _messages.add(ChatMessage(
                role: 'assistant',
                content: msg,
                timestamp: DateTime.now(),
              ));
            });
            _scrollToBottom();
          }
          // Persist so the error reply isn't lost on navigation.
          unawaited(_persistHistory());
          break;
        }
      }

      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _streamingMessageIndex = null;
        });
      }
    } finally {
      client.close();
    }
  }

  Future<void> _showPaywall() async {
    await showPremiumPaywall(context, source: 'ask_ai_daily_limit');
  }

  @override
  Widget build(BuildContext context) {
    final limitState = ref.watch(askAiLimitProvider);
    final limitReached = limitState.limitReached;
    final messagesRemaining = limitState.messagesRemaining;
    final isPremium =
        ref.watch(premiumStatusProvider).valueOrNull ?? false;
    // Hide all free-tier counters/hints until the user has actually sent a
    // message — a "0 / 3 free" row on a brand-new chat reads hostile. Once
    // they engage (or a previous session's count is non-zero), surface it.
    final hasUserSent = _messages.any((m) => m.role == 'user');
    final showFreeMeters =
        !isPremium && (hasUserSent || limitState.dailyMessageCount > 0);
    final showRemainingHint = showFreeMeters &&
        !limitReached &&
        messagesRemaining < kAskAiFreeDailyLimit;
    final showLowWarning = showFreeMeters &&
        !limitReached &&
        messagesRemaining <= 2 &&
        messagesRemaining > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'AI Instructor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        leading: const BackButton(),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear conversation',
              onPressed: _confirmClearConversation,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages list ────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoading) {
                          return const AskAiTypingIndicator();
                        }
                        return AskAiMessageBubble(message: _messages[index]);
                      },
                    ),
            ),
          ),

          // ── Retry banner ─────────────────────────────────────────
          if (_hasError && _lastUserMessage != null && !_isLoading)
            GestureDetector(
              onTap: () {
                setState(() => _hasError = false);
                _controller.text = _lastUserMessage!;
                _sendMessage();
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.error.withValues(alpha: 0.08),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text(
                      'Tap to retry last message',
                      style: TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

          // ── Daily limit banner ───────────────────────────────────
          if (limitReached)
            AskAiDailyLimitBanner(onUpgradeTapped: _showPaywall),

          // ── Low-message warning (≤2 remaining) ──────────────────
          if (showLowWarning)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    '$messagesRemaining message${messagesRemaining == 1 ? '' : 's'} left today — upgrade for unlimited',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // ── Messages-remaining hint (3–4 remaining) ──────────────
          if (showRemainingHint && !showLowWarning)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '$messagesRemaining message${messagesRemaining == 1 ? '' : 's'} remaining today',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // ── Free usage counter (free users, after first send) ────
          if (showFreeMeters &&
              !limitReached &&
              !showLowWarning &&
              !showRemainingHint)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '${limitState.dailyMessageCount} of $kAskAiFreeDailyLimit free messages used today — upgrade for unlimited',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // ── Debrief save banner ─────────────────────────────────
          if (widget.debriefExerciseId != null &&
              _messages.any(
                  (m) => m.role == 'assistant' && m.content.isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _isSavingDebrief ? null : _saveDebriefToNotes,
                icon: _isSavingDebrief
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_outlined, size: 16),
                label: Text(
                  _isSavingDebrief
                      ? 'Saving...'
                      : 'Save debrief to exercise notes',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side:
                      BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          // ── Input bar ────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              12,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !limitReached,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLength: InputSanitiser.maxChat,
                    maxLines: 5,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: limitReached
                          ? 'Daily limit reached'
                          : 'Ask anything about flying...',
                      hintStyle: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_sttReady && !limitReached) ...[
                  const SizedBox(width: 4),
                  AnimatedBuilder(
                    animation: _micPulse,
                    builder: (context, _) {
                      return IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none_rounded,
                          color: _isListening
                              ? Color.lerp(
                                  AppColors.error,
                                  AppColors.error.withValues(alpha: 0.4),
                                  _micPulse.value,
                                )!
                              : AppColors.onSurfaceVariant,
                          size: 22,
                        ),
                        onPressed: _toggleListening,
                        tooltip:
                            _isListening ? 'Stop listening' : 'Voice input',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      );
                    },
                  ),
                ],
                const SizedBox(width: 4),
                Material(
                  color: (_isLoading || limitReached)
                      ? AppColors.surfaceVariant
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: (_isLoading || limitReached) ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: (_isLoading || limitReached)
                            ? AppColors.onSurfaceVariant
                            : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
