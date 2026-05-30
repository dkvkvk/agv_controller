import 'package:flutter/material.dart';

/// Pulsing circle that indicates Bluetooth connection status.
///
/// • **Connected** — bright cyan pulsing glow.
/// • **Connecting** — amber spinning indicator.
/// • **Disconnected** — dim gray static circle.
class ConnectionIndicator extends StatefulWidget {
  final bool isConnected;
  final bool isConnecting;
  final double size;

  const ConnectionIndicator({
    super.key,
    required this.isConnected,
    this.isConnecting = false,
    this.size = 14,
  });

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isConnecting) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor:
              AlwaysStoppedAnimation(const Color(0xFFFF9100)),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final glow = widget.isConnected ? _ctrl.value : 0.0;
        final color = widget.isConnected
            ? const Color(0xFF00E676)
            : const Color(0xFF6B7DB3);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: widget.isConnected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3 + glow * 0.4),
                      blurRadius: 8 + glow * 8,
                      spreadRadius: glow * 3,
                    ),
                  ]
                : [],
          ),
        );
      },
    );
  }
}
