import 'dart:async';
import 'dart:convert';

import 'bluetooth_service.dart';
import '../models/agv_state.dart';

/// Bridges [BluetoothService] ↔ [AGVState].
///
/// • Listens to incoming lines and parses JSON / text responses.
/// • Provides typed command helpers for every AGV protocol command.
class ProtocolService {
  final BluetoothService _bt;
  final AGVState _state;
  StreamSubscription<String>? _sub;

  ProtocolService(this._bt, this._state) {
    _sub = _bt.lineStream.listen(_processLine);
  }

  // ─────────────────────────────────
  //  Incoming data parsing
  // ─────────────────────────────────

  void _processLine(String line) {
    // Log everything to the terminal
    _state.addTerminalEntry(line, false);

    // JSON status payload  {"type":"status", ...}
    if (line.startsWith('{')) {
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json['type'] == 'status') {
          _state.updateFromJson(json);
        }
        return;
      } catch (_) {
        // Not valid JSON — fall through to text parsing
      }
    }

    // QP response  →  P:base,gain,max,min
    if (line.startsWith('P:')) {
      _parseParams(line);
      return;
    }

    // QS response  →  S:s1,s2,s3,s4,s5
    if (line.startsWith('S:')) {
      _parseSensors(line);
      return;
    }

    // QM response  →  M:mode,flag
    if (line.startsWith('M:')) {
      _parseMode(line);
      return;
    }

    // V‑command confirmations
    if (line.startsWith('BASE_SPEED = ')) {
      _state.updateSingleParam(
          'BASE_SPEED', int.tryParse(line.split('= ').last) ?? 0);
      return;
    }
    if (line.startsWith('TURN_GAIN = ')) {
      _state.updateSingleParam(
          'TURN_GAIN', int.tryParse(line.split('= ').last) ?? 0);
      return;
    }
    if (line.startsWith('MAX_SPEED = ')) {
      _state.updateSingleParam(
          'MAX_SPEED', int.tryParse(line.split('= ').last) ?? 0);
      return;
    }
    if (line.startsWith('MIN_SPEED = ')) {
      _state.updateSingleParam(
          'MIN_SPEED', int.tryParse(line.split('= ').last) ?? 0);
      return;
    }

    // AUTO_REPORT confirmation
    if (line.startsWith('AUTO_REPORT = ')) {
      _state.autoReport =
          (int.tryParse(line.split('= ').last) ?? 0) != 0;
      return;
    }

    // MODE confirmation
    if (line.startsWith('MODE = ')) {
      final m = line.split('= ').last.trim();
      _state.controlMode = m;
      _state.notifyListeners();
      return;
    }
  }

  void _parseParams(String line) {
    try {
      final parts = line.substring(2).split(',');
      if (parts.length == 4) {
        _state.updateParams(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          int.parse(parts[3]),
        );
      }
    } catch (_) {}
  }

  void _parseSensors(String line) {
    try {
      final parts = line.substring(2).split(',');
      if (parts.length == 5) {
        _state.updateSensors(parts.map((s) => int.parse(s)).toList());
      }
    } catch (_) {}
  }

  void _parseMode(String line) {
    try {
      final parts = line.substring(2).split(',');
      if (parts.length == 2) {
        _state.updateMode(
          int.parse(parts[0]) == 0 ? 'auto' : 'manual',
          int.parse(parts[1]) != 0,
        );
      }
    } catch (_) {}
  }

  // ─────────────────────────────────
  //  Command senders
  // ─────────────────────────────────

  /// Send raw text — automatically appends \\r\\n if missing.
  Future<void> sendRaw(String cmd) async {
    final message = cmd.endsWith('\r\n') ? cmd : '$cmd\r\n';
    _state.addTerminalEntry(cmd, true);
    await _bt.send(message);
  }

  // Control
  Future<void> toggleRunning() => sendRaw('C');
  Future<void> setModeAuto() => sendRaw('M:0');
  Future<void> setModeManual() => sendRaw('M:1');

  // Motion (manual mode only)
  Future<void> forward(int speed) => sendRaw('F:$speed');
  Future<void> backward(int speed) => sendRaw('B:$speed');
  Future<void> turnLeft(int speed, int gain) => sendRaw('L:$speed,$gain');
  Future<void> turnRight(int speed, int gain) => sendRaw('R:$speed,$gain');
  Future<void> stop() => sendRaw('S');
  Future<void> setDuty(int d1, int d2, int d3, int d4) =>
      sendRaw('D:$d1,$d2,$d3,$d4');

  // Parameter setting
  Future<void> setBaseSpeed(int v) => sendRaw('V1:$v');
  Future<void> setTurnGain(int v) => sendRaw('V2:$v');
  Future<void> setMaxSpeed(int v) => sendRaw('V3:$v');
  Future<void> setMinSpeed(int v) => sendRaw('V4:$v');

  // Queries
  Future<void> queryAll() => sendRaw('Q');
  Future<void> queryParams() => sendRaw('QP');
  Future<void> querySensors() => sendRaw('QS');
  Future<void> queryMode() => sendRaw('QM');

  // Auto‑report
  Future<void> enableAutoReport() => sendRaw('AR:1');
  Future<void> disableAutoReport() => sendRaw('AR:0');

  // OLED
  Future<void> switchOledPage() => sendRaw('N');

  void dispose() {
    _sub?.cancel();
  }
}
