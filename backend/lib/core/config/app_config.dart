/// @file
/// @brief

// ============================================================
// PokéGrading — Application Configuration (Core)
// Reads environment variables and exposes them in a typed way.
// ============================================================
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';

import 'logging_config.dart';

/// Immutable configuration class that centralizes all
/// application parameters read from environment variables.
///
/// Principle: Single Source of Truth for configuration.
class AppConfig {
  final String environment;
  final String version;
  final String host;
  final int port;
  final Level logLevel;
  final LoggingConfig logging;
  final DatabaseConfig database;
  final MongoConfig mongo;
  final EmailConfig email;
  final bool useMockRepositories;
  final B2bConfig b2b;

  const AppConfig(
      {required this.environment,
      required this.version,
      required this.host,
      required this.port,
      required this.logLevel,
      required this.logging,
      required this.database,
      required this.mongo,
      required this.email,
      required this.useMockRepositories,
      required this.b2b});

  /// Builds [AppConfig] from environment variables.
  factory AppConfig.fromEnv(DotEnv env) {
    final environment = env['APP_ENV'] ?? 'development';
    final useMock =
        (env['USE_MOCK_REPOSITORIES'] ?? 'true').toLowerCase() == 'true';

    return AppConfig(
        environment: environment,
        version: env['APP_VERSION'] ?? '0.1.0',
        host: env['BACKEND_HOST'] ?? '0.0.0.0',
        port: int.tryParse(env['BACKEND_PORT'] ?? '') ?? 8080,
        logLevel: _parseLogLevel(env['BACKEND_LOG_LEVEL'] ?? 'info'),
        logging: LoggingConfig.fromEnv(env),
        database: DatabaseConfig.fromEnv(env),
        mongo: MongoConfig.fromEnv(env),
        email: EmailConfig.fromEnv(env),
        useMockRepositories: useMock,
        b2b: B2bConfig.fromEnv(env));
  }

  /// Are we in development mode?
  bool get isDevelopment => environment == 'development';

  /// Are we in production mode?
  bool get isProduction => environment == 'production';

  static Level _parseLogLevel(String level) {
    return switch (level.toLowerCase()) {
      'debug' => Level.FINE,
      'info' => Level.INFO,
      'warning' => Level.WARNING,
      'error' => Level.SEVERE,
      _ => Level.INFO,
    };
  }
}

/// PostgreSQL database connection configuration.
class DatabaseConfig {
  final String host;
  final int port;
  final String name;
  final String user;
  final String password;
  final int maxConnections;
  final Duration connectionTimeout;

  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.name,
    required this.user,
    required this.password,
    required this.maxConnections,
    required this.connectionTimeout,
  });

  factory DatabaseConfig.fromEnv(DotEnv env) {
    return DatabaseConfig(
      host: (env['DB_HOST'] ?? 'localhost').trim(),
      port: int.tryParse(env['DB_PORT']?.trim() ?? '') ?? 5432,
      name: (env['DB_NAME'] ?? 'pokegrading').trim(),
      user: (env['DB_USER'] ?? 'pokegrading_user').trim(),
      password: (env['DB_PASSWORD'] ?? 'pokegrading_secret').trim(),
      maxConnections:
          int.tryParse(env['DB_MAX_CONNECTIONS']?.trim() ?? '') ?? 10,
      connectionTimeout: Duration(
        seconds: int.tryParse(env['DB_CONNECTION_TIMEOUT']?.trim() ?? '') ?? 30,
      ),
    );
  }

  /// DSN (Data Source Name) for the PostgreSQL connection.
  String get dsn => 'postgresql://$user:$password@$host:$port/$name';
}

/// MongoDB connection configuration for image storage (GridFS).
class MongoConfig {
  final String uri;
  final String dbName;

  const MongoConfig({
    required this.uri,
    required this.dbName,
  });

  factory MongoConfig.fromEnv(DotEnv env) {
    return MongoConfig(
      uri: (env['MONGO_URI'] ?? 'mongodb://localhost:27017/pokegrading_images')
          .trim(),
      dbName: (env['MONGO_DB_NAME'] ?? 'pokegrading_images').trim(),
    );
  }
}

/// SMTP / email delivery configuration.
class EmailConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String fromEmail;
  final String fromName;
  final bool useSsl;

  const EmailConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromEmail,
    required this.fromName,
    required this.useSsl,
  });

  factory EmailConfig.fromEnv(DotEnv env) {
    return EmailConfig(
      host: env['SMTP_HOST'] ?? '',
      port: int.tryParse(env['SMTP_PORT'] ?? '') ?? 587,
      username: env['SMTP_USERNAME'] ?? '',
      password: env['SMTP_PASSWORD'] ?? '',
      fromEmail: env['SMTP_FROM_EMAIL'] ?? '',
      fromName: env['SMTP_FROM_NAME'] ?? 'PokéGrading',
      useSsl: (env['SMTP_USE_SSL'] ?? 'false').toLowerCase() == 'true',
    );
  }

  bool get isConfigured =>
      host.isNotEmpty &&
      username.isNotEmpty &&
      password.isNotEmpty &&
      fromEmail.isNotEmpty;
}

/// B2B API configuration.
class B2bConfig {
  final int rateLimitCardsPerMonth;
  final int idempotencyTtlSeconds;
  final int maxCardsPerRequest;
  final String apiKeyPepper;
  final String devApiKey;

  const B2bConfig({
    required this.rateLimitCardsPerMonth,
    required this.idempotencyTtlSeconds,
    required this.maxCardsPerRequest,
    required this.apiKeyPepper,
    required this.devApiKey,
  });

  factory B2bConfig.fromEnv(DotEnv env) {
    return B2bConfig(
      rateLimitCardsPerMonth:
          int.tryParse(env['B2B_RATE_LIMIT_CARDS_PER_MONTH'] ?? '') ?? 10000,
      idempotencyTtlSeconds:
          int.tryParse(env['B2B_IDEMPOTENCY_TTL_SECONDS'] ?? '') ?? 86400,
      maxCardsPerRequest:
          int.tryParse(env['B2B_MAX_CARDS_PER_REQUEST'] ?? '') ?? 100,
      apiKeyPepper: env['B2B_API_KEY_PEPPER'] ?? '',
      devApiKey: env['B2B_DEV_API_KEY'] ?? 'pk_test_b2b_dev_key',
    );
  }
}
