// Ask AI screen — free-form chat with an AI flight training assistant
// powered by Claude via a Firebase Cloud Function.
import 'dart:async';
import 'dart:convert';

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
import 'package:flight_path/features/logbook/providers/logbook_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/services/hive_service.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// Cap persisted history so the Hive box can't grow unbounded across sessions.
const int _kMaxPersistedMessages = 50;
// Hive key — namespaced by UID so different accounts on the same device get
// separate chat histories. Falls back to `anon` for unauthenticated states.
String _askAiHistoryKey() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return 'messages_$uid';
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
  String _studentContext = '';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildStudentContext());
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
      final raw = HiveService().askAiHistoryBox.get(_askAiHistoryKey());
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
      await HiveService().askAiHistoryBox.put(_askAiHistoryKey(), encoded);
    } catch (e, stack) {
      debugPrint('AskAi: failed to persist chat history: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
    }
  }

  Future<void> _clearPersistedHistory() async {
    try {
      await HiveService().askAiHistoryBox.delete(_askAiHistoryKey());
    } catch (e, stack) {
      debugPrint('AskAi: failed to clear chat history: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
    }
  }

  void _buildStudentContext() {
    if (!mounted) return;

    final user = ref.read(appUserProvider).valueOrNull;
    final userExercises = ref.read(userExercisesProvider).valueOrNull ?? [];
    final lessons = ref.read(allLessonsProvider).valueOrNull ?? [];
    final totals = ref.read(logbookTotalsProvider);

    final lines = <String>[];

    if (user != null) {
      final firstName = user.displayName.split(' ').first;
      if (firstName.isNotEmpty) lines.add('Name: $firstName');

      final aircraftName = AppConstants.aircraftTypes[user.aircraftType];
      if (aircraftName != null && aircraftName.isNotEmpty) {
        lines.add('Aircraft: $aircraftName');
      }

      if (user.airfieldIcao.isNotEmpty) {
        lines.add('Home airfield: ${user.airfieldIcao}');
      }
    }

    if (totals.totalMinutes > 0) {
      final h = totals.totalMinutes ~/ 60;
      final m = totals.totalMinutes % 60;
      lines.add('Total hours flown: ${h}h ${m.toString().padLeft(2, '0')}m');
    }

    if (totals.entryCount > 0) {
      lines.add('Lessons logged: ${totals.entryCount}');
    }

    if (user != null) {
      final currentExId = _currentExerciseId(user.currentExerciseNumber);
      if (currentExId != null) {
        final title = AppConstants.exerciseTitles[currentExId] ??
            AppConstants.exerciseNames[currentExId];
        if (title != null) {
          lines.add('Current exercise: $title (Exercise ${user.currentExerciseNumber})');
        }
      }
    }

    final completed = userExercises
        .where((e) => e.status.isCompleted)
        .toList();
    if (completed.isNotEmpty) {
      lines.add('Completed exercises: ${completed.length}/${AppConstants.allExerciseIds.length}');
    }

    final highRated = userExercises
        .where((e) => (e.bestRating ?? 0) >= 4)
        .take(10)
        .map((e) => _exerciseLabel(e.exerciseId, e.subExercise))
        .where((s) => s.isNotEmpty)
        .toList();
    if (highRated.isNotEmpty) {
      lines.add('Exercises rated 4+/5: ${highRated.join(', ')}');
    }

    final weakAreas = userExercises
        .where((e) => (e.bestRating ?? 0) > 0 && (e.bestRating ?? 0) <= 2)
        .map((e) => _exerciseLabel(e.exerciseId, e.subExercise))
        .where((s) => s.isNotEmpty)
        .toList();
    if (weakAreas.isNotEmpty) {
      lines.add('Weak areas (rated 1-2/5): ${weakAreas.join(', ')}');
    }

    final recentLessons = lessons
        .where((l) =>
            l.status != LessonStatus.cancelled &&
            l.status != LessonStatus.scheduled &&
            l.studentRating != null)
        .take(3)
        .toList();
    if (recentLessons.isNotEmpty) {
      final lessonSummaries = recentLessons.map((l) {
        final label = _exerciseLabel(l.exerciseId, l.subExercise.isEmpty ? null : l.subExercise);
        final date = l.lessonDate ?? l.createdAt;
        final dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        return '$label ($dateStr, ${l.studentRating}/5)';
      }).join('; ');
      lines.add('Last 3 lessons: $lessonSummaries');
    }

    // Debrief-mode: append exercise-specific history and notes.
    if (widget.debriefExerciseId != null) {
      final ue = userExercises.where((e) =>
        e.exerciseId == widget.debriefExerciseId &&
        e.subExercise == widget.debriefSubExercise,
      ).firstOrNull;
      final exLabel = _exerciseLabel(widget.debriefExerciseId!, widget.debriefSubExercise);

      lines.add('---');
      lines.add('DEBRIEF SESSION: ${exLabel.isNotEmpty ? exLabel : widget.debriefExerciseId}');
      if (ue != null) {
        if (ue.timesAttempted > 0) lines.add('Times flown: ${ue.timesAttempted}');
        if (ue.ratingHistory.isNotEmpty) {
          lines.add('Rating history: ${ue.ratingHistory.map((r) => '$r/5').join(', ')}');
        }
        if (ue.debriefNotes?.isNotEmpty == true) {
          lines.add('What went well (previous): ${ue.debriefNotes}');
        }
        if (ue.focusNextTime?.isNotEmpty == true) {
          lines.add('Focus area (previous): ${ue.focusNextTime}');
        }
        if (ue.instructorNotes?.isNotEmpty == true) {
          lines.add('Instructor notes: ${ue.instructorNotes}');
        }
      }
    }

    if (lines.isEmpty) return;

    if (mounted) {
      setState(() {
        _studentContext = 'Student profile:\n${lines.map((l) => '- $l').join('\n')}';
      });
    }

    // Auto-send the debrief opener once context is built.
    if (mounted && widget.debriefExerciseId != null && !_debriefAutoSent) {
      _debriefAutoSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendDebriefIntro());
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

  String? _currentExerciseId(int exerciseNumber) {
    final paddedNum = exerciseNumber.toString().padLeft(2, '0');
    final baseKey = 'ex_$paddedNum';
    if (AppConstants.exerciseTitles.containsKey(baseKey)) return baseKey;
    for (final id in AppConstants.allExerciseIds) {
      if (id.startsWith('ex_$paddedNum')) return id;
    }
    return null;
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
    } catch (_) {
      if (mounted) setState(() => _sttReady = false);
    }
  }

  Future<void> _toggleListening() async {
    if (!_sttReady) return;
    if (_isListening) {
      await _stt.stop();
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
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
      _micPulse.stop();
    }
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
        studentContext: _studentContext,
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
            content: 'Something went wrong. Check your connection and try again.',
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendMessageStreaming({
    required List<Map<String, String>> history,
    required String studentContext,
    required User currentUser,
  }) async {
    final token = await currentUser.getIdToken(true);

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
      final body = <String, dynamic>{'messages': history};
      if (studentContext.isNotEmpty) body['studentContext'] = studentContext;
      request.body = jsonEncode(body);

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Stream request failed with status ${response.statusCode}');
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
            setState(() => _isLoading = false);
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
    final showRemainingHint =
        !isPremium && !limitReached && messagesRemaining < kAskAiFreeDailyLimit;
    final showLowWarning =
        !isPremium && !limitReached && messagesRemaining <= 2 && messagesRemaining > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Ask AI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        leading: const BackButton(),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear conversation',
              onPressed: () async {
                setState(() => _messages.clear());
                await _clearPersistedHistory();
              },
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
              child: _messages.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Ask anything',
                      subtitle:
                          'Your AI Instructor is ready. Ask about theory, procedures, weather — anything from your training.',
                    )
                  : ListView.builder(
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

          // ── Free usage counter (always visible for free users) ────
          if (!isPremium && !limitReached && !showLowWarning && !showRemainingHint)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '${limitState.dailyMessageCount} / $kAskAiFreeDailyLimit free messages today',
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
