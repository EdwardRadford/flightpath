// Simple sparkline widget for rating history.
// Shows a line graph of past ratings, equally spaced horizontally.
// Color: AppColors.primary. Dot at the last point.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';

class RatingSparkline extends StatelessWidget {
  /// Rating history values — should have at least 2 entries.
  final List<num> ratings;

  const RatingSparkline({super.key, required this.ratings});

  @override
  Widget build(BuildContext context) {
    if (ratings.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 60,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(ratings: ratings),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<num> ratings;

  const _SparklinePainter({required this.ratings});

  @override
  void paint(Canvas canvas, Size size) {
    if (ratings.length < 2) return;

    final minVal = ratings.reduce((a, b) => a < b ? a : b).toDouble();
    final maxVal = ratings.reduce((a, b) => a > b ? a : b).toDouble();
    final range = maxVal - minVal;

    // Avoid division by zero when all values are the same.
    final effectiveRange = range == 0 ? 1.0 : range;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    // Vertical inset so the dot isn't clipped at the edge.
    const verticalPadding = 6.0;
    final drawHeight = size.height - verticalPadding * 2;

    Offset toOffset(int index) {
      final x = size.width * index / (ratings.length - 1);
      final normalized = (ratings[index].toDouble() - minVal) / effectiveRange;
      // Flip: high rating → top of canvas.
      final y = verticalPadding + drawHeight * (1 - normalized);
      return Offset(x, y);
    }

    final path = Path();
    path.moveTo(toOffset(0).dx, toOffset(0).dy);
    for (int i = 1; i < ratings.length; i++) {
      path.lineTo(toOffset(i).dx, toOffset(i).dy);
    }
    canvas.drawPath(path, linePaint);

    // Dot at last point.
    final last = toOffset(ratings.length - 1);
    canvas.drawCircle(last, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.ratings != ratings;
}
