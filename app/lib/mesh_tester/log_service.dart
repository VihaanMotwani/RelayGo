import 'dart:async';

/// Singleton log collector for the mesh tester UI.
///
/// All mesh services push timestamped log entries here, and the UI
/// listens to the stream for live updates.
class LogService {
  LogService._();
  static final LogService instance = LogService._();

  final List<LogEntry> _entries = [];
  final _controller = StreamController<LogEntry>.broadcast();

  /// Live stream of new log entries.
  Stream<LogEntry> get onNewEntry => _controller.stream;

  /// All entries collected so far.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Add a log entry with a tag and message.
  void log(String tag, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    _controller.add(entry);
  }

  /// Convenience methods for common tags.
  void central(String msg) => log('BLE-CENTRAL', msg);
  void peripheral(String msg) => log('BLE-PERIPH', msg);
  void store(String msg) => log('STORE', msg);
  void mesh(String msg) => log('MESH', msg);
  void sync(String msg) => log('SYNC', msg);
  void info(String msg) => log('INFO', msg);
  void error(String msg) => log('ERROR', msg);

  /// Clear all entries.
  void clear() {
    _entries.clear();
  }

  void dispose() {
    _controller.close();
  }
}

class LogEntry {
  final DateTime timestamp;
  final String tag;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.tag,
    required this.message,
  });

  /// Formatted string for display.
  String get formatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms  [$tag] $message';
  }
}
