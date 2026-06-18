import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:pokegrading_logging/pokegrading_logging.dart';

/// Appends [LogEvent] records as JSON Lines to daily log files.
///
/// Uses an internal buffer to batch disk writes for performance:
/// - Buffered events are flushed every 1 second or when the buffer reaches
///   [maxBufferSize] entries (whichever comes first).
/// - The [flush] method can be called explicitly on shutdown to drain
///   remaining events.
class FileLogSink {
  final String logDir;
  final int maxBufferSize;

  final Queue<_LogEntry> _buffer = Queue();
  Timer? _flushTimer;
  bool _disposed = false;

  FileLogSink({required this.logDir, this.maxBufferSize = 100}) {
    _flushTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _flushBuffer(),
    );
  }

  void write(LogEvent event) {
    if (_disposed) return;

    final date = event.timestamp.toUtc();
    final fileName =
        'app-${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}.jsonl';
    final line = '${jsonEncode(event.toJson())}\n';

    _buffer.add(_LogEntry(fileName: fileName, line: line));

    if (_buffer.length >= maxBufferSize) {
      _flushBuffer();
    }
  }

  /// Flushes all buffered entries to disk.
  /// Call this on graceful shutdown to avoid data loss.
  void flush() {
    _flushBuffer();
  }

  void _flushBuffer() {
    if (_buffer.isEmpty) return;

    final directory = Directory(logDir);
    if (!directory.existsSync()) {
      try {
        directory.createSync(recursive: true);
      } catch (_) {
        return;
      }
    }

    final batches = <String, List<String>>{};
    while (_buffer.isNotEmpty) {
      final entry = _buffer.removeFirst();
      batches.putIfAbsent(entry.fileName, () => []).add(entry.line);
    }

    for (final entry in batches.entries) {
      final file =
          File('${directory.path}${Platform.pathSeparator}${entry.key}');
      try {
        final content = entry.value.join();
        file.writeAsStringSync(content, mode: FileMode.append, flush: false);
      } catch (_) {
        // If a write fails, re-queue entries for the next flush cycle.
        for (final line in entry.value) {
          _buffer.addFirst(
            _LogEntry(fileName: entry.key, line: line),
          );
        }
        break;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushBuffer();
  }
}

class _LogEntry {
  final String fileName;
  final String line;

  const _LogEntry({required this.fileName, required this.line});
}
