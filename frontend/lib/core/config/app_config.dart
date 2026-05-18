// ============================================================
// PokéGrading — Frontend Configuration (Core)
// API URLs and application constants.
// ============================================================

/// Global configuration of the frontend.
/// URLs should be adjusted via environment variables in production.
abstract class AppConfig {
  // --- Backend API ---
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String apiVersion = 'v1';
  static String get apiUrl => '$apiBaseUrl/api/$apiVersion';

  // --- App ---
  static const String appName = 'PokéGrading';
  static const String appVersion = '0.1.0';
  static const String appDescription =
      'Assisted Pre-Grading System for Pokémon Cards';
}
