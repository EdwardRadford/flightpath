import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/coach_mark_step.dart';

/// Full-screen overlay that walks the user through a series of [CoachMarkStep]s,
/// highlighting each target widget with a spotlight cutout and tooltip card.
///
/// Usage:
/// ```dart
/// CoachMarkOverlay.show(
///   context: context,
///   steps: steps,
///   onComplete: () { /* mark complete */ },
///   onSkip: () { /* mark complete */ },
/// );
/// ```
class CoachMarkOverlay extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final OverlayEntry _entry;

  const CoachMarkOverlay._({
    required this.steps,
    required this.onComplete,
    required this.onSkip,
    required OverlayEntry entry,
  }) : _entry = entry;

  /// Insert a coach-mark overlay into the nearest [Overlay].
  static void show({
    required BuildContext context,
    required List<CoachMarkStep> steps,
    required VoidCallback onComplete,
    required VoidCallback onSkip,
  }) {
    if (steps.isEmpty) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CoachMarkOverlay._(
        steps: steps,
        onComplete: onComplete,
        onSkip: onSkip,
        entry: entry,
      ),
    );

    Overlay.of(context).insert(entry);
  }

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────
  int _currentStep = 0;
  Rect _targetRect = Rect.zero;

  // ── Animation controllers ──────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _cutoutController;
  late Animation<Rect?> _cutoutAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ── Tween tracking ─────────────────────────────────────────────────────
  Rect _previousRect = Rect.zero;

  @override
  void initState() {
    super.initState();

    // Fade in the entire overlay.
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Animate the cutout rectangle between steps.
    _cutoutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _cutoutAnimation = RectTween(begin: Rect.zero, end: Rect.zero).animate(
      CurvedAnimation(parent: _cutoutController, curve: Curves.easeOutCubic),
    );

    // Pulsing glow ring.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _logEvent('walkthrough_started');
    _showStep(0, initialLoad: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _cutoutController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Step lifecycle ─────────────────────────────────────────────────────

  Future<void> _showStep(int index, {bool initialLoad = false}) async {
    final step = widget.steps[index];

    // Ensure the target is visible if it lives inside a scrollable.
    if (step.targetKey.currentContext != null) {
      await Scrollable.ensureVisible(
        step.targetKey.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
      );
      // Allow the scroll + layout pass to settle before measuring.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
    }

    final newRect = _getTargetRect(step.targetKey);

    if (initialLoad) {
      _previousRect = newRect;
      _targetRect = newRect;
      _cutoutController.value = 1.0;
      _fadeController.forward();
    } else {
      _previousRect = _targetRect;
      _cutoutAnimation = RectTween(begin: _previousRect, end: newRect).animate(
        CurvedAnimation(parent: _cutoutController, curve: Curves.easeOutCubic),
      );
      _cutoutController.forward(from: 0);
    }

    setState(() {
      _currentStep = index;
      _targetRect = newRect;
    });

    _logEvent('walkthrough_step_viewed', params: {
      'step_index': index,
      'step_name': step.title,
    });
  }

  // ── Measuring helpers ──────────────────────────────────────────────────

  static Rect _getTargetRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Rect.zero;
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      _showStep(_currentStep + 1);
    } else {
      _finish();
    }
  }

  void _finish() {
    _logEvent('walkthrough_completed', params: {
      'steps_viewed': _currentStep + 1,
    });
    _removeOverlay();
    widget.onComplete();
  }

  void _skip() {
    _logEvent('walkthrough_skipped', params: {
      'skipped_at_step': _currentStep,
    });
    _removeOverlay();
    widget.onSkip();
  }

  void _removeOverlay() {
    _fadeController.reverse().then((_) {
      widget._entry.remove();
    });
  }

  // ── Analytics ──────────────────────────────────────────────────────────

  void _logEvent(String name, {Map<String, Object>? params}) {
    FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
  }

  // ── Tooltip positioning ────────────────────────────────────────────────

  bool _shouldPlaceBelow(Rect target, Size screenSize, TooltipPosition pref) {
    if (pref == TooltipPosition.below) return true;
    if (pref == TooltipPosition.above) return false;
    // auto — place below when target is in the upper half of the screen.
    return target.center.dy < screenSize.height / 2;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: Listenable.merge([_cutoutController, _pulseController]),
          builder: (context, _) {
            // Interpolate rect during cutout animation.
            final animatedRect =
                _cutoutController.isAnimating || _cutoutController.value < 1.0
                    ? (_cutoutAnimation.value ?? _targetRect)
                    : _targetRect;

            final below =
                _shouldPlaceBelow(animatedRect, screenSize, step.position);

            return Stack(
              children: [
                // ── Dark overlay with cutout ──────────────────────────
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      targetRect: animatedRect,
                      pulseValue: _pulseAnimation.value,
                    ),
                  ),
                ),

                // ── Tap outside to dismiss ───────────────────────────
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _next,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),

                // ── Tooltip card ─────────────────────────────────────
                _buildTooltip(
                  step: step,
                  targetRect: animatedRect,
                  below: below,
                  screenSize: screenSize,
                  isLast: isLast,
                  isDark: isDark,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTooltip({
    required CoachMarkStep step,
    required Rect targetRect,
    required bool below,
    required Size screenSize,
    required bool isLast,
    required bool isDark,
  }) {
    const padding = 8.0;
    const tooltipGap = 12.0;
    const horizontalMargin = 16.0;

    final double top;
    if (below) {
      top = targetRect.bottom + padding + tooltipGap;
    } else {
      // Will be positioned with a bottom constraint instead.
      top = 0;
    }

    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor =
        isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;

    return Positioned(
      left: horizontalMargin,
      right: horizontalMargin,
      top: below ? top : null,
      bottom: below
          ? null
          : screenSize.height - targetRect.top + padding + tooltipGap,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                step.description,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // Dot indicators + buttons
              Row(
                children: [
                  // Dots
                  ...List.generate(widget.steps.length, (i) {
                    final isActive = i == _currentStep;
                    return Container(
                      width: isActive ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                  const Spacer(),

                  // Skip
                  TextButton(
                    onPressed: _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: textColor.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),

                  // Next / Got it
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(isLast ? 'Got it!' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom painter — dark overlay with spotlight cutout ────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double pulseValue;

  static const double _padding = 8.0;
  static const double _borderRadius = 8.0;

  _SpotlightPainter({
    required this.targetRect,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Dark scrim with cutout ─────────────────────────────────────────
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fullPath = Path()..addRect(fullRect);

    final cutoutRRect = RRect.fromRectAndRadius(
      targetRect.inflate(_padding),
      const Radius.circular(_borderRadius),
    );
    final cutoutPath = Path()..addRRect(cutoutRRect);

    final overlayPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cutoutPath,
    );

    canvas.drawPath(
      overlayPath,
      Paint()..color = const Color(0xBF000000),
    );

    // ── Static border around the cutout ──────────────────────────────────
    canvas.drawRRect(
      cutoutRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = AppColors.primary.withValues(alpha: 0.6),
    );

    // ── Pulsing glow ring ────────────────────────────────────────────────
    final glowOpacity = 0.15 + (0.25 * pulseValue);
    final glowSpread = 4.0 + (6.0 * pulseValue);

    canvas.drawRRect(
      cutoutRRect.inflate(glowSpread),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = AppColors.primary.withValues(alpha: glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      pulseValue != oldDelegate.pulseValue;
}
