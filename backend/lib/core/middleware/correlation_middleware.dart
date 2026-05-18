// ============================================================
// PokéGrading — Correlation ID Middleware (Core)
// Injects a unique correlation_id in each HTTP request to
// enable end-to-end tracing across layers (Observability).
// ============================================================
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

final _log = Logger('PokéGrading.Middleware.Correlation');
const _uuid = Uuid();

/// HTTP Header that carries the correlation_id.
const correlationIdHeader = 'X-Correlation-ID';

/// Middleware that:
/// 1. Reads [correlationIdHeader] from the incoming request (if client sent it).
/// 2. If not present, generates a new one (UUID v4).
/// 3. Stores it in the request context for downstream usage.
/// 4. Includes it in the response header.
///
/// Each layer can access the correlation_id like this:
/// ```dart
/// final correlationId = request.context['correlation_id'];
/// ```
Middleware correlationMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // Read or generate correlation_id
      final correlationId =
          request.headers[correlationIdHeader] ?? _uuid.v4();

      // Inject into the request context
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

      // Process request and get response
      final response = await innerHandler(updatedRequest);

      // Propagate the correlation_id in the response
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
