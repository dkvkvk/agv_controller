import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../services/bluetooth_service.dart';
import '../widgets/connection_indicator.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  List<BluetoothDevice> _devices = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final bt = context.read<BluetoothService>();

    // Ensure bluetooth is on
    if (bt.bluetoothState != BluetoothState.STATE_ON) {
      final ok = await bt.requestEnable();
      if (!ok) {
        setState(() {
          _loading = false;
          _error = '请先开启蓝牙';
        });
        return;
      }
    }

    final devices = await bt.getBondedDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    final bt = context.read<BluetoothService>();
    try {
      await bt.connect(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已连接到 ${device.name ?? device.address}'),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接失败: $e'),
            backgroundColor: const Color(0xFFFF1744),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothService>();
    const cyan = Color(0xFF00D4FF);
    const surface = Color(0xFF111636);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                const Icon(Icons.bluetooth, color: cyan, size: 28),
                const SizedBox(width: 10),
                const Text(
                  '蓝牙连接',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE0E6FF),
                  ),
                ),
                const Spacer(),
                ConnectionIndicator(
                  isConnected: bt.isConnected,
                  isConnecting: bt.isConnecting,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Connected device card ──
            if (bt.isConnected)
              _buildConnectedCard(bt, cyan, surface),

            if (bt.isConnected) const SizedBox(height: 20),

            // ── Device list ──
            Row(
              children: [
                const Text(
                  '已配对设备',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7DB3),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _refreshDevices,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cyan,
                          ),
                        )
                      : const Icon(Icons.refresh, color: cyan, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFFF9100))),
              ),

            Expanded(
              child: _devices.isEmpty && !_loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bluetooth_searching,
                              color: cyan.withOpacity(0.3), size: 64),
                          const SizedBox(height: 12),
                          Text(
                            '未找到已配对设备\n请先在系统蓝牙设置中配对 HC-05',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _buildDeviceTile(_devices[i], bt, cyan, surface),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedCard(
      BluetoothService bt, Color cyan, Color surface) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cyan.withOpacity(0.08),
            const Color(0xFF7C4DFF).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyan.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bluetooth_connected,
                color: Color(0xFF00E676), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已连接',
                    style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  bt.connectedDeviceName ?? '',
                  style: const TextStyle(
                      color: Color(0xFFE0E6FF),
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  bt.connectedDeviceAddress ?? '',
                  style: const TextStyle(
                      color: Color(0xFF6B7DB3), fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => bt.disconnect(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1744).withOpacity(0.15),
              foregroundColor: const Color(0xFFFF1744),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('断开'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice device, BluetoothService bt,
      Color cyan, Color surface) {
    final isThisConnected =
        bt.isConnected && bt.connectedDeviceAddress == device.address;
    final isHC05 = (device.name ?? '').toUpperCase().contains('HC');

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHC05
              ? cyan.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHC05
                ? cyan.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.bluetooth,
            color: isHC05 ? cyan : const Color(0xFF6B7DB3),
          ),
        ),
        title: Text(
          device.name ?? '未知设备',
          style: TextStyle(
            color: const Color(0xFFE0E6FF),
            fontWeight: isHC05 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          device.address,
          style: const TextStyle(color: Color(0xFF6B7DB3), fontSize: 12),
        ),
        trailing: isThisConnected
            ? const Chip(
                label: Text('已连接',
                    style: TextStyle(color: Color(0xFF00E676), fontSize: 12)),
                backgroundColor: Color(0xFF0D1133),
                side: BorderSide(color: Color(0xFF00E676)),
              )
            : bt.isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton(
                    onPressed: () => _connect(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cyan.withOpacity(0.15),
                      foregroundColor: cyan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('连接'),
                  ),
      ),
    );
  }
}
