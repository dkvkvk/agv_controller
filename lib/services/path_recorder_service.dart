import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recorded_path.dart';
import 'protocol_service.dart';

/// Handles recording, playback, persistence, and import/export of AGV paths.
class PathRecorderService extends ChangeNotifier {
  // ── Storage key ──
  static const _storageKey = 'recorded_paths_v1';

  // ── Recording state ──
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  DateTime? _lastCommandTime;
  List<PathCommand> _recordingBuffer = [];
  String? _lastRecordedCommand;

  // ── Playback state ──
  bool _isPlaying = false;
  int _playbackIndex = 0;
  int _playbackTotal = 0;
  String _playbackCurrentCmd = '';
  Timer? _playbackTimer;
  ProtocolService? _playbackProto;

  // ── Saved paths ──
  List<RecordedPath> _paths = [];

  // ── Public getters ──
  bool get isRecording => _isRecording;
  DateTime? get recordingStartTime => _recordingStartTime;
  int get recordingCommandCount => _recordingBuffer.length;

  bool get isPlaying => _isPlaying;
  int get playbackIndex => _playbackIndex;
  int get playbackTotal => _playbackTotal;
  String get playbackCurrentCmd => _playbackCurrentCmd;
  double get playbackProgress =>
      _playbackTotal > 0 ? _playbackIndex / _playbackTotal : 0;

  List<RecordedPath> get paths => List.unmodifiable(_paths);

  // ─────────────────────────────────────────────
  //  Initialization
  // ─────────────────────────────────────────────

  PathRecorderService() {
    _loadFromStorage();
  }

  // ─────────────────────────────────────────────
  //  Recording
  // ─────────────────────────────────────────────

  void startRecording() {
    _isRecording = true;
    _recordingStartTime = DateTime.now();
    _lastCommandTime = _recordingStartTime;
    _recordingBuffer = [];
    _lastRecordedCommand = null;
    notifyListeners();
  }

  /// Record a command. Automatically computes delay from the previous command.
  /// Deduplicates identical commands within 100ms to avoid joystick spam.
  void recordCommand(String cmd) {
    if (!_isRecording) return;

    final now = DateTime.now();
    final delayMs = _lastCommandTime != null
        ? now.difference(_lastCommandTime!).inMilliseconds
        : 0;

    // Deduplicate: skip identical commands within 100ms
    if (cmd == _lastRecordedCommand && delayMs < 100) return;

    _recordingBuffer.add(PathCommand(command: cmd, delayMs: delayMs));
    _lastCommandTime = now;
    _lastRecordedCommand = cmd;
    notifyListeners();
  }

  /// Stop recording and return the recorded path (without saving yet).
  RecordedPath? stopRecording(String name) {
    if (!_isRecording) return null;
    _isRecording = false;

    if (_recordingBuffer.isEmpty) {
      notifyListeners();
      return null;
    }

    // Ensure the path ends with a STOP command
    if (_recordingBuffer.last.command != 'S') {
      final now = DateTime.now();
      final delayMs = _lastCommandTime != null
          ? now.difference(_lastCommandTime!).inMilliseconds
          : 0;
      _recordingBuffer.add(PathCommand(command: 'S', delayMs: delayMs));
    }

    final path = RecordedPath(
      name: name,
      createdAt: _recordingStartTime ?? DateTime.now(),
      commands: List.from(_recordingBuffer),
    );

    _recordingBuffer = [];
    _recordingStartTime = null;
    _lastCommandTime = null;
    _lastRecordedCommand = null;
    notifyListeners();
    return path;
  }

