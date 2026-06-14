import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pokegrading_logging/pokegrading_logging.dart';

import '../config/app_config.dart';

/// Reports client-side errors using the shared structured log contract.
class ClientLogReporter {
  ClientLogReporter._();

  static final http.Client _client = http.Client();

  static void reportError({
    required String logger,
    required String correlationId,
    required String message,
    Map<String, dynamic>? context,
  }) {
    final event = LogEvent(
      timestamp: DateTime.now().toUtc(),
      level: 'SEVERE',
      category: LogCategory.operational,
      logger: logger,
      correlationId: correlationId,
      message: message,
      context: context,
    );

    if (kDebugMode) {
      debugPrint(jsonEncode(event.toJson()));
    }

    unawaited(_postToBackend(event));
  }

  static Future<void> _postToBackend(LogEvent event) async {
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/observability/client-errors');
      await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          if (event.correlationId != null)
            'X-Correlation-ID': event.correlationId!,
        },
        body: jsonEncode({
          'logger': event.logger,
          'message': event.message,
          'context': event.context,
        }),
      );
    } catch (_) {
      // Client telemetry must not break the UI flow.
    }
  }
}
