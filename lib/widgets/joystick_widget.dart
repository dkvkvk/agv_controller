import 'dart:math';
import 'package:flutter/material.dart';

/// A virtual joystick that reports normalised (dx, dy) in the range ‑1…+1.
///
/// [onUpdate] fires while the user drags the knob.
/// [onEnd]    fires when the user releases the knob.
class JoystickWidget extends StatefulWidget {
  final double size;
  final void Function(double dx, double dy) onUpdate;
  final VoidCallback? onEnd;

  const JoystickWidget({
    super.key,
    this.size = 200,
    required this.onUpdate,
    this.onEnd,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  double _dy = 0;
  late AnimationController _springController;
  late Animation<Offset> _springAnim;

  double get _radius => widget.size / 2;
  double get _knobRadius => widget.size * 0.15;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _springAnim =
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _springController.addListener(() {
      setState(() {
        _dx = _springAnim.value.dx;
        _dy = _springAnim.value.dy;
      });
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _handlePan(Offset localPos) {
    final center = Offset(_radius, _radius);
    var delta = localPos - center;
    final dist = delta.distance;
    final maxDist = _radius - _knobRadius;
    if (dist > maxDist) {
      delta = delta / dist * maxDist;
    }
    setState(() {
      _dx = delta.dx / maxDist;
      _dy = delta.dy / maxDist;
    });
    widget.onUpdate(_dx, _dy);
  }

  void _handleEnd() {
    _springAnim = Tween<Offset>(
      begin: Offset(_dx, _dy),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _springController.forward(from: 0);
    widget.onEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final maxDist = _radius - _knobRadius;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanStart: (d) => _handlePan(d.localPosition),
        onPanUpdate: (d) => _handlePan(d.localPosition),
        onPanEnd: (_) => _handleEnd(),
        child: CustomPaint(
          painter: _JoystickPainter(
            dx: _dx * maxDist,
            dy: _dy * maxDist,
            baseRadius: _radius,
            knobRadius: _knobRadius,
            accentColor: const Color(0xFF00D4FF),
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final double dx, dy;
  final double baseRadius;
  final double knobRadius;
  final Color accentColor;

  _JoystickPainter({
    required this.dx,
    required this.dy,
    required this.baseRadius,
    required this.knobRadius,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Base circle
    canvas.drawCircle(
      center,
      baseRadius - 2,
      Paint()
        ..color = const Color(0xFF111636)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      baseRadius - 2,
      Paint()
        ..color = accentColor.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Crosshair lines
    final linePaint = Paint()
      ..color = accentColor.withOpacity(0.08)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(center.dx, center.dy - baseRadius + 20),
        Offset(center.dx, center.dy + baseRadius - 20),
        linePaint);
    canvas.drawLine(
        Offset(center.dx - baseRadius + 20, center.dy),
        Offset(center.dx + baseRadius - 20, center.dy),
        linePaint);

    // Direction indicators (small arrows)
    final arrowPaint = Paint()
      ..color = accentColor.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final arrowDist = baseRadius * 0.72;
    // Up arrow
    _drawTriangle(canvas, center + Offset(0, -arrowDist), 8, 0, arrowPaint);
    // Down arrow
    _drawTriangle(canvas, center + Offset(0, arrowDist), 8, pi, arrowPaint);
    // Left arrow
    _drawTriangle(
        canvas, center + Offset(-arrowDist, 0), 8, -pi / 2, arrowPaint);
    // Right arrow
    _drawTriangle(
        canvas, center + Offset(arrowDist, 0), 8, pi / 2, arrowPaint);

    // Knob
    final knobCenter = center + Offset(dx, dy);

    // Glow
    canvas.drawCircle(
      knobCenter,
      knobRadius + 6,
      Paint()
        ..color = accentColor.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Knob body
    final knobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor,
          accentColor.withOpacity(0.6),
        ],
      ).createShader(
          Rect.fromCircle(center: knobCenter, radius: knobRadius));
    canvas.drawCircle(knobCenter, knobRadius, knobPaint);

    // Knob highlight
    canvas.drawCircle(
      knobCenter - Offset(knobRadius * 0.25, knobRadius * 0.25),
      knobRadius * 0.35,
      Paint()..color = Colors.white.withOpacity(0.3),
    );
  }

  void _drawTriangle(
      Canvas canvas, Offset center, double size, double angle, Paint paint) {
    final path = Path();
    path.moveTo(
      center.dx + size * cos(angle - pi / 2),
      center.dy + size * sin(angle - pi / 2),
    );
    path.lineTo(
      center.dx + size * 1.2 * cos(angle),
      center.dy + size * 1.2 * sin(angle),
    );
    path.lineTo(
      center.dx + size * cos(angle + pi / 2),
      center.dy + size * sin(angle + pi / 2),
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) =>
      old.dx != dx || old.dy != dy;
}
