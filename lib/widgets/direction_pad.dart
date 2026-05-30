import 'package:flutter/material.dart';

/// D‑pad style directional control (alternative to joystick).
///
/// Fires [onDirection] with one of 'F', 'B', 'L', 'R' while pressed,
/// and [onStop] when released.
class DirectionPad extends StatelessWidget {
  final void Function(String direction) onDirection;
  final VoidCallback onStop;
  final double size;

  const DirectionPad({
    super.key,
    required this.onDirection,
    required this.onStop,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = size * 0.36;
    const accent = Color(0xFF00D4FF);
    const surface = Color(0xFF151B42);

    Widget dirButton(IconData icon, String dir, Alignment align) {
      return Align(
        alignment: align,
        child: GestureDetector(
          onTapDown: (_) => onDirection(dir),
          onTapUp: (_) => onStop(),
          onTapCancel: onStop,
          child: Container(
            width: btnSize,
            height: btnSize,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.2)),
            ),
            child: Icon(icon, color: accent, size: btnSize * 0.45),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Center stop button
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: onStop,
              child: Container(
                width: btnSize * 0.75,
                height: btnSize * 0.75,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.1)),
                ),
                child: Icon(Icons.stop_rounded,
                    color: accent.withOpacity(0.5), size: btnSize * 0.35),
              ),
            ),
          ),
          dirButton(Icons.arrow_upward_rounded, 'F',
              Alignment.topCenter),
          dirButton(Icons.arrow_downward_rounded, 'B',
              Alignment.bottomCenter),
          dirButton(Icons.arrow_back_rounded, 'L',
              Alignment.centerLeft),
          dirButton(Icons.arrow_forward_rounded, 'R',
              Alignment.centerRight),
        ],
      ),
    );
  }
}
