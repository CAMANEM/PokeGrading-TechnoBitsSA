/// @file
/// @brief

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/logging/app_logger.dart';
import '../../core/middleware/correlation_middleware.dart';
import '../http_helpers.dart';

Router buildObservabilityRoutes() {
  final router = Router();

  router.post('/client-errors', (Request request) async {
    final payload = await readJson(request);
    final correlationId = request.context['correlation_id'] as String? ??
        resolveCorrelationId(request.headers);
    final message = (payload['message'] ?? 'Client error').toString();
    final logger =
        (payload['logger'] ?? 'PokéGrading.Client').toString();
    final context = payload['context'];

    AppLogger.error(
      logger,
      message,
      context: context is Map<String, dynamic> ? context : null,
    );

    return jsonResponse(
      202,
      {'status': 'accepted', 'correlation_id': correlationId},
      headers: {correlationIdHeader: correlationId},
    );
  });

  return router;
}
