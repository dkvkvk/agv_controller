import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agv_state.dart';
import '../services/bluetooth_service.dart';
import '../services/protocol_service.dart';
import '../widgets/joystick_widget.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  double _speed = 500;
  String _currentCmd = 'STOP';
  Timer? _sendTimer;

  // Last joystick direction
  double _joyDx = 0;
  double _joyDy = 0;

  ProtocolService get _proto => context.read<ProtocolService>();

  void _onJoystickUpdate(double dx, double dy) {
    _joyDx = dx;
    _joyDy = dy;

    // Start throttled sending if not already active
    _sendTimer ??= Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _sendJoystickCommand(),
    );
    // Also send immediately on first touch
    _sendJoystickCommand();
  }

  void _onJoystickEnd() {
    _sendTimer?.cancel();
    _sendTimer = null;
    _joyDx = 0;
    _joyDy = 0;
    _proto.stop();
    setState(() => _currentCmd = 'STOP');
  }

  void _sendJoystickCommand() {
    final dist = sqrt(_joyDx * _joyDx + _joyDy * _joyDy);
    if (dist < 0.2) {
      _proto.stop();
      setState(() => _currentCmd = 'STOP');
      return;
    }

    final speed = (_speed * min(dist, 1.0)).round().clamp(0, 1000);

    if (_joyDy.abs() >= _joyDx.abs()) {
      // Vertical dominant → forward / backward
      if (_joyDy < 0) {
        _proto.forward(speed);
        setState(() => _currentCmd = 'FWD $speed');
      } else {
        _proto.backward(speed);
        setState(() => _currentCmd = 'BACK $speed');
      }
    } else {
      // Horizontal dominant → turn
      final gain = (_joyDx.abs() * 200).round().clamp(50, 500);
      if (_joyDx < 0) {
        _proto.turnLeft(speed, gain);
        setState(() => _currentCmd = 'LEFT $speed,$gain');
      } else {
        _proto.turnRight(speed, gain);
        setState(() => _currentCmd = 'RIGHT $speed,$gain');
      }
    }
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothService>();
    final state = context.watch<AGVState>();
    const cyan = Color(0xFF00D4FF);
    const purple = Color(0xFF7C4DFF);
    const danger = Color(0xFFFF1744);
    const surface = Color(0xFF111636);

    final connected = bt.isConnected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // ── Top status bar ──
            _statusBar(state, bt, cyan, purple, surface),
            const SizedBox(height: 10),

            // ── Current command ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cyan.withOpacity(0.1)),
              ),
              child: Center(
                child: Text(
                  _currentCmd,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cyan,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Joystick ──
            Expanded(
              child: Center(
                child: Opacity(
                  opacity: connected && state.controlMode == 'manual'
                      ? 1.0
                      : 0.35,
                  child: IgnorePointer(
                    ignoring:
                        !connected || state.controlMode != 'manual',
                    child: JoystickWidget(
                      size: 220,
                      onUpdate: _onJoystickUpdate,
                      onEnd: _onJoystickEnd,
                    ),
                  ),
                ),
              ),
            ),

            // ── Speed slider ──
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed, color: cyan, size: 18),
                      const SizedBox(width: 8),
                      const Text('速度',
                          style: TextStyle(color: Color(0xFF6B7DB3))),
                      const Spacer(),
                      Text(
                        _speed.toInt().toString(),
                        style: const TextStyle(
                          color: Color(0xFFE0E6FF),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: cyan,
                      inactiveTrackColor: cyan.withOpacity(0.15),
                      thumbColor: cyan,
                      overlayColor: cyan.withOpacity(0.1),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _speed,
                      min: 0,
                      max: 1000,
                      divisions: 20,
                      onChanged: (v) => setState(() => _speed = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Emergency stop ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: connected
                    ? () {
                        _onJoystickEnd();
                        _proto.stop();
                      }
                    : null,
                icon: const Icon(Icons.emergency_rounded, size: 26),
                label: const Text('紧 急 停 止',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: danger.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(AGVState state, BluetoothService bt, Color cyan,
      Color purple, Color surface) {
    final isAuto = state.controlMode == 'auto';
    final connected = bt.isConnected;

    return Row(
      children: [
        // Mode toggle
        Expanded(
          child: GestureDetector(
            onTap: connected
                ? () {
                    if (isAuto) {
                      _proto.setModeManual();
                    } else {
                      _proto.setModeAuto();
                    }
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (isAuto ? purple : cyan).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isAuto ? Icons.smart_toy : Icons.gamepad,
                    color: isAuto ? purple : cyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAuto ? '自动模式' : '手动模式',
                    style: TextStyle(
                      color: isAuto ? purple : cyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.swap_horiz,
                      color: Colors.white.withOpacity(0.3), size: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Run / Stop toggle
        GestureDetector(
          onTap: connected ? () => _proto.toggleRunning() : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 18),
            decoration: BoxDecoration(
              color: state.running
                  ? const Color(0xFF00E676).withOpacity(0.12)
                  : surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.running
                    ? const Color(0xFF00E676).withOpacity(0.4)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  state.running
                      ? Icons.play_circle_fill
                      : Icons.stop_circle_outlined,
                  color: state.running
                      ? const Color(0xFF00E676)
                      : const Color(0xFF6B7DB3),
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  state.running ? '运行中' : '已停止',
                  style: TextStyle(
                    color: state.running
                        ? const Color(0xFF00E676)
                        : const Color(0xFF6B7DB3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
