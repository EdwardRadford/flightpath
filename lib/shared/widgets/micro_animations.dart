// Micro-animation widgets — meaningful animations that add polish and
// personality to the Flight Path app.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Animated Check Button
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
// Counting Number Animation
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
