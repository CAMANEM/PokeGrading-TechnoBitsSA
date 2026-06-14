/// @file
/// @brief

// ============================================================
// PokéGrading — Correlation ID Middleware (Core)
// Injects a unique correlation_id in each HTTP request to
// enable end-to-end tracing across layers (Observability).
// ============================================================
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'package:pokegrading_logging/pokegrading_logging.dart';

const _uuid = Uuid();

/// HTTP Header that carries the correlation_id.
const correlationIdHeader = 'X-Correlation-ID';

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

/// Returns a valid correlation id from the header or generates a new UUID v4.
String resolveCorrelationId(Map<String, String> headers) {
  final incoming = headers[correlationIdHeader];
  if (incoming != null && _uuidPattern.hasMatch(incoming.trim())) {
    return incoming.trim();
  }
  return _uuid.v4();
}

/// Middleware that:
/// 1. Reads [correlationIdHeader] from the incoming request (if client sent it).
/// 2. If not present or invalid, generates a new one (UUID v4).
/// 3. Stores it in the request context and [CorrelationContext] Zone.
/// 4. Includes it in the response header.
Middleware correlationMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      final correlationId = resolveCorrelationId(request.headers);

      final updatedRequest = request.change(
        context: {
          ...request.context,
          'correlation_id': correlationId,
        },
      );

      return CorrelationContext.runAsync(
        correlationId,
        () async {
          final response = await innerHandler(updatedRequest);
          return response.change(
            headers: {
              ...response.headersAll.map(
                (key, values) => MapEntry(key, values.join(', ')),
              ),
              correlationIdHeader: correlationId,
            },
          );
        },
      );
    };
  };
}
