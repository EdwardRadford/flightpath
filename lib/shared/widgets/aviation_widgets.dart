// Aviation-themed UI components — premium design elements that give the app
// a tasteful aviation personality without being gimmicky.
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// 1. Runway Progress Indicator
// ---------------------------------------------------------------------------

/// A progress bar styled like a runway — grey background with white centre-line
/// dashes, orange fill for progress.
class RunwayProgressIndicator extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final String? semanticLabel;

  const RunwayProgressIndicator({
    super.key,
    required this.value,
    this.height = 8,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;
    final dashColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    return Semantics(
      label: semanticLabel ?? 'Progress: ${(value * 100).round()} percent',
      value: '${(value * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _RunwayPainter(
                progress: value.clamp(0.0, 1.0),
                trackColor: trackColor,
                dashColor: dashColor,
                fillColor: AppColors.primary,
                barHeight: height,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunwayPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color dashColor;
  final Color fillColor;
  final double barHeight;

  _RunwayPainter({
    required this.progress,
    required this.trackColor,
    required this.dashColor,
    required this.fillColor,
    required this.barHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = trackColor;
    final fillPaint = Paint()..color = fillColor;
    final dashPaint = Paint()
      ..color = dashColor
      ..strokeWidth = 1.5;

    // Track
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), trackPaint);

    // Centre-line dashes
    final centerY = size.height / 2;
    const dashWidth = 6.0;
    const gapWidth = 4.0;
    double x = 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, centerY),
        Offset(min(x + dashWidth, size.width), centerY),
        dashPaint,
      );
      x += dashWidth + gapWidth;
    }

    // Progress fill
    final fillWidth = size.width * progress;
    if (fillWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fillWidth, size.height),
          Radius.circular(barHeight / 2),
        ),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RunwayPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ---------------------------------------------------------------------------
// 2. Dashed Divider (Flight Route Line)
// ---------------------------------------------------------------------------

/// A dashed line divider styled like a flight route on a chart.
class DashedDivider extends StatelessWidget {
  final Color? color;
  final double dashWidth;
  final double gapWidth;
  final double strokeWidth;

  const DashedDivider({
    super.key,
    this.color,
    this.dashWidth = 5,
    this.gapWidth = 4,
    this.strokeWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.outline;
    return ExcludeSemantics(
      child: SizedBox(
        height: strokeWidth,
        width: double.infinity,
        child: CustomPaint(
          painter: _DashedLinePainter(
            color: c,
            dashWidth: dashWidth,
            gapWidth: gapWidth,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double gapWidth;
  final double strokeWidth;

  _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.gapWidth,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(min(x + dashWidth, size.width), size.height / 2),
        paint,
      );
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// 3. Stats Card with Top Accent Bar (Instrument Gauge Style)
// ---------------------------------------------------------------------------

/// A card with a coloured top accent bar reminiscent of cockpit instrument
/// gauges. Used for stats and metrics.
class AccentStatsCard extends StatelessWidget {
  final Color accentColor;
  final String label;
  final String value;
  final IconData? icon;
  final Widget? child;

  const AccentStatsCard({
    super.key,
    this.accentColor = AppColors.primary,
    required this.label,
    required this.value,
    this.icon,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;
    final subtextColor = isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight;
    final borderColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Semantics(
      label: '$label: $value',
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent bar (decorative)
            ExcludeSemantics(
              child: Container(
                height: 3,
                width: double.infinity,
                color: accentColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: child ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: accentColor, size: 22),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
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

// ---------------------------------------------------------------------------
// 4. Instrument Bezel Empty State Icon
// ---------------------------------------------------------------------------

/// An icon with a circular gradient background resembling a cockpit instrument
/// bezel. Used in empty states.
class InstrumentBezelIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? iconColor;

  const InstrumentBezelIcon({
    super.key,
    required this.icon,
    this.size = 80,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isDark
              ? [
                  AppColors.surfaceVariantDark,
                  AppColors.surfaceDark,
                ]
              : [
                  AppColors.surfaceVariantLight,
                  AppColors.backgroundLight,
                ],
          stops: const [0.4, 1.0],
        ),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.15),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: iconColor ?? AppColors.primary,
        size: size * 0.45,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Premium Flight Path Card (replacement for plain Container cards)
// ---------------------------------------------------------------------------

/// A premium-styled card with rounded corners, subtle border, and consistent
/// internal padding. Use instead of bare Container + BoxDecoration.
class FlightPathCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  const FlightPathCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final defaultBorder = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    Widget card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? defaultBorder,
          width: 0.5,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ---------------------------------------------------------------------------
// 6. Pressable Card Wrapper (subtle scale-down on press)
// ---------------------------------------------------------------------------

/// Wraps a child in a gesture detector that scales it to 0.98 on press.
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressableCard({super.key, required this.child, this.onTap});

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Section Header with Aviation Icon
// ---------------------------------------------------------------------------

/// Section header with an optional small aviation icon next to the title.
class AviationSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const AviationSectionHeader({
    super.key,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
