import 'dart:math';
import 'package:flutter/material.dart';

/// Circular arc speed gauge (0 – [maxValue]).
class SpeedGauge extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final double size;

  const SpeedGauge({
    super.key,
    required this.value,
    this.maxValue = 1000,
    required this.label,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 18,
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _GaugePainter(
                value: value.clamp(0, maxValue),
                maxValue: maxValue,
              ),
              child: Center(
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE0E6FF),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7DB3),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;

  _GaugePainter({required this.value, required this.maxValue});

  static const _startAngle = 135.0; // degrees
  static const _sweepAngle = 270.0; // degrees

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final startRad = _startAngle * pi / 180;
    final sweepRad = _sweepAngle * pi / 180;
    final fraction = (value / maxValue).clamp(0.0, 1.0);
    final valueSweep = sweepRad * fraction;

    // Background arc
    canvas.drawArc(
      rect,
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = const Color(0xFF1A1F45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Value arc with gradient
    if (fraction > 0.001) {
      final gradientColors = fraction < 0.5
          ? [const Color(0xFF00E676), const Color(0xFF00D4FF)]
          : fraction < 0.8
              ? [const Color(0xFF00D4FF), const Color(0xFFFF9100)]
              : [const Color(0xFFFF9100), const Color(0xFFFF1744)];

      final gradient = SweepGradient(
        startAngle: startRad,
        endAngle: startRad + valueSweep,
        colors: gradientColors,
      );

      canvas.drawArc(
        rect,
        startRad,
        valueSweep,
        false,
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );

      // Glow at the tip
      final tipAngle = startRad + valueSweep;
      final tipPos = center +
          Offset(radius * cos(tipAngle), radius * sin(tipAngle));
      canvas.drawCircle(
        tipPos,
        6,
        Paint()
          ..color = gradientColors.last.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Tick marks
    final tickPaint = Paint()
      ..color = const Color(0xFF6B7DB3).withOpacity(0.3)
      ..strokeWidth = 1;
    for (int i = 0; i <= 10; i++) {
      final a = startRad + sweepRad * i / 10;
      final outer = center + Offset(radius + 4, 0);
      final inner = center + Offset(radius - 4, 0);
      final cosA = cos(a);
      final sinA = sin(a);
      canvas.drawLine(
        Offset(center.dx + (radius + 2) * cosA,
            center.dy + (radius + 2) * sinA),
        Offset(center.dx + (radius - 3) * cosA,
            center.dy + (radius - 3) * sinA),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value;
}
