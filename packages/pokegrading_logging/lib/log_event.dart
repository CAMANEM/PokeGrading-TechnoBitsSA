import 'log_categories.dart';
import 'redaction.dart';

/// Canonical structured log event emitted by all PokéGrading layers.
class LogEvent {
  final DateTime timestamp;
  final String level;
  final LogCategory category;
  final String logger;
  final String? correlationId;
  final String message;
  final Map<String, dynamic>? context;
  final String? error;
  final String? stackTrace;

  const LogEvent({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.logger,
    required this.message,
    this.correlationId,
    this.context,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level,
      'category': category.value,
      'logger': logger,
      'message': message,
    };

    if (correlationId != null) {
      json['correlation_id'] = correlationId;
    }

    final scrubbedContext = LogRedaction.scrubMap(context);
    if (scrubbedContext != null && scrubbedContext.isNotEmpty) {
      json['context'] = scrubbedContext;
    }

    if (error != null) {
      json['error'] = error;
    }

    if (stackTrace != null) {
      json['stack_trace'] = stackTrace;
    }

    return json;
  }
}
