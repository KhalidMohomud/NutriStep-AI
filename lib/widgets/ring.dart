import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular progress ring with content in the middle — calories and macros.
class Ring extends StatelessWidget {
  const Ring({
    super.key,
    required this.size,
    required this.stroke,
    required this.progress,
    this.color = AppColors.ink,
    this.track = AppColors.track,
    this.gradient,
    this.child,
  });

  final double size;
  final double stroke;
  final double progress; // 0..1, clamped; NaN (0/0 target) counts as 0
  final Color color;
  final Color track;

  /// Colours swept along the arc, start → end; overrides [color].
  final List<Color>? gradient;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          stroke: stroke,
          progress: p,
          color: color,
          track: track,
          gradient: gradient,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.stroke,
    required this.progress,
    required this.color,
    required this.track,
    this.gradient,
  });

  final double stroke;
  final double progress;
  final Color color;
  final Color track;
  final List<Color>? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawOval(arc, paint..color = track);
    if (progress > 0) {
      final colors = gradient;
      if (colors != null) {
        // sweep from 12 o'clock over just the filled part, so a short arc still shows both ends
        paint.shader = SweepGradient(
          colors: colors,
          endAngle: 2 * pi * progress,
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect);
      }
      canvas.drawArc(
        arc,
        -pi / 2,
        2 * pi * progress,
        false,
        paint
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.gradient != gradient ||
      old.track != track ||
      old.stroke != stroke;
}
