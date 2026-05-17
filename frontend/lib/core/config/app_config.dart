// ============================================================
// PokéGrading — Configuración del Frontend (Core)
// URLs de API y constantes de la aplicación.
// ============================================================

/// Configuración global del frontend.
/// Las URLs se deben ajustar via variables de entorno en producción.
abstract class AppConfig {
  // ─── API Backend ─────────────────────────────────────────
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String apiVersion = 'v1';
  static String get apiUrl => '$apiBaseUrl/api/$apiVersion';

  // ─── App ─────────────────────────────────────────────────
  static const String appName = 'PokéGrading';
  static const String appVersion = '0.1.0';
  static const String appDescription =
      'Sistema Asistido de Pre-Grading para Cartas Pokémon';
}