  void cancelRecording() {
    _isRecording = false;
    _recordingBuffer = [];
    _recordingStartTime = null;
    _lastCommandTime = null;
    _lastRecordedCommand = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  Playback
  // ─────────────────────────────────────────────

  void startPlayback(RecordedPath path, ProtocolService proto) {
    if (_isPlaying) stopPlayback();

    _isPlaying = true;
    _playbackIndex = 0;
    _playbackTotal = path.commands.length;
    _playbackCurrentCmd = '';
    _playbackProto = proto;
    notifyListeners();

    // Ensure manual mode first
    proto.setModeManual();

    // Start executing commands sequentially
    _executeNextCommand(path.commands);
  }

  void _executeNextCommand(List<PathCommand> commands) {
    if (!_isPlaying || _playbackIndex >= commands.length) {
      // Playback finished
      _isPlaying = false;
      _playbackCurrentCmd = '';
      _playbackProto = null;
      notifyListeners();
      return;
    }

    final cmd = commands[_playbackIndex];

    // Wait the specified delay, then execute the command
    _playbackTimer = Timer(Duration(milliseconds: cmd.delayMs), () {
      if (!_isPlaying) return;

      _playbackCurrentCmd = cmd.command;
      _playbackProto?.sendRaw(cmd.command);
      _playbackIndex++;
      notifyListeners();

      // Schedule next command
      _executeNextCommand(commands);
    });
  }

  void stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;

    // Send stop command to ensure AGV stops
    _playbackProto?.stop();

    _isPlaying = false;
    _playbackIndex = 0;
    _playbackTotal = 0;
    _playbackCurrentCmd = '';
    _playbackProto = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  Persistence (SharedPreferences)
  // ─────────────────────────────────────────────

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        _paths = list
            .map((e) => RecordedPath.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_paths.map((p) => p.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (_) {}
  }

  Future<void> savePath(RecordedPath path) async {
    _paths.add(path);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> deletePath(int index) async {
    if (index < 0 || index >= _paths.length) return;
    _paths.removeAt(index);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> renamePath(int index, String newName) async {
    if (index < 0 || index >= _paths.length) return;
    final old = _paths[index];
    _paths[index] = RecordedPath(
      name: newName,
      createdAt: old.createdAt,
      commands: old.commands,
    );
    notifyListeners();
    await _saveToStorage();
  }

  // ─────────────────────────────────────────────
  //  Export
  // ─────────────────────────────────────────────

  /// Export a single path to a JSON file. Returns the file path on success.
  Future<String?> exportPath(RecordedPath path) async {
    try {
      final dir = await _getExportDirectory();
      if (dir == null) return null;

      final safeName = path.name.replaceAll(RegExp(r'[^\w\u4e00-\u9fff]'), '_');
      final fileName = 'agv_path_$safeName.json';
      final file = File('${dir.path}/$fileName');

      final data = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'paths': [path.toJson()],
      };

      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Export all saved paths to a single JSON file. Returns the file path.
  Future<String?> exportAllPaths() async {
    if (_paths.isEmpty) return null;

    try {
      final dir = await _getExportDirectory();
      if (dir == null) return null;

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'agv_paths_all_$timestamp.json';
      final file = File('${dir.path}/$fileName');

      final data = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'paths': _paths.map((p) => p.toJson()).toList(),
      };

      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _getExportDirectory() async {
    try {
      // Try to get the Downloads directory on Android
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        // Navigate up to storage root and use Download folder
        final parts = dir.path.split('/');
        final androidIdx = parts.indexOf('Android');
        if (androidIdx > 0) {
          final downloadDir =
              Directory('${parts.sublist(0, androidIdx).join('/')}/Download');
          if (await downloadDir.exists()) return downloadDir;
        }
        return dir;
      }
      // Fallback to app documents directory
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  //  Import
  // ─────────────────────────────────────────────

  /// Let user pick a JSON file and import paths from it.
  /// Returns the number of paths imported, or -1 on error.
  Future<int> importPaths() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return 0;

      final filePath = result.files.single.path;
      if (filePath == null) return 0;

      return await importFromFile(filePath);
    } catch (_) {
      return -1;
    }
  }

  /// Import paths from a specific file path.
  /// Returns the number of paths imported, or -1 on error.
  Future<int> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return -1;

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Validate version
      final version = (data['version'] as num?)?.toInt() ?? 0;
      if (version < 1) return -1;

      final pathsList = data['paths'] as List?;
      if (pathsList == null || pathsList.isEmpty) return 0;

      int imported = 0;
      for (final pathJson in pathsList) {
        try {
          final path =
              RecordedPath.fromJson(pathJson as Map<String, dynamic>);

          // Handle name conflicts by appending a number
          String finalName = path.name;
          int suffix = 1;
          while (_paths.any((p) => p.name == finalName)) {
            finalName = '${path.name}_$suffix';
            suffix++;
          }

          _paths.add(RecordedPath(
            name: finalName,
            createdAt: path.createdAt,
            commands: path.commands,
          ));
          imported++;
        } catch (_) {
          // Skip invalid path entries
        }
      }

      if (imported > 0) {
        notifyListeners();
        await _saveToStorage();
      }
      return imported;
    } catch (_) {
      return -1;
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
