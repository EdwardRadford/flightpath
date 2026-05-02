// RT Practice screen — AI-powered ATC roleplay for UK PPL student pilots.
// Mirrors the chat UI pattern from ask_ai_screen.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';
import 'package:flight_path/features/learn/providers/rt_practice_provider.dart';
import 'package:flight_path/shared/services/voice_service.dart';

// ---------------------------------------------------------------------------
// RT Practice Screen
// ---------------------------------------------------------------------------

/// Main RT Practice screen — scenario selector, chat list, input bar.
class RtPracticeScreen extends ConsumerStatefulWidget {
  const RtPracticeScreen({super.key});

  @override
  ConsumerState<RtPracticeScreen> createState() => _RtPracticeScreenState();
}

class _RtPracticeScreenState extends ConsumerState<RtPracticeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final VoiceService _voice;
  bool _muted = false;
  bool _showTranscript = false;
  bool _showHistory = false;
  bool _wasListening = false;
  double _ttsSpeed = 0.45; // 0.3 = slow, 0.45 = normal, 0.65 = fast

  static const _kTtsSpeedKey = 'rt_tts_speed';
  static const _kSpeedSlow = 0.3;
  static const _kSpeedNormal = 0.45;
  static const _kSpeedFast = 0.65;

  @override
  void initState() {
    super.initState();
    _voice = VoiceService();
    _voice.addListener(_onVoiceStateChanged);
    _voice.init().then((_) => _loadTtsSpeed());
  }

  Future<void> _loadTtsSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kTtsSpeedKey);
    if (saved != null && mounted) {
      setState(() => _ttsSpeed = saved);
      await _voice.setSpeechRate(saved);
    }
  }

  Future<void> _setTtsSpeed(double speed) async {
    setState(() => _ttsSpeed = speed);
    await _voice.setSpeechRate(speed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTtsSpeedKey, speed);
  }

  void _onVoiceStateChanged() {
    if (!mounted) return;
    final wasListening = _wasListening;
    _wasListening = _voice.isListening;
    // Auto-send when STT ends and there is transcribed text
    if (wasListening && !_voice.isListening) {
      final text = _controller.text.trim();
      if (text.isNotEmpty) _handleSend();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _voice.removeListener(_onVoiceStateChanged);
    _voice.dispose();
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

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Stop any active listening before sending
    if (_voice.isListening) await _voice.stopListening();

    _controller.clear();
    final result = await ref
        .read(rtPracticeProvider.notifier)
        .sendStudentCall(text);

    if (!mounted) return;

    if (result == RtSendResult.rateLimited) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before sending another call.'),
        ),
      );
    } else if (result == RtSendResult.ok) {
      // Speak the latest ATC reply if not muted
      if (!_muted) {
        final messages = ref.read(rtPracticeProvider).messages;
        final lastAtc = messages
            .lastWhere((m) => m['role'] == 'atc', orElse: () => {});
        final reply = lastAtc['content'];
        if (reply != null && reply.isNotEmpty) {
          await _voice.speakAtcResponse(reply);
        }
      }
    }
    _scrollToBottom();
  }

  Future<void> _handleHint() async {
    await ref.read(rtPracticeProvider.notifier).requestHint();
    _scrollToBottom();
  }

  Future<void> _handleNewScenario(RtScenario scenario) async {
    final notifier = ref.read(rtPracticeProvider.notifier);

    // Check free tier before starting
    if (!await notifier.canStartNewScenario()) {
      if (!mounted) return;
      await showPremiumPaywall(context, source: 'rt_practice_scenario_limit');
      return;
    }

    await _voice.stopSpeaking();
    // startScenario internally saves the current session before clearing it.
    notifier.startScenario(scenario);
    if (mounted) setState(() => _showHistory = false);
    _scrollToBottom();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) _voice.stopSpeaking();
  }

  Future<void> _toggleListening() async {
    if (_voice.isListening) {
      await _voice.stopListening();
    } else {
      await _voice.startListening((text) {
        if (mounted) {
          setState(() {
            _controller.text = text;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: text.length),
            );
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtState = ref.watch(rtPracticeProvider);
    final isPremium = ref.watch(premiumStatusProvider).valueOrNull ?? false;
    final atLimit = !isPremium &&
        rtState.scenariosUsedThisSession >= kRtPracticeFreeScenarios;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.headset_mic_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'RT Practice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        automaticallyImplyLeading: true,
        actions: [
          // Hint button
          if (rtState.messages.isNotEmpty && !rtState.isLoading)
            TextButton.icon(
              onPressed: _handleHint,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
              label: const Text('Hint'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
              ),
            ),
          // History toggle
          IconButton(
            onPressed: () => setState(() {
              _showHistory = !_showHistory;
              if (_showHistory) _showTranscript = false;
            }),
            icon: Icon(
              _showHistory
                  ? Icons.bar_chart_rounded
                  : Icons.bar_chart_rounded,
              size: 22,
              color: _showHistory ? AppColors.primary : null,
            ),
            tooltip: _showHistory ? 'Hide history' : 'Score history',
          ),
          // Transcript toggle
          IconButton(
            onPressed: () => setState(() {
              _showTranscript = !_showTranscript;
              if (_showTranscript) _showHistory = false;
            }),
            icon: Icon(
              _showTranscript
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 22,
            ),
            tooltip: _showTranscript ? 'Hide transcript' : 'Show transcript',
          ),
          // Mute/unmute TTS — only shown when TTS is available
          if (_voice.ttsReady)
            IconButton(
              onPressed: _toggleMute,
              icon: Icon(
                _muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                size: 22,
              ),
              tooltip: _muted ? 'Unmute ATC voice' : 'Mute ATC voice',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Scenario selector ──────────────────────────────────────────
          _ScenarioSelector(
            selected: rtState.currentScenario,
            onSelected: _handleNewScenario,
            atLimit: atLimit,
          ),

          // ── TTS speed control (only when TTS is available) ─────────────
          if (_voice.ttsReady)
            _TtsSpeedBar(
              current: _ttsSpeed,
              onSelect: _setTtsSpeed,
              slow: _kSpeedSlow,
              normal: _kSpeedNormal,
              fast: _kSpeedFast,
            ),

          // ── Radio display / transcript / history ──────────────────────
          Expanded(
            child: _showHistory
                ? _ScoreHistoryPanel(
                    scenario: rtState.currentScenario,
                    onNewSession: () => setState(() => _showHistory = false),
                  )
                : _showTranscript
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: rtState.messages.isEmpty
                            ? _EmptyState(scenario: rtState.currentScenario)
                            : ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                itemCount: rtState.messages.length +
                                    (rtState.isLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == rtState.messages.length &&
                                      rtState.isLoading) {
                                    return const _TypingIndicator();
                                  }
                                  return _MessageBubble(
                                    message: rtState.messages[index],
                                    onReplay: (text) {
                                      if (!_muted) _voice.speakAtcResponse(text);
                                    },
                                  );
                                },
                              ),
                      )
                    : _RadioDisplay(
                        voice: _voice,
                        rtState: rtState,
                        scenario: rtState.currentScenario,
                      ),
          ),

          // ── Paywall banner ─────────────────────────────────────────────
          if (atLimit) _PaywallBanner(context: context),

          // ── PTT / text input ───────────────────────────────────────────
          if (!_showHistory)
            if (_showTranscript)
              _InputBar(
                controller: _controller,
                isLoading: rtState.isLoading,
                disabled: atLimit,
                onSend: _handleSend,
                voiceService: _voice,
                onMicToggle: _toggleListening,
              )
            else
              _PttBar(
                isListening: _voice.isListening,
                isSpeaking: _voice.isSpeaking,
                isLoading: rtState.isLoading,
                disabled: atLimit,
                onTap: _toggleListening,
              ),

          // ── ATIS link ─────────────────────────────────────────────────
          _AtisLink(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scenario selector
// ---------------------------------------------------------------------------

class _ScenarioSelector extends StatelessWidget {
  final RtScenario selected;
  final ValueChanged<RtScenario> onSelected;
  final bool atLimit;

  const _ScenarioSelector({
    required this.selected,
    required this.onSelected,
    required this.atLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: RtScenario.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final scenario = RtScenario.values[index];
          final isSelected = scenario == selected;
          return ChoiceChip(
            label: Text(scenario.displayName),
            selected: isSelected,
            onSelected: (_) => onSelected(scenario),
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.onSurface,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: isSelected ? 1.5 : 0.5,
            ),
            backgroundColor: AppColors.surfaceVariant,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final RtScenario scenario;
  const _EmptyState({required this.scenario});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.headset_mic_rounded,
      title: scenario.displayName,
      subtitle:
          'Type your first radio call below. ATC will respond and guide you through the scenario.',
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final Map<String, String> message;

  /// Called when the replay speaker button is tapped on an ATC bubble.
  final void Function(String text)? onReplay;

  const _MessageBubble({required this.message, this.onReplay});

  @override
  Widget build(BuildContext context) {
    final role = message['role'] ?? 'atc';
    final content = message['content'] ?? '';
    final isStudent = role == 'student';
    final isHint = role == 'hint';

    if (isHint) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.warning,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  content,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isStudent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isStudent) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.headset_mic_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isStudent
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isStudent ? 16 : 4),
                  bottomRight: Radius.circular(isStudent ? 4 : 16),
                ),
                border: isStudent
                    ? null
                    : Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isStudent)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'ATC',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Replay speaker icon — only for ATC messages
                        if (onReplay != null)
                          GestureDetector(
                            onTap: () => onReplay!(content),
                            child: Icon(
                              Icons.volume_up_rounded,
                              size: 14,
                              color: AppColors.primary.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  SelectableText(
                    content,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  // Score chips for ATC responses that carry feedback
                  if (!isStudent && !isHint) ...[
                    Builder(builder: (context) {
                      final ps = message['score_phrasing'];
                      final rs = message['score_readback'];
                      final fs = message['score_format'];
                      if (ps == null || rs == null || fs == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            _ScoreChip(label: 'Phrasing', score: int.tryParse(ps) ?? 0),
                            _ScoreChip(label: 'Readback', score: int.tryParse(rs) ?? 0),
                            _ScoreChip(label: 'Format', score: int.tryParse(fs) ?? 0),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          if (isStudent) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int score;

  const _ScoreChip({required this.label, required this.score});

  Color get _color {
    if (score >= 4) return AppColors.success;
    if (score >= 3) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label $score/5',
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator — identical to ask_ai_screen.dart
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
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
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
                    final opacity = 0.3 +
                        0.7 *
                            (1.0 - (offset - 0.5).abs() * 2).clamp(0.0, 1.0);
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

// ---------------------------------------------------------------------------
// Paywall banner
// ---------------------------------------------------------------------------

class _PaywallBanner extends StatelessWidget {
  final BuildContext context;
  const _PaywallBanner({required this.context});

  @override
  Widget build(BuildContext _) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You\'ve used your 5 free scenarios. Upgrade to continue.',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                showPremiumPaywall(context, source: 'rt_practice_banner'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar (with mic button + listening animation)
// ---------------------------------------------------------------------------

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onSend;
  final VoiceService voiceService;
  final VoidCallback onMicToggle;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.disabled,
    required this.onSend,
    required this.voiceService,
    required this.onMicToggle,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    widget.voiceService.addListener(_onVoiceChanged);
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    if (widget.voiceService.isListening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.voiceService.removeListener(_onVoiceChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.voiceService.isListening;
    final sttAvailable = widget.voiceService.sttReady;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        12,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Mic button (only when STT is available and not disabled) ──
          if (sttAvailable && !widget.disabled) ...[
            _MicButton(
              isListening: isListening,
              pulseAnimation: _pulseAnimation,
              onTap: widget.onMicToggle,
            ),
            const SizedBox(width: 8),
          ],

          // ── Text field ─────────────────────────────────────────────────
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: isListening
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    )
                  : null,
              child: TextField(
                controller: widget.controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!widget.isLoading && !widget.disabled) widget.onSend();
                },
                enabled: !widget.disabled,
                maxLength: 2000,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(color: AppColors.onSurface, fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.disabled
                      ? 'Upgrade to continue practising...'
                      : isListening
                          ? 'Listening...'
                          : 'Type your radio call...',
                  hintStyle: TextStyle(
                    color: isListening
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : AppColors.onSurfaceVariant,
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
          ),

          const SizedBox(width: 8),

          // ── Send button ────────────────────────────────────────────────
          Material(
            color: (widget.isLoading || widget.disabled)
                ? AppColors.surfaceVariant
                : AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: (widget.isLoading || widget.disabled) ? null : widget.onSend,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: (widget.isLoading || widget.disabled)
                      ? AppColors.onSurfaceVariant
                      : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mic button — shows pulse animation while listening
// ---------------------------------------------------------------------------

class _MicButton extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _MicButton({
    required this.isListening,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isListening ? 'Stop voice input' : 'Start voice input',
      child: GestureDetector(
        onTap: onTap,
        // Pad to 48dp tap target while keeping the visible button at 44dp.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isListening ? pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isListening
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                  border: isListening
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color:
                      isListening ? AppColors.primary : AppColors.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TTS speed bar — Slow / Normal / Fast preset chips
// ---------------------------------------------------------------------------

class _TtsSpeedBar extends StatelessWidget {
  final double current;
  final ValueChanged<double> onSelect;
  final double slow;
  final double normal;
  final double fast;

  const _TtsSpeedBar({
    required this.current,
    required this.onSelect,
    required this.slow,
    required this.normal,
    required this.fast,
  });

  @override
  Widget build(BuildContext context) {
    final presets = [
      (label: 'Slow', value: slow),
      (label: 'Normal', value: normal),
      (label: 'Fast', value: fast),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.speed_rounded,
            size: 14,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'ATC speed',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          ...presets.map((p) {
            final isSelected = current == p.value;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(p.label),
                selected: isSelected,
                onSelected: (_) => onSelect(p.value),
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: isSelected ? 1.5 : 0.5,
                ),
                backgroundColor: AppColors.surfaceVariant,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Radio display — shown instead of transcript during active session
// ---------------------------------------------------------------------------

class _RadioDisplay extends StatelessWidget {
  final VoiceService voice;
  final dynamic rtState;
  final RtScenario scenario;

  const _RadioDisplay({
    required this.voice,
    required this.rtState,
    required this.scenario,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSpeaking = voice.isSpeaking;
    final bool isListening = voice.isListening;
    final bool isLoading = rtState.isLoading as bool;
    final bool hasMessages = (rtState.messages as List).isNotEmpty;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isSpeaking) {
      statusText = 'ATC Transmitting...';
      statusIcon = Icons.radio_rounded;
      statusColor = AppColors.primary;
    } else if (isListening) {
      statusText = 'Transmitting...';
      statusIcon = Icons.mic_rounded;
      statusColor = AppColors.error;
    } else if (isLoading) {
      statusText = 'Awaiting response...';
      statusIcon = Icons.hourglass_top_rounded;
      statusColor = AppColors.onSurfaceVariant;
    } else if (!hasMessages) {
      statusText = 'Press PTT to begin';
      statusIcon = Icons.radio_outlined;
      statusColor = AppColors.onSurfaceVariant;
    } else {
      statusText = 'Press PTT to transmit';
      statusIcon = Icons.mic_none_rounded;
      statusColor = AppColors.onSurfaceVariant;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: statusColor,
                    ),
                  )
                : Icon(statusIcon, size: 36, color: statusColor),
          ),
          const SizedBox(height: 20),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scenario.displayName,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PTT bar — push-to-talk button shown in radio (non-transcript) mode
// ---------------------------------------------------------------------------

class _PttBar extends StatelessWidget {
  final bool isListening;
  final bool isSpeaking;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onTap;

  const _PttBar({
    required this.isListening,
    required this.isSpeaking,
    required this.isLoading,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool canTransmit = !isSpeaking && !isLoading && !disabled;
    final Color btnColor = isListening
        ? AppColors.error
        : canTransmit
            ? AppColors.primary
            : AppColors.onSurfaceVariant.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: canTransmit || isListening ? onTap : null,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: btnColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isListening
                ? 'Tap to stop'
                : isSpeaking
                    ? 'ATC talking...'
                    : 'PTT',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score history panel
// ---------------------------------------------------------------------------

class _ScoreHistoryPanel extends StatefulWidget {
  final RtScenario scenario;
  final VoidCallback onNewSession;

  const _ScoreHistoryPanel({
    required this.scenario,
    required this.onNewSession,
  });

  @override
  State<_ScoreHistoryPanel> createState() => _ScoreHistoryPanelState();
}

class _ScoreHistoryPanelState extends State<_ScoreHistoryPanel> {
  List<RtSessionRecord>? _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ScoreHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scenario != widget.scenario) _load();
  }

  Future<void> _load() async {
    final history = await loadRtHistory(widget.scenario);
    if (mounted) setState(() => _history = history);
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            widget.scenario.displayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Score history — last $kMaxRtHistory sessions',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),

        // Session list or empty state
        Expanded(
          child: history == null
              ? const Center(child: CircularProgressIndicator())
              : history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No completed sessions yet for this scenario.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: history.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        // Show most recent first
                        final record =
                            history[history.length - 1 - index];
                        return _HistoryRow(
                          record: record,
                          sessionNumber: history.length - index,
                        );
                      },
                    ),
        ),

        // New Session button
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: widget.onNewSession,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'New Session',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final RtSessionRecord record;
  final int sessionNumber;

  const _HistoryRow({required this.record, required this.sessionNumber});

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${record.date.day.toString().padLeft(2, '0')}/'
        '${record.date.month.toString().padLeft(2, '0')}/'
        '${record.date.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Session number + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session $sessionNumber',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Score badges
          Wrap(
            spacing: 6,
            children: [
              _HistoryScoreBadge(
                label: 'Phrasing',
                score: record.phrasing,
              ),
              _HistoryScoreBadge(
                label: 'Readback',
                score: record.readback,
              ),
              _HistoryScoreBadge(
                label: 'Format',
                score: record.format,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryScoreBadge extends StatelessWidget {
  final String label;
  final double score;

  const _HistoryScoreBadge({required this.label, required this.score});

  Color get _color {
    if (score >= 4) return AppColors.success;
    if (score >= 3) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final display = score.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label $display',
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick links footer — ATIS + CAP 413 readbacks
// ---------------------------------------------------------------------------

class _AtisLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => context.push('/learn/atis'),
            icon: const Icon(Icons.radio_rounded, size: 16),
            label: const Text('Practice ATIS'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: AppColors.divider,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          TextButton.icon(
            onPressed: () => context.push('/learn/mandatory-readback'),
            icon: const Icon(Icons.checklist_rounded, size: 16),
            label: const Text('CAP 413 Readbacks'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
