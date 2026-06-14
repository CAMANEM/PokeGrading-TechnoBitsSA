import 'dart:convert';
import 'dart:io';

import 'package:pokegrading_logging/pokegrading_logging.dart';

/// Writes [LogEvent] records as JSON Lines to stdout/stderr.
class ConsoleLogSink {
  final bool pretty;

  const ConsoleLogSink({this.pretty = false});

  void write(LogEvent event) {
    final line = pretty ? _prettyLine(event) : jsonEncode(event.toJson());
    if (_isErrorLevel(event.level)) {
      stderr.writeln(line);
    } else {
      stdout.writeln(line);
    }
  }

  bool _isErrorLevel(String level) {
    return level == 'SEVERE' || level == 'SHOUT';
  }

  String _prettyLine(LogEvent event) {
    final json = event.toJson();
    final timestamp = json['timestamp'];
    final level = json['level'];
    final category = json['category'];
    final logger = json['logger'];
    final correlationId = json['correlation_id'];
    final correlationSuffix =
        correlationId == null ? '' : ' correlation_id=$correlationId';

    final buffer = StringBuffer(
      '[$timestamp] [$level] [$category] [$logger]$correlationSuffix '
      '${event.message}',
    );

    final context = json['context'];
    if (context is Map && context.isNotEmpty) {
      buffer.write('\n  context: ${jsonEncode(context)}');
    }

    if (json['error'] != null) {
      buffer.write('\n  error: ${json['error']}');
    }

    return buffer.toString();
  }
}
