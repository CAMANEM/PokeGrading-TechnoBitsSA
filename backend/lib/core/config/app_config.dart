// ============================================================
// PokéGrading — Configuración de la Aplicación (Core)
// Lee las variables de entorno y las expone de forma tipada.
// ============================================================
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';

/// Clase de configuración inmutable que centraliza todos los
/// parámetros de la aplicación leídos desde variables de entorno.
///
/// Principio: Single Source of Truth para la configuración.
class AppConfig {
  final String environment;
  final String version;
  final String host;
  final int port;
  final Level logLevel;
  final DatabaseConfig database;

  const AppConfig({
    required this.environment,
    required this.version,
    required this.host,
    required this.port,
    required this.logLevel,
    required this.database,
  });

  /// Construye [AppConfig] a partir de variables de entorno.
  factory AppConfig.fromEnv(DotEnv env) {
    final environment = env['APP_ENV'] ?? 'development';

    return AppConfig(
      environment: environment,
      version: env['APP_VERSION'] ?? '0.1.0',
      host: env['BACKEND_HOST'] ?? '0.0.0.0',
      port: int.tryParse(env['BACKEND_PORT'] ?? '') ?? 8080,
      logLevel: _parseLogLevel(env['BACKEND_LOG_LEVEL'] ?? 'info'),
      database: DatabaseConfig.fromEnv(env),
    );
  }

  /// ¿Estamos en modo desarrollo?
  bool get isDevelopment => environment == 'development';

  /// ¿Estamos en producción?
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

/// Configuración de conexión a la base de datos PostgreSQL.
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
      host: env['DB_HOST'] ?? 'localhost',
      port: int.tryParse(env['DB_PORT'] ?? '') ?? 5432,
      name: env['DB_NAME'] ?? 'pokegrading',
      user: env['DB_USER'] ?? 'pokegrading_user',
      password: env['DB_PASSWORD'] ?? 'pokegrading_secret',
      maxConnections: int.tryParse(env['DB_MAX_CONNECTIONS'] ?? '') ?? 10,
      connectionTimeout: Duration(
        seconds: int.tryParse(env['DB_CONNECTION_TIMEOUT'] ?? '') ?? 30,
      ),
    );
  }

  /// DSN (Data Source Name) para la conexión PostgreSQL.
  String get dsn =>
      'postgresql://$user:$password@$host:$port/$name';
}
