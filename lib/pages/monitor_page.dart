import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agv_state.dart';
import '../services/bluetooth_service.dart';
import '../services/protocol_service.dart';
import '../widgets/sensor_bar.dart';
import '../widgets/speed_gauge.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Start polling every 2 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPolling();
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final bt = context.read<BluetoothService>();
      if (bt.isConnected) {
        context.read<ProtocolService>().queryAll();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AGVState>();
    final bt = context.watch<BluetoothService>();
    const cyan = Color(0xFF00D4FF);
    const purple = Color(0xFF7C4DFF);
    const surface = Color(0xFF111636);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                const Icon(Icons.monitor_heart, color: cyan, size: 26),
                const SizedBox(width: 10),
                const Text('状态监控',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE0E6FF))),
                const Spacer(),
                if (!bt.isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9100).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('未连接',
                        style: TextStyle(
                            color: Color(0xFFFF9100), fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Mode & Status ──
            _modeStatusRow(state, cyan, purple, surface),
            const SizedBox(height: 16),

            // ── Sensors ──
            _card('循迹传感器', Icons.sensors, cyan, surface,
                child: Center(
                    child: SensorBar(sensors: state.sensors))),
            const SizedBox(height: 14),

            // ── Speed gauges ──
            _card('四轮速度', Icons.speed, cyan, surface,
                child: _speedGauges(state)),
            const SizedBox(height: 14),

            // ── Error trend ──
            _card('循迹误差', Icons.timeline, cyan, surface,
                child: SizedBox(
                  height: 140,
                  child: _errorChart(state, cyan),
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _modeStatusRow(
      AGVState s, Color cyan, Color purple, Color surface) {
    final badges = <Widget>[
      _badge(
        s.controlMode == 'auto' ? '自动' : '手动',
        s.controlMode == 'auto'
            ? purple
            : cyan,
        s.controlMode == 'auto'
            ? Icons.smart_toy
            : Icons.gamepad,
      ),
      _badge(
        _followLabel(s.followMode),
        _followColor(s.followMode),
        Icons.route,
      ),
      _badge(
        s.running ? '运行中' : '已停止',
        s.running ? const Color(0xFF00E676) : const Color(0xFF6B7DB3),
        s.running ? Icons.play_circle : Icons.stop_circle,
      ),
      _badge(
        'ERR: ${s.error}',
        s.error == 0
            ? const Color(0xFF00E676)
            : const Color(0xFFFF9100),
        Icons.warning_amber,
      ),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: badges);
  }

  Widget _badge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _speedGauges(AGVState s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            SpeedGauge(
                value: s.speeds.isNotEmpty
                    ? s.speeds[0].toDouble()
                    : 0,
                label: '右前'),
            const SizedBox(height: 8),
            SpeedGauge(
                value: s.speeds.length > 1
                    ? s.speeds[1].toDouble()
                    : 0,
                label: '右后'),
          ],
        ),
        Column(
          children: [
            SpeedGauge(
                value: s.speeds.length > 2
                    ? s.speeds[2].toDouble()
                    : 0,
                label: '左前'),
            const SizedBox(height: 8),
            SpeedGauge(
                value: s.speeds.length > 3
                    ? s.speeds[3].toDouble()
                    : 0,
                label: '左后'),
          ],
        ),
      ],
    );
  }

  Widget _errorChart(AGVState s, Color cyan) {
    if (s.errorHistory.isEmpty) {
      return Center(
        child: Text('暂无数据',
            style: TextStyle(color: Colors.white.withOpacity(0.3))),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < s.errorHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), s.errorHistory[i]));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: cyan,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: cyan.withOpacity(0.08),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
        minY: -5,
        maxY: 5,
      ),
    );
  }

  Widget _card(
      String title, IconData icon, Color color, Color surface,
      {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _followLabel(String mode) {
    switch (mode) {
      case 'follow':
        return '循迹中';
      case 'hold':
        return '保持';
      case 'search':
        return '搜索';
      case 'turn':
        return '转弯';
      case 'stop':
        return '停止';
      default:
        return mode;
    }
  }

  Color _followColor(String mode) {
    switch (mode) {
      case 'follow':
        return const Color(0xFF00E676);
      case 'hold':
        return const Color(0xFF00D4FF);
      case 'search':
        return const Color(0xFFFF9100);
      case 'turn':
        return const Color(0xFF7C4DFF);
      case 'stop':
        return const Color(0xFF6B7DB3);
      default:
        return const Color(0xFF6B7DB3);
    }
  }
}
