// Micro-animation widgets — meaningful animations that add polish and
// personality to the Flight Path app.
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// 1. Quiz Completion Animation
// ---------------------------------------------------------------------------

/// Shows a celebration animation after quiz completion. Draws a checkmark
/// for passing scores or a subtle "try again" prompt for low scores.
/// Includes confetti-like particles for high scores (>= 80%).
class QuizCompletionAnimation extends StatefulWidget {
  final bool passed;
  final int scorePercent;
  final VoidCallback? onComplete;

  const QuizCompletionAnimation({
    super.key,
    required this.passed,
    required this.scorePercent,
    this.onComplete,
  });

  @override
  State<QuizCompletionAnimation> createState() =>
      _QuizCompletionAnimationState();
}

class _QuizCompletionAnimationState extends State<QuizCompletionAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _confettiController;
  late final Animation<double> _checkProgress;
  late final Animation<double> _scaleAnimation;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _checkProgress = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // Generate confetti particles for high scores
    final rng = Random();
    _particles = List.generate(
      widget.scorePercent >= 80 ? 20 : 0,
      (_) => _ConfettiParticle(
        x: rng.nextDouble(),
        speed: 0.5 + rng.nextDouble() * 0.5,
        angle: rng.nextDouble() * 2 * pi,
        size: 4 + rng.nextDouble() * 4,
        color: [
          AppColors.primary,
          AppColors.primaryBright,
          AppColors.success,
          AppColors.warning,
          const Color(0xFF64B5F6),
        ][rng.nextInt(5)],
      ),
    );

    _checkController.forward();
    if (_particles.isNotEmpty) {
      _confettiController.forward();
    }

    _checkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onComplete?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: _AnimBuilder(
        listenable: Listenable.merge([_checkController, _confettiController]),
        builder: (context, _) {
          return CustomPaint(
            painter: _CompletionPainter(
              passed: widget.passed,
              checkProgress: _checkProgress.value,
              scale: _scaleAnimation.value,
              confettiProgress: _confettiController.value,
              particles: _particles,
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double speed;
  final double angle;
  final double size;
  final Color color;

  _ConfettiParticle({
    required this.x,
    required this.speed,
    required this.angle,
    required this.size,
    required this.color,
  });
}

class _CompletionPainter extends CustomPainter {
  final bool passed;
  final double checkProgress;
  final double scale;
  final double confettiProgress;
  final List<_ConfettiParticle> particles;

  _CompletionPainter({
    required this.passed,
    required this.checkProgress,
    required this.scale,
    required this.confettiProgress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * scale;

    if (scale > 0) {
      // Circle background
      final bgPaint = Paint()
        ..color = (passed ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.15);
      canvas.drawCircle(center, radius, bgPaint);

      // Circle border
      final borderPaint = Paint()
        ..color = passed ? AppColors.success : AppColors.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius, borderPaint);

      // Check or X mark
      if (checkProgress > 0) {
        final iconPaint = Paint()
          ..color = passed ? AppColors.success : AppColors.error
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;

        if (passed) {
          _drawCheck(canvas, center, radius * 0.45, checkProgress, iconPaint);
        } else {
          _drawX(canvas, center, radius * 0.35, checkProgress, iconPaint);
        }
      }
    }

    // Confetti particles
    for (final p in particles) {
      final progress = confettiProgress * p.speed;
      final dist = 60 * progress;
      final px = center.dx + cos(p.angle) * dist * (0.5 + p.x);
      final py = center.dy + sin(p.angle) * dist * (0.5 + p.x) -
          20 * progress;
      final opacity = (1.0 - confettiProgress).clamp(0.0, 1.0);

      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(px, py), p.size * (1 - confettiProgress * 0.5), paint);
    }
  }

  void _drawCheck(Canvas canvas, Offset center, double size,
      double progress, Paint paint) {
    final path = Path();
    final startX = center.dx - size * 0.6;
    final startY = center.dy + size * 0.1;
    final midX = center.dx - size * 0.1;
    final midY = center.dy + size * 0.6;
    final endX = center.dx + size * 0.7;
    final endY = center.dy - size * 0.4;

    if (progress <= 0.5) {
      final t = progress * 2;
      path.moveTo(startX, startY);
      path.lineTo(
        startX + (midX - startX) * t,
        startY + (midY - startY) * t,
      );
    } else {
      final t = (progress - 0.5) * 2;
      path.moveTo(startX, startY);
      path.lineTo(midX, midY);
      path.lineTo(
        midX + (endX - midX) * t,
        midY + (endY - midY) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  void _drawX(Canvas canvas, Offset center, double size,
      double progress, Paint paint) {
    if (progress <= 0.5) {
      final t = progress * 2;
      canvas.drawLine(
        Offset(center.dx - size, center.dy - size),
        Offset(
          center.dx - size + 2 * size * t,
          center.dy - size + 2 * size * t,
        ),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(center.dx - size, center.dy - size),
        Offset(center.dx + size, center.dy + size),
        paint,
      );
      final t = (progress - 0.5) * 2;
      canvas.drawLine(
        Offset(center.dx + size, center.dy - size),
        Offset(
          center.dx + size - 2 * size * t,
          center.dy - size + 2 * size * t,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CompletionPainter old) =>
      old.checkProgress != checkProgress ||
      old.scale != scale ||
      old.confettiProgress != confettiProgress;
}

// ---------------------------------------------------------------------------
// 2. Animated Check Button
// ---------------------------------------------------------------------------

/// A button that briefly shows a checkmark before calling [onComplete].
/// Used for "I'm Ready", "Save", "Mark as Complete" type actions.
class AnimatedCheckButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onComplete;
  final Color? backgroundColor;

  const AnimatedCheckButton({
    super.key,
    required this.label,
    this.icon,
    required this.onComplete,
    this.backgroundColor,
  });

  @override
  State<AnimatedCheckButton> createState() => _AnimatedCheckButtonState();
}

class _AnimatedCheckButtonState extends State<AnimatedCheckButton>
    with SingleTickerProviderStateMixin {
  bool _showCheck = false;

  void _handleTap() {
    setState(() => _showCheck = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showCheck = false);
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showCheck ? null : _handleTap,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: child,
          ),
          child: _showCheck
              ? const Icon(Icons.check_rounded, key: ValueKey('check'))
              : (widget.icon != null
                  ? Icon(widget.icon, key: const ValueKey('icon'))
                  : const SizedBox.shrink(key: ValueKey('none'))),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _showCheck ? 'Done!' : widget.label,
            key: ValueKey(_showCheck),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _showCheck
              ? AppColors.success
              : (widget.backgroundColor ?? AppColors.primaryBright),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Counting Number Animation
// ---------------------------------------------------------------------------

/// Animates a number counting up from 0 to [value] when first displayed.
class CountingNumber extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final String? suffix;
  final Duration duration;

  const CountingNumber({
    super.key,
    required this.value,
    this.style,
    this.suffix,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<CountingNumber> createState() => _CountingNumberState();
}

class _CountingNumberState extends State<CountingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AnimBuilder(
      listenable: _animation,
      builder: (context, _) {
        final current = (_animation.value * widget.value).round();
        return Text(
          '$current${widget.suffix ?? ''}',
          style: widget.style,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: _AnimBuilder compatible with AnimatedWidget
// ---------------------------------------------------------------------------

class _AnimBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const _AnimBuilder({
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
