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
  final ThresholdConfig thresholds;

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
      required this.b2b,
      required this.thresholds});

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
        b2b: B2bConfig.fromEnv(env),
        thresholds: ThresholdConfig.fromEnv(env));
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

/// Centralized thresholds for search, IQS, grading, and validation.
///
/// All values are read from environment variables with sane defaults
/// so the system works out-of-the-box without extra configuration.
class ThresholdConfig {
  // ─── Search ──────────────────────────────────────────────
  final double searchAcceptedConfidence;

  // ─── Image Quality Service (basic) ───────────────────────
  final int iqsAcceptedThreshold;
  final double iqsSharpnessPerfectVariance;
  final double iqsBrightnessMin;
  final double iqsBrightnessMax;

  // ─── Enhanced IQS ────────────────────────────────────────
  final double enhTenengradPerfectMagnitude;
  final double enhEntropyPerfectValue;
  final double enhEntropyMinValue;
  final double enhContrastIdealLower;
  final double enhContrastIdealUpper;
  final double enhContrastLowThreshold;
  final double enhContrastHighThreshold;
  final double enhLaplacianSharpnessWeight;
  final double enhTenengradSharpnessWeight;
  final double enhSharpnessOverallWeight;
  final double enhBrightnessOverallWeight;
  final double enhEntropyOverallWeight;
  final double enhContrastOverallWeight;

  // ─── Grading Weights ────────────────────────────────────
  final double gradingCenteringWeight;
  final double gradingCornersWeight;
  final double gradingEdgesWeight;
  final double gradingSurfaceWeight;

  // ─── Grading Confidence ─────────────────────────────────
  final double gradingHighConfidenceStdDev;
  final double gradingLowConfidenceStdDev;

  // ─── Evaluation Review ──────────────────────────────────
  final double evalReviewConfidenceThreshold;
  final double evalReviewGapThreshold;

  // ─── Validation Limits ──────────────────────────────────
  final int validationMaxSetLength;
  final int validationMaxEditionLength;
  final int validationMaxLanguageLength;
  final int validationMaxFinishLength;
  final int validationMaxAuthorLength;
  final int validationMinImageBase64Bytes;
  final int validationHpMin;
  final int validationHpMax;
  final int validationYearMin;

  const ThresholdConfig({
    this.searchAcceptedConfidence = 90.0,
    this.iqsAcceptedThreshold = 50,
    this.iqsSharpnessPerfectVariance = 150.0,
    this.iqsBrightnessMin = 80.0,
    this.iqsBrightnessMax = 180.0,
    this.enhTenengradPerfectMagnitude = 500.0,
    this.enhEntropyPerfectValue = 7.0,
    this.enhEntropyMinValue = 3.0,
    this.enhContrastIdealLower = 0.2,
    this.enhContrastIdealUpper = 0.6,
    this.enhContrastLowThreshold = 0.1,
    this.enhContrastHighThreshold = 0.8,
    this.enhLaplacianSharpnessWeight = 0.6,
    this.enhTenengradSharpnessWeight = 0.4,
    this.enhSharpnessOverallWeight = 0.35,
    this.enhBrightnessOverallWeight = 0.25,
    this.enhEntropyOverallWeight = 0.20,
    this.enhContrastOverallWeight = 0.20,
    this.gradingCenteringWeight = 0.40,
    this.gradingCornersWeight = 0.20,
    this.gradingEdgesWeight = 0.20,
    this.gradingSurfaceWeight = 0.20,
    this.gradingHighConfidenceStdDev = 0.5,
    this.gradingLowConfidenceStdDev = 2.0,
    this.evalReviewConfidenceThreshold = 0.7,
    this.evalReviewGapThreshold = 2.0,
    this.validationMaxSetLength = 60,
    this.validationMaxEditionLength = 40,
    this.validationMaxLanguageLength = 30,
    this.validationMaxFinishLength = 30,
    this.validationMaxAuthorLength = 100,
    this.validationMinImageBase64Bytes = 5 * 1024,
    this.validationHpMin = 0,
    this.validationHpMax = 2000,
    this.validationYearMin = 1950,
  });

