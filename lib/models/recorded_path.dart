/// Data models for path recording and playback.

/// A single recorded command with its delay from the previous command.
class PathCommand {
  /// Raw command text, e.g. "F:500", "L:400,100", "S"
  final String command;

  /// Delay in milliseconds since the previous command (0 for the first command).
  final int delayMs;

  PathCommand({required this.command, required this.delayMs});

  Map<String, dynamic> toJson() => {
        'command': command,
        'delayMs': delayMs,
      };

  factory PathCommand.fromJson(Map<String, dynamic> json) => PathCommand(
        command: json['command'] as String,
        delayMs: (json['delayMs'] as num).toInt(),
      );
}

/// A complete recorded path consisting of a named sequence of commands.
class RecordedPath {
  /// User-assigned name for this path.
  final String name;

  /// When this path was recorded.
  final DateTime createdAt;

  /// The ordered list of commands that make up this path.
  final List<PathCommand> commands;

  RecordedPath({
    required this.name,
    required this.createdAt,
    required this.commands,
  });

  /// Total duration of this path in milliseconds.
  int get totalDurationMs =>
      commands.fold<int>(0, (sum, c) => sum + c.delayMs);

  /// Number of motion commands (excluding STOP).
  int get motionCommandCount =>
      commands.where((c) => c.command != 'S').length;

  Map<String, dynamic> toJson() => {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'commands': commands.map((c) => c.toJson()).toList(),
      };

  factory RecordedPath.fromJson(Map<String, dynamic> json) => RecordedPath(
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        commands: (json['commands'] as List)
            .map((c) => PathCommand.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
