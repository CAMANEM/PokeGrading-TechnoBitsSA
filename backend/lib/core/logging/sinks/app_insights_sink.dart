import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokegrading_logging/pokegrading_logging.dart';

/// Parsed Azure Application Insights connection string.
class AppInsightsConfig {
  final String instrumentationKey;
  final Uri trackEndpoint;

  const AppInsightsConfig({
    required this.instrumentationKey,
    required this.trackEndpoint,
  });

  static AppInsightsConfig? parse(String? connectionString) {
    if (connectionString == null || connectionString.trim().isEmpty) {
      return null;
    }

    var instrumentationKey = '';
    var ingestionEndpoint = '';

    for (final part in connectionString.split(';')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('InstrumentationKey=')) {
        instrumentationKey = trimmed.substring('InstrumentationKey='.length);
      } else if (trimmed.startsWith('IngestionEndpoint=')) {
        ingestionEndpoint = trimmed.substring('IngestionEndpoint='.length);
      }
    }

    if (instrumentationKey.isEmpty) return null;

    final base = ingestionEndpoint.isNotEmpty
        ? ingestionEndpoint
        : 'https://dc.services.visualstudio.com';
    final trackUri = Uri.parse(base.endsWith('/') ? base : '$base/').resolve(
      'v2/track',
    );

    return AppInsightsConfig(
      instrumentationKey: instrumentationKey,
      trackEndpoint: trackUri,
    );
  }
}

/// Sends [LogEvent] records to Azure Application Insights Track API.
class AppInsightsLogSink {
  final AppInsightsConfig config;
  final http.Client _client;

  AppInsightsLogSink({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void write(LogEvent event) {
    unawaited(_send(event));
  }

  Future<void> _send(LogEvent event) async {
    try {
      final payload = jsonEncode(_toTrackEnvelope(event));
      await _client.post(
        config.trackEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
    } catch (error) {
      // Telemetry must not break the application, but we log locally.
      // ignore: avoid_print
      print('[AppInsights] Failed to send telemetry: $error');
    }
  }

  Map<String, dynamic> _toTrackEnvelope(LogEvent event) {
    final properties = <String, String>{
      'category': event.category.value,
      'logger': event.logger,
      'level': event.level,
      if (event.correlationId != null) 'correlation_id': event.correlationId!,
    };

    final context = event.context;
    if (context != null) {
      for (final entry in context.entries) {
        properties[entry.key] = entry.value.toString();
      }
    }

    if (event.error != null) {
      properties['error'] = event.error!;
    }

    return {
      'name': 'Microsoft.ApplicationInsights.Message',
      'time': event.timestamp.toUtc().toIso8601String(),
      'iKey': config.instrumentationKey,
      'tags': {
        if (event.correlationId != null)
          'ai.operation.id': event.correlationId,
      },
      'data': {
        'baseType': 'MessageData',
        'baseData': {
          'ver': 2,
          'message': event.message,
          'severityLevel': _severityLevel(event.level),
          'properties': properties,
        },
      },
    };
  }

  int _severityLevel(String level) {
    return switch (level.toUpperCase()) {
      'SEVERE' || 'SHOUT' => 3,
      'WARNING' => 2,
      'FINE' || 'FINER' || 'FINEST' || 'CONFIG' => 0,
      _ => 1,
    };
  }

  void close() {
    _client.close();
  }
}
