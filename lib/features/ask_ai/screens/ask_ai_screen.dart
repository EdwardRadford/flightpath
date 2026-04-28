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
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

const String _kStreamUrl =
    'https://europe-west2-flight-path-fed56.cloudfunctions.net/getAiChatStream';

/// Chat interface for asking PPL(A) training questions to an AI assistant.
class AskAiScreen extends ConsumerStatefulWidget {
  final String? initialMessage;

  const AskAiScreen({super.key, this.initialMessage});

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
    if (widget.initialMessage != null) {
      _controller.text = widget.initialMessage!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildStudentContext());
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

    if (lines.isEmpty) return;

    if (mounted) {
      setState(() {
        _studentContext = 'Student profile:\n${lines.map((l) => '- $l').join('\n')}';
      });
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
              onPressed: () {
                setState(() => _messages.clear());
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
