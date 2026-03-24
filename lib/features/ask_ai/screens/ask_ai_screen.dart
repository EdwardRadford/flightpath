// Ask AI screen — free-form chat with an AI flight training assistant
// powered by Claude via a Firebase Cloud Function.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// Chat message model
// ---------------------------------------------------------------------------

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  const _ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

// ---------------------------------------------------------------------------
// Ask AI Screen
// ---------------------------------------------------------------------------

/// Chat interface for asking PPL(A) training questions to an AI assistant.
class AskAiScreen extends ConsumerStatefulWidget {
  const AskAiScreen({super.key});

  @override
  ConsumerState<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends ConsumerState<AskAiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  /// Simple client-side rate limit: minimum interval between API calls.
  DateTime? _lastSendTime;
  static const _minSendInterval = Duration(seconds: 3);

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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

    // --- Rate limit: prevent rapid-fire API calls ---
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _minSendInterval) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before sending another message.'),
        ),
      );
      return;
    }
    _lastSendTime = now;

    // --- Sanitise & enforce length limit ---
    final text = InputSanitiser.sanitise(
      rawText,
      maxLength: InputSanitiser.maxChat,
    );
    if (text.isEmpty) return;

    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    // Analytics: track first message and every message
    final userMessages = _messages.where((m) => m.role == 'user').length;
    if (userMessages == 1) {
      FirebaseAnalytics.instance.logEvent(name: 'ai_chat_started');
    }
    FirebaseAnalytics.instance.logEvent(
      name: 'ai_message_sent',
      parameters: {'message_length': text.length},
    );

    try {
      final user = ref.read(appUserProvider).valueOrNull;
      // aircraftName comes from a constrained dropdown — safe to interpolate.
      final aircraftName =
          AppConstants.aircraftTypes[user?.aircraftType] ?? 'a training aircraft';

      // Build conversation history — cap at last 20 messages to limit payload
      // size and prevent abuse via huge context windows.
      final recentMessages = _messages.length > 20
          ? _messages.sublist(_messages.length - 20)
          : _messages;
      final history = recentMessages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('getAiDebrief');

      final result = await callable.call<dynamic>({
        'mode': 'chat',
        'aircraftName': aircraftName,
        'messages': history,
      });

      final data = result.data as Map<String, dynamic>?;
      final aiText = data?['reply'] as String? ??
          'Sorry, I couldn\'t process that right now. Please try again.';

      setState(() {
        _messages.add(_ChatMessage(
          role: 'assistant',
          content: aiText,
          timestamp: DateTime.now(),
        ));
      });
    } on FirebaseFunctionsException catch (e) {
      FirebaseCrashlytics.instance.recordError(e, e.stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'AI service error. Please try again.'),
          ),
        );
      }
      setState(() {
        _messages.add(_ChatMessage(
          role: 'assistant',
          content:
              'Sorry, I couldn\'t process that right now. Please try again.',
          timestamp: DateTime.now(),
        ));
      });
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
      setState(() {
        _messages.add(_ChatMessage(
          role: 'assistant',
          content:
              'Something went wrong. Check your connection and try again.',
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // ── Messages list ────────────────────────────────────────
          Expanded(
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
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
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
            decoration:  BoxDecoration(
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
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLength: InputSanitiser.maxChat,
                    maxLines: 5,
                    style:  TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask anything about flying...',
                      hintStyle:  TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      counterText: '', // hide the character counter
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
                const SizedBox(width: 8),
                Material(
                  color: _isLoading
                      ? AppColors.surfaceVariant
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _isLoading ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _isLoading
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

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary.withValues(alpha:0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.divider),
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: isUser ? FontWeight.w400 : FontWeight.w400,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------------

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.divider),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final offset = (_controller.value + i * 0.33) % 1.0;
                    final opacity = 0.3 + 0.7 * (1.0 - (offset - 0.5).abs() * 2).clamp(0.0, 1.0);
                    return Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
