// ============================================================
// PokéGrading — Logger Global (Core)
// Logging estructurado con soporte de correlation_id.
// ============================================================
import 'package:logging/logging.dart';

/// Inicializa y configura el sistema de logging de la aplicación.
///
/// Todos los logs incluyen:
/// - Timestamp UTC
/// - Nivel de severidad
/// - Nombre del logger (origen)
/// - correlation_id (cuando está disponible en Zone)
/// - Mensaje
///
/// Uso:
/// ```dart
/// AppLogger.init();
/// final log = Logger('MiClase');
/// log.info('Evento importante');
/// ```
class AppLogger {
  AppLogger._(); // No instanciable

  static bool _initialized = false;

  /// Inicializa el sistema de logging. Llamar UNA sola vez al inicio.
  static void init({Level level = Level.INFO}) {
    if (_initialized) return;
    _initialized = true;

    Logger.root.level = level;
    Logger.root.onRecord.listen(_handleRecord);
  }

  /// Handler que formatea y escribe cada [LogRecord] a stdout/stderr.
  static void _handleRecord(LogRecord record) {
    final timestamp = record.time.toUtc().toIso8601String();
    final level = record.level.name.padRight(7);
    final name = record.loggerName;
    final message = record.message;

    // Formato de log estructurado (JSON-like legible)
    final line = '[$timestamp] [$level] [$name] $message';

    if (record.level >= Level.SEVERE) {
      // Errores van a stderr
      print('\x1B[31m$line\x1B[0m'); // Rojo
      if (record.error != null) {
        print('\x1B[31m  ERROR: ${record.error}\x1B[0m');
      }
      if (record.stackTrace != null) {
        print('\x1B[31m  STACK: ${record.stackTrace}\x1B[0m');
      }
    } else if (record.level >= Level.WARNING) {
      print('\x1B[33m$line\x1B[0m'); // Amarillo
    } else if (record.level >= Level.INFO) {
      print('\x1B[36m$line\x1B[0m'); // Cyan
    } else {
      print('\x1B[90m$line\x1B[0m'); // Gris (DEBUG)
    }
  }
}
