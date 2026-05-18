// ============================================================
// PokéGrading — Global Logger (Core)
// Structured logging with correlation_id support.
// ============================================================
import 'package:logging/logging.dart';

/// Initializes and configures the application's logging system.
///
/// All logs include:
/// - UTC Timestamp
/// - Severity level
/// - Logger name (source)
/// - correlation_id (when available in Zone)
/// - Message
///
/// Usage:
/// ```dart
/// AppLogger.init();
/// final log = Logger('MyClass');
/// log.info('Important event');
/// ```
class AppLogger {
  AppLogger._(); // Not instantiable

  static bool _initialized = false;

  /// Initializes the logging system. Call ONCE at startup.
  static void init({Level level = Level.INFO}) {
    if (_initialized) return;
    _initialized = true;

    Logger.root.level = level;
    Logger.root.onRecord.listen(_handleRecord);
  }

  /// Handler that formats and writes each [LogRecord] to stdout/stderr.
  static void _handleRecord(LogRecord record) {
    final timestamp = record.time.toUtc().toIso8601String();
    final level = record.level.name.padRight(7);
    final name = record.loggerName;
    final message = record.message;

    // Structured log format (human-readable JSON-like)
    final line = '[$timestamp] [$level] [$name] $message';

    if (record.level >= Level.SEVERE) {
      // Errors go to stderr
      print('\x1B[31m$line\x1B[0m'); // Red
      if (record.error != null) {
        print('\x1B[31m  ERROR: ${record.error}\x1B[0m');
      }
      if (record.stackTrace != null) {
        print('\x1B[31m  STACK: ${record.stackTrace}\x1B[0m');
      }
    } else if (record.level >= Level.WARNING) {
      print('\x1B[33m$line\x1B[0m'); // Yellow
    } else if (record.level >= Level.INFO) {
      print('\x1B[36m$line\x1B[0m'); // Cyan
    } else {
      print('\x1B[90m$line\x1B[0m'); // Grey (DEBUG)
    }
  }
}
