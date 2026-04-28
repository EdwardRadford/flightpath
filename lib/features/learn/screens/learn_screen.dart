// Learn tab — shows the AI Instructor chat directly, with RT Practice toggle.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/ask_ai/providers/ask_ai_provider.dart';
import 'package:flight_path/features/ask_ai/widgets/ask_ai_shared_widgets.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

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

    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
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
      final user = ref.read(appUserProvider).valueOrNull;
      final aircraftName =
          AppConstants.aircraftTypes[user?.aircraftType] ?? 'a training aircraft';

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
            content: 'You appear to be signed out. Please close the app and sign in again.',
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        return;
      }
      await currentUser.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('getAiChat');

      final result = await callable.call<dynamic>({
        'messages': history,
        'exerciseContext': 'Student is training on $aircraftName',
      });

      final data = result.data as Map<String, dynamic>?;
      final aiText = data?['reply'] as String? ??
          'Sorry, I couldn\'t process that right now. Please try again.';

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: aiText,
          timestamp: DateTime.now(),
        ));
      });
    } on FirebaseFunctionsException catch (e) {
      FirebaseCrashlytics.instance.recordError(e, e.stackTrace);
      String errorMsg;
      if (e.code == 'unauthenticated' ||
          e.code == 'permission-denied' ||
          e.code == 'failed-precondition') {
        errorMsg =
            'Authentication error. Please close and reopen the app, then try again.';
      } else {
        errorMsg = e.message ?? 'AI service error. Please try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: errorMsg,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'Something went wrong. Check your connection and try again.',
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
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
    final isPremium = ref.watch(premiumStatusProvider).valueOrNull ?? false;
    final showRemainingHint =
        !isPremium && !limitReached && messagesRemaining < kAskAiFreeDailyLimit;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI Instructor',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_messages.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      tooltip: 'Clear chat',
                      color: cs.onSurface.withValues(alpha: 0.4),
                      onPressed: () => setState(() => _messages.clear()),
                    ),
                  TextButton.icon(
                    onPressed: () => context.push('/learn/rt-practice'),
                    icon: const Icon(Icons.headset_mic_rounded, size: 16),
                    label: const Text('RT Practice'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Messages list ─────────────────────────────────────────
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

            // ── Daily limit banner ────────────────────────────────────
            if (limitReached)
              AskAiDailyLimitBanner(onUpgradeTapped: _showPaywall),

            // ── Messages-remaining hint ───────────────────────────────
            if (showRemainingHint)
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

            // ── Input bar ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
                  const SizedBox(width: 8),
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
      ),
    );
  }
}
