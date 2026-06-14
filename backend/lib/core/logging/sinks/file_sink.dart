import 'dart:convert';
import 'dart:io';

import 'package:pokegrading_logging/pokegrading_logging.dart';

/// Appends [LogEvent] records as JSON Lines to daily log files.
class FileLogSink {
  final String logDir;

  const FileLogSink({required this.logDir});

  void write(LogEvent event) {
    final directory = Directory(logDir);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final date = event.timestamp.toUtc();
    final fileName =
        'app-${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}.jsonl';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    file.writeAsStringSync(
      '${jsonEncode(event.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}