  /// Builds [ThresholdConfig] from environment variables.
  factory ThresholdConfig.fromEnv(DotEnv env) {
    return ThresholdConfig(
      searchAcceptedConfidence:
          double.tryParse(env['SEARCH_ACCEPTED_CONFIDENCE'] ?? '') ?? 90.0,
      iqsAcceptedThreshold:
          int.tryParse(env['IQS_ACCEPTED_THRESHOLD'] ?? '') ?? 50,
      iqsSharpnessPerfectVariance:
          double.tryParse(env['IQS_SHARPNESS_PERFECT_VARIANCE'] ?? '') ?? 150.0,
      iqsBrightnessMin:
          double.tryParse(env['IQS_BRIGHTNESS_MIN'] ?? '') ?? 80.0,
      iqsBrightnessMax:
          double.tryParse(env['IQS_BRIGHTNESS_MAX'] ?? '') ?? 180.0,
      enhTenengradPerfectMagnitude:
          double.tryParse(env['ENH_TENENGRAD_PERFECT_MAGNITUDE'] ?? '') ?? 500.0,
      enhEntropyPerfectValue:
          double.tryParse(env['ENH_ENTROPY_PERFECT_VALUE'] ?? '') ?? 7.0,
      enhEntropyMinValue:
          double.tryParse(env['ENH_ENTROPY_MIN_VALUE'] ?? '') ?? 3.0,
      enhContrastIdealLower:
          double.tryParse(env['ENH_CONTRAST_IDEAL_LOWER'] ?? '') ?? 0.2,
      enhContrastIdealUpper:
          double.tryParse(env['ENH_CONTRAST_IDEAL_UPPER'] ?? '') ?? 0.6,
      enhContrastLowThreshold:
          double.tryParse(env['ENH_CONTRAST_LOW_THRESHOLD'] ?? '') ?? 0.1,
      enhContrastHighThreshold:
          double.tryParse(env['ENH_CONTRAST_HIGH_THRESHOLD'] ?? '') ?? 0.8,
      enhLaplacianSharpnessWeight:
          double.tryParse(env['ENH_LAPLACIAN_SHARPNESS_WEIGHT'] ?? '') ?? 0.6,
      enhTenengradSharpnessWeight:
          double.tryParse(env['ENH_TENENGRAD_SHARPNESS_WEIGHT'] ?? '') ?? 0.4,
      enhSharpnessOverallWeight:
          double.tryParse(env['ENH_SHARPNESS_OVERALL_WEIGHT'] ?? '') ?? 0.35,
      enhBrightnessOverallWeight:
          double.tryParse(env['ENH_BRIGHTNESS_OVERALL_WEIGHT'] ?? '') ?? 0.25,
      enhEntropyOverallWeight:
          double.tryParse(env['ENH_ENTROPY_OVERALL_WEIGHT'] ?? '') ?? 0.20,
      enhContrastOverallWeight:
          double.tryParse(env['ENH_CONTRAST_OVERALL_WEIGHT'] ?? '') ?? 0.20,
      gradingCenteringWeight:
          double.tryParse(env['GRADING_CENTERING_WEIGHT'] ?? '') ?? 0.40,
      gradingCornersWeight:
          double.tryParse(env['GRADING_CORNERS_WEIGHT'] ?? '') ?? 0.20,
      gradingEdgesWeight:
          double.tryParse(env['GRADING_EDGES_WEIGHT'] ?? '') ?? 0.20,
      gradingSurfaceWeight:
          double.tryParse(env['GRADING_SURFACE_WEIGHT'] ?? '') ?? 0.20,
      gradingHighConfidenceStdDev:
          double.tryParse(env['GRADING_HIGH_CONFIDENCE_STD_DEV'] ?? '') ?? 0.5,
      gradingLowConfidenceStdDev:
          double.tryParse(env['GRADING_LOW_CONFIDENCE_STD_DEV'] ?? '') ?? 2.0,
      evalReviewConfidenceThreshold:
          double.tryParse(env['EVAL_REVIEW_CONFIDENCE_THRESHOLD'] ?? '') ?? 0.7,
      evalReviewGapThreshold:
          double.tryParse(env['EVAL_REVIEW_GAP_THRESHOLD'] ?? '') ?? 2.0,
      validationMaxSetLength:
          int.tryParse(env['VALIDATION_MAX_SET_LENGTH'] ?? '') ?? 60,
      validationMaxEditionLength:
          int.tryParse(env['VALIDATION_MAX_EDITION_LENGTH'] ?? '') ?? 40,
      validationMaxLanguageLength:
          int.tryParse(env['VALIDATION_MAX_LANGUAGE_LENGTH'] ?? '') ?? 30,
      validationMaxFinishLength:
          int.tryParse(env['VALIDATION_MAX_FINISH_LENGTH'] ?? '') ?? 30,
      validationMaxAuthorLength:
          int.tryParse(env['VALIDATION_MAX_AUTHOR_LENGTH'] ?? '') ?? 100,
      validationMinImageBase64Bytes:
          int.tryParse(env['VALIDATION_MIN_IMAGE_BASE64_BYTES'] ?? '') ?? (5 * 1024),
      validationHpMin:
          int.tryParse(env['VALIDATION_HP_MIN'] ?? '') ?? 0,
      validationHpMax:
          int.tryParse(env['VALIDATION_HP_MAX'] ?? '') ?? 2000,
      validationYearMin:
          int.tryParse(env['VALIDATION_YEAR_MIN'] ?? '') ?? 1950,
    );
  }
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
