/// @file
/// @brief

// ============================================================
// PokéGrading — Global Logger (Core)
// Structured JSON logging with correlation_id support.
// ============================================================
import 'package:logging/logging.dart';
import 'package:pokegrading_logging/pokegrading_logging.dart';

import '../config/logging_config.dart';
import 'sinks/app_insights_sink.dart';
import 'sinks/console_sink.dart';
import 'sinks/file_sink.dart';

/// Initializes and configures the application's logging system.
class AppLogger {
  AppLogger._();

  static bool _initialized = false;
  static late ConsoleLogSink _consoleSink;
  static FileLogSink? _fileSink;
  static AppInsightsLogSink? _appInsightsSink;

  /// Initializes the logging system. Call ONCE at startup.
  static void init({
    required Level level,
    required LoggingConfig config,
  }) {
    if (_initialized) return;
    _initialized = true;

    _consoleSink = ConsoleLogSink(pretty: config.format == LogFormat.pretty);
    if (config.fileEnabled) {
      _fileSink = FileLogSink(logDir: config.logDir);
    }

    if (config.appInsightsEnabled) {
      final insightsConfig =
          AppInsightsConfig.parse(config.appInsightsConnectionString);
      if (insightsConfig != null) {
        _appInsightsSink = AppInsightsLogSink(config: insightsConfig);
      }
    }

    Logger.root.level = level;
    Logger.root.onRecord.listen(_handleRecord);
  }

  /// Emits a structured [LogEvent] through all configured sinks.
  static void emit(LogEvent event) {
    _consoleSink.write(event);
    _fileSink?.write(event);
    _appInsightsSink?.write(event);
  }

  static void info(
    String logger,
    String message, {
    LogCategory category = LogCategory.operational,
    Map<String, dynamic>? context,
  }) {
    emit(
      LogEvent(
        timestamp: DateTime.now().toUtc(),
        level: 'INFO',
        category: category,
        logger: logger,
        correlationId: CorrelationContext.current,
        message: message,
        context: context,
      ),
    );
  }

  static void warning(
    String logger,
    String message, {
    LogCategory category = LogCategory.operational,
    Map<String, dynamic>? context,
  }) {
    emit(
      LogEvent(
        timestamp: DateTime.now().toUtc(),
        level: 'WARNING',
        category: category,
        logger: logger,
        correlationId: CorrelationContext.current,
        message: message,
        context: context,
      ),
    );
  }

  static void error(
    String logger,
    String message, {
    LogCategory category = LogCategory.operational,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    emit(
      LogEvent(
        timestamp: DateTime.now().toUtc(),
        level: 'SEVERE',
        category: category,
        logger: logger,
        correlationId: CorrelationContext.current,
        message: message,
        context: context,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      ),
    );
  }

  static void audit(
    String logger,
    String eventType, {
    required String result,
    Map<String, dynamic>? context,
  }) {
    emit(
      LogEvent(
        timestamp: DateTime.now().toUtc(),
        level: 'INFO',
        category: LogCategory.audit,
        logger: logger,
        correlationId: CorrelationContext.current,
        message: eventType,
        context: {
          'event': eventType,
          'result': result,
          if (context != null) ...context,
        },
      ),
    );
  }

  static void metric(
    String logger,
    String eventType, {
    required Map<String, dynamic> context,
  }) {
    emit(
      LogEvent(
        timestamp: DateTime.now().toUtc(),
        level: 'INFO',
        category: LogCategory.metric,
        logger: logger,
        correlationId: CorrelationContext.current,
        message: eventType,
        context: {
          'event': eventType,
          ...context,
        },
      ),
    );
  }

  static void grading(
    String logger,
    String message, {
    Map<String, dynamic>? context,
  }) {
    emit(
      LogEvent(
        timestamp: DateTime.now().toUtc(),
        level: 'INFO',
        category: LogCategory.grading,
        logger: logger,
        correlationId: CorrelationContext.current,
        message: message,
        context: context,
      ),
    );
  }

  static void _handleRecord(LogRecord record) {
    emit(
      LogEvent(
        timestamp: record.time.toUtc(),
        level: record.level.name,
        category: LogCategory.operational,
        logger: record.loggerName,
        correlationId: CorrelationContext.current,
        message: record.message,
        error: record.error?.toString(),
        stackTrace: record.stackTrace?.toString(),
      ),
    );
  }

  /// Flushes and disposes all logging sinks.
  /// Call this on graceful shutdown (e.g., SIGINT) to drain pending writes.
  static void dispose() {
    _fileSink?.dispose();
    _appInsightsSink?.close();
  }
}
