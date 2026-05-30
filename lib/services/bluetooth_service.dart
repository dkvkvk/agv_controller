import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Manages Bluetooth Classic SPP connection to HC-05.
class BluetoothService extends ChangeNotifier {
  BluetoothConnection? _connection;
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  bool _isConnecting = false;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;

  // Line‑buffered data stream
  final StreamController<String> _lineController =
      StreamController<String>.broadcast();
  String _rxBuffer = '';

  // ── Public getters ──
  Stream<String> get lineStream => _lineController.stream;
  bool get isConnected => _connection?.isConnected ?? false;
  bool get isConnecting => _isConnecting;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  BluetoothState get bluetoothState => _bluetoothState;

  BluetoothService() {
    _init();
  }

  Future<void> _init() async {
    try {
      _bluetoothState = await FlutterBluetoothSerial.instance.state;
    } catch (_) {}

    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      _bluetoothState = state;
      if (state == BluetoothState.STATE_OFF) {
        disconnect();
      }
      notifyListeners();
    });
  }

  /// Request the system to turn Bluetooth on.
  Future<bool> requestEnable() async {
    try {
      return await FlutterBluetoothSerial.instance.requestEnable() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Return devices already paired in the system settings.
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  /// Connect to a specific Bluetooth device (HC-05).
  Future<void> connect(BluetoothDevice device) async {
    if (_isConnecting || isConnected) return;

    _isConnecting = true;
    notifyListeners();

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDeviceName = device.name ?? device.address;
      _connectedDeviceAddress = device.address;
      _isConnecting = false;
      _rxBuffer = '';
      notifyListeners();

      // Start listening to incoming data
      _connection!.input?.listen(
        _onDataReceived,
        onDone: () {
          _handleDisconnect();
        },
        onError: (_) {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnecting = false;
      _connection = null;
      _connectedDeviceName = null;
      _connectedDeviceAddress = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Send a raw string over Bluetooth.
  Future<void> send(String message) async {
    if (!isConnected || _connection == null) return;
    try {
      _connection!.output
          .add(Uint8List.fromList(utf8.encode(message)));
      await _connection!.output.allSent;
    } catch (_) {
      _handleDisconnect();
    }
  }

  /// Gracefully disconnect.
  Future<void> disconnect() async {
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
    _connectedDeviceName = null;
    _connectedDeviceAddress = null;
    _rxBuffer = '';
    notifyListeners();
  }

  // ── Private helpers ──

  void _onDataReceived(Uint8List data) {
    _rxBuffer += utf8.decode(data, allowMalformed: true);

    // Emit every complete line (terminated by \n)
    while (_rxBuffer.contains('\n')) {
      final idx = _rxBuffer.indexOf('\n');
      final line = _rxBuffer.substring(0, idx).replaceAll('\r', '').trim();
      _rxBuffer = _rxBuffer.substring(idx + 1);
      if (line.isNotEmpty) {
        _lineController.add(line);
      }
    }
  }

  void _handleDisconnect() {
    _connection = null;
    _connectedDeviceName = null;
    _connectedDeviceAddress = null;
    _rxBuffer = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _lineController.close();
    try {
      _connection?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
