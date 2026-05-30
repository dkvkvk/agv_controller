import 'package:flutter/foundation.dart';

/// Terminal log entry
class TerminalEntry {
  final DateTime timestamp;
  final String message;
  final bool isSent; // true = sent to AGV, false = received from AGV

  TerminalEntry({
    required this.timestamp,
    required this.message,
    required this.isSent,
  });
}

/// Central AGV state — all data received from / sent to the device
class AGVState extends ChangeNotifier {
  // ── Parameters (defaults from firmware lm2596s.c) ──
  int baseSpeed = 500;
  int turnGain = 50;
  int maxSpeed = 900;
  int minSpeed = 50;

  // ── 5‑channel line‑follower sensors ──
  List<int> sensors = [0, 0, 0, 0, 0];

  // ── Four‑wheel speeds: [rightFront, rightRear, leftFront, leftRear] ──
  List<int> speeds = [0, 0, 0, 0];

  // ── Control mode: 'auto' | 'manual' ──
  String controlMode = 'auto';

  // ── Follow mode: 'follow' | 'hold' | 'search' | 'turn' | 'stop' ──
  String followMode = 'follow';

  // ── Running flag ──
  bool running = false;

  // ── Line‑tracking error value ──
  int error = 0;

  // ── Auto‑report enabled ──
  bool autoReport = false;

  // ── Error history for trend chart ──
  List<double> errorHistory = [];
  static const int maxErrorHistory = 60;

  // ── Terminal log ──
  List<TerminalEntry> terminalLog = [];
  static const int maxTerminalEntries = 500;

  // ─────────────────────────────────────────────
  //  Update helpers (called by ProtocolService)
  // ─────────────────────────────────────────────

  /// Parse full JSON status payload from the device
  void updateFromJson(Map<String, dynamic> json) {
    if (json.containsKey('params')) {
      final p = json['params'] as Map<String, dynamic>;
      baseSpeed = (p['base'] as num?)?.toInt() ?? baseSpeed;
      turnGain = (p['gain'] as num?)?.toInt() ?? turnGain;
      maxSpeed = (p['max'] as num?)?.toInt() ?? maxSpeed;
      minSpeed = (p['min'] as num?)?.toInt() ?? minSpeed;
    }
    if (json.containsKey('sensors')) {
      sensors = List<int>.from(json['sensors']);
    }
    if (json.containsKey('speeds')) {
      speeds = List<int>.from(json['speeds']);
    }
    if (json.containsKey('mode')) {
      controlMode = json['mode'] as String;
    }
    if (json.containsKey('follow')) {
      followMode = json['follow'] as String;
    }
    if (json.containsKey('flag')) {
      running = (json['flag'] as num).toInt() != 0;
    }
    if (json.containsKey('error')) {
      error = (json['error'] as num).toInt();
      _pushError(error.toDouble());
    }
    notifyListeners();
  }

  void updateSensors(List<int> s) {
    sensors = s;
    notifyListeners();
  }

  void updateSpeeds(List<int> s) {
    speeds = s;
    notifyListeners();
  }

  void updateParams(int base, int gain, int max, int min) {
    baseSpeed = base;
    turnGain = gain;
    maxSpeed = max;
    minSpeed = min;
    notifyListeners();
  }

  void updateMode(String mode, bool isRunning) {
    controlMode = mode;
    running = isRunning;
    notifyListeners();
  }

  void updateSingleParam(String name, int value) {
    switch (name) {
      case 'BASE_SPEED':
        baseSpeed = value;
        break;
      case 'TURN_GAIN':
        turnGain = value;
        break;
      case 'MAX_SPEED':
        maxSpeed = value;
        break;
      case 'MIN_SPEED':
        minSpeed = value;
        break;
    }
    notifyListeners();
  }

  // ── Terminal ──

  void addTerminalEntry(String message, bool isSent) {
    terminalLog.add(TerminalEntry(
      timestamp: DateTime.now(),
      message: message,
      isSent: isSent,
    ));
    if (terminalLog.length > maxTerminalEntries) {
      terminalLog.removeAt(0);
    }
    notifyListeners();
  }

  void clearTerminal() {
    terminalLog.clear();
    notifyListeners();
  }

  // ── Error history ──

  void _pushError(double e) {
    errorHistory.add(e);
    if (errorHistory.length > maxErrorHistory) {
      errorHistory.removeAt(0);
    }
  }

  void clearErrorHistory() {
    errorHistory.clear();
    notifyListeners();
  }
}
