/// @file
/// @brief

import 'package:dotenv/dotenv.dart';

enum LogFormat {
  json,
  pretty,
}

/// File, console, and Application Insights logging configuration.
class LoggingConfig {
  final String logDir;
  final bool fileEnabled;
  final LogFormat format;
  final int retentionDays;
  final bool appInsightsEnabled;
  final String? appInsightsConnectionString;

  const LoggingConfig({
    required this.logDir,
    required this.fileEnabled,
    required this.format,
    required this.retentionDays,
    required this.appInsightsEnabled,
    this.appInsightsConnectionString,
  });

  factory LoggingConfig.fromEnv(DotEnv env) {
    final formatRaw = (env['LOG_FORMAT'] ?? 'json').toLowerCase();
    return LoggingConfig(
      logDir: env['LOG_DIR'] ?? './logs',
      fileEnabled: (env['LOG_FILE_ENABLED'] ?? 'false').toLowerCase() == 'true',
      format: formatRaw == 'pretty' ? LogFormat.pretty : LogFormat.json,
      retentionDays: int.tryParse(env['LOG_RETENTION_DAYS'] ?? '') ?? 30,
      appInsightsEnabled:
          (env['APPINSIGHTS_ENABLED'] ?? 'false').toLowerCase() == 'true',
      appInsightsConnectionString: env['APPINSIGHTS_CONNECTION_STRING'],
    );
  }
}
