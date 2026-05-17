// ============================================================
// PokéGrading — Middleware de Correlation ID (Core)
// Inyecta un correlation_id único en cada request HTTP para
// permitir el rastreo end-to-end entre capas (Observabilidad).
// ============================================================
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

final _log = Logger('PokéGrading.Middleware.Correlation');
const _uuid = Uuid();

/// Header HTTP que transporta el correlation_id.
const correlationIdHeader = 'X-Correlation-ID';

/// Middleware que:
/// 1. Lee el [correlationIdHeader] del request entrante (si lo trae el cliente).
/// 2. Si no existe, genera uno nuevo (UUID v4).
/// 3. Lo almacena en el contexto del request para uso downstream.
/// 4. Lo incluye en el response como header.
///
/// Cada capa puede acceder al correlation_id así:
/// ```dart
/// final correlationId = request.context['correlation_id'];
/// ```
Middleware correlationMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // Leer o generar correlation_id
      final correlationId =
          request.headers[correlationIdHeader] ?? _uuid.v4();

      // Inyectar en el contexto del request
      final updatedRequest = request.change(
        context: {
          ...request.context,
          'correlation_id': correlationId,
        },
      );

      _log.fine(
        'correlation_id=$correlationId '
        'method=${request.method} '
        'path=${request.requestedUri.path}',
      );

      // Procesar el request y capturar el response
      final response = await innerHandler(updatedRequest);

      // Propagar el correlation_id en el response
      return response.change(
        headers: {
          ...response.headersAll.map(
            (key, values) => MapEntry(key, values.join(', ')),
          ),
          correlationIdHeader: correlationId,
        },
      );
    };
  };
}
