import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agv_state.dart';
import '../services/bluetooth_service.dart';
import '../services/protocol_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Local slider values (edited but not yet sent)
  late double _baseSpeed;
  late double _turnGain;
  late double _maxSpeed;
  late double _minSpeed;
  bool _initialised = false;

  void _syncFromState(AGVState s) {
    _baseSpeed = s.baseSpeed.toDouble();
    _turnGain = s.turnGain.toDouble();
    _maxSpeed = s.maxSpeed.toDouble();
    _minSpeed = s.minSpeed.toDouble();
    _initialised = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AGVState>();
    final bt = context.watch<BluetoothService>();
    final connected = bt.isConnected;
    const cyan = Color(0xFF00D4FF);
    const purple = Color(0xFF7C4DFF);
    const surface = Color(0xFF111636);
    const success = Color(0xFF00E676);

    if (!_initialised) _syncFromState(state);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                const Icon(Icons.tune, color: cyan, size: 26),
                const SizedBox(width: 10),
                const Text('参数设置',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE0E6FF))),
              ],
            ),
            const SizedBox(height: 20),

            // ── Parameter sliders ──
            _paramCard(
              'BASE_SPEED',
              '基础速度',
              Icons.speed,
              _baseSpeed,
              0,
              1000,
              cyan,
              surface,
              (v) => setState(() => _baseSpeed = v),
            ),
            _paramCard(
              'TURN_GAIN',
              '转弯增益',
              Icons.turn_right,
              _turnGain,
              0,
              300,
              purple,
              surface,
              (v) => setState(() => _turnGain = v),
            ),
            _paramCard(
              'MAX_SPEED',
              '最大速度',
              Icons.arrow_upward,
              _maxSpeed,
              0,
              1000,
              const Color(0xFFFF9100),
              surface,
              (v) => setState(() => _maxSpeed = v),
            ),
            _paramCard(
              'MIN_SPEED',
              '最小速度',
              Icons.arrow_downward,
              _minSpeed,
              0,
              500,
              success,
              surface,
              (v) => setState(() => _minSpeed = v),
            ),
            const SizedBox(height: 14),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    '读取参数',
                    Icons.download,
                    cyan,
                    connected
                        ? () async {
                            await context
                                .read<ProtocolService>()
                                .queryParams();
                            // Wait a bit then sync slider values
                            await Future.delayed(
                                const Duration(milliseconds: 400));
                            if (mounted) {
                              setState(() => _syncFromState(
                                  context.read<AGVState>()));
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    '下发全部',
                    Icons.upload,
                    success,
                    connected ? _sendAll : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    '保存预设',
                    Icons.save,
                    purple,
                    () => _savePreset(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    '加载预设',
                    Icons.folder_open,
                    const Color(0xFFFF9100),
                    () => _loadPreset(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Current device values ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cyan.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('设备当前值',
                      style: TextStyle(
                          color: Color(0xFF6B7DB3), fontSize: 13)),
                  const SizedBox(height: 8),
                  _valRow('BASE_SPEED', state.baseSpeed, cyan),
                  _valRow('TURN_GAIN', state.turnGain, purple),
                  _valRow('MAX_SPEED', state.maxSpeed,
                      const Color(0xFFFF9100)),
                  _valRow('MIN_SPEED', state.minSpeed, success),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _paramCard(
    String key,
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    Color color,
    Color surface,
    ValueChanged<double> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFFE0E6FF), fontSize: 14)),
              const Spacer(),
              Text(
                value.toInt().toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.12),
              thumbColor: color,
              overlayColor: color.withOpacity(0.08),
              trackHeight: 5,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / 10).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      String text, IconData icon, Color color, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.12),
        foregroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.05),
        disabledForegroundColor: color.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _valRow(String key, int val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(key,
              style: const TextStyle(
                  color: Color(0xFF6B7DB3),
                  fontSize: 13,
                  fontFamily: 'monospace')),
          const Spacer(),
          Text(val.toString(),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _sendAll() async {
    final p = context.read<ProtocolService>();
    await p.setBaseSpeed(_baseSpeed.toInt());
    await Future.delayed(const Duration(milliseconds: 60));
    await p.setTurnGain(_turnGain.toInt());
    await Future.delayed(const Duration(milliseconds: 60));
    await p.setMaxSpeed(_maxSpeed.toInt());
    await Future.delayed(const Duration(milliseconds: 60));
    await p.setMinSpeed(_minSpeed.toInt());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('参数已下发'),
        backgroundColor: Color(0xFF00E676),
      ));
    }
  }

  Future<void> _savePreset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('base_speed', _baseSpeed.toInt());
    await prefs.setInt('turn_gain', _turnGain.toInt());
    await prefs.setInt('max_speed', _maxSpeed.toInt());
    await prefs.setInt('min_speed', _minSpeed.toInt());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('预设已保存'),
        backgroundColor: Color(0xFF7C4DFF),
      ));
    }
  }

  Future<void> _loadPreset() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _baseSpeed = (prefs.getInt('base_speed') ?? 500).toDouble();
      _turnGain = (prefs.getInt('turn_gain') ?? 50).toDouble();
      _maxSpeed = (prefs.getInt('max_speed') ?? 900).toDouble();
      _minSpeed = (prefs.getInt('min_speed') ?? 50).toDouble();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('预设已加载 — 请点击"下发全部"应用到设备'),
        backgroundColor: Color(0xFFFF9100),
      ));
    }
  }
}
