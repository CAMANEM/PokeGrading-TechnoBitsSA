/// @file
/// @brief

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_helpers.dart';
import '../../core/middleware/correlation_middleware.dart';
import '../../domain/scoring/evaluation_logic.dart';
import '../../shared/exception_service/exception_handler.dart';
import '../http_helpers.dart';

Router buildEvaluationRoutes(EvaluationLogic evaluationLogic) {
  final router = Router();

  router.post('/evaluations', (Request request) async {
    final payload = await readJson(request);
    final frontImageData = payload['front_image_data'].toString();
    final backImageData = (payload['back_image_data'] ?? '').toString();
    final cardId = payload['card_id']?.toString();
    final correlationId = request.context['correlation_id'] as String? ??
        resolveCorrelationId(request.headers);
    final requestContext = httpLogContext(
      request: request,
      body: evaluationBodySummary(payload),
    );

    AppLogger.info(
      'PokéGrading.Routes.Evaluation',
      'Evaluation submission request',
      context: requestContext,
    );

    try {
      final result = await evaluationLogic.submit(
        SubmitEvaluationCommand(
          frontImageData: frontImageData,
          backImageData: backImageData,
          cardId: cardId,
          correlationId: correlationId,
        ),
      );

      AppLogger.info(
        'PokéGrading.Routes.Evaluation',
        'Evaluation submission accepted',
        context: {
          ...requestContext,
          'evaluation_id': result.submissionId,
          'status': result.status.name,
        },
      );

      return jsonResponse(
        201,
        {
          'evaluation_id': result.submissionId,
          'correlation_id': result.correlationId,
          'status': result.status.toString(),
          'created_at': result.createdAt.toIso8601String(),
          'estimated_time': '0 seconds',
        },
        headers: {correlationIdHeader: result.correlationId},
      );
    } on LogicException catch (error) {
      AppLogger.grading(
        'PokéGrading.Routes.Evaluation',
        'Evaluation submission rejected',
        context: {
          ...requestContext,
          'error_code': error.code,
          'error_message': error.message,
        },
      );
      return jsonResponse(
        submitEvaluationStatusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
          'correlation_id': correlationId,
        },
        headers: {correlationIdHeader: correlationId},
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Routes.Evaluation',
        'Evaluation submission failed',
        context: requestContext,
        error: error,
        stackTrace: stack,
      );
      return jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'submission_failed',
          'message': error.toString(),
          'correlation_id': correlationId,
        },
        headers: {correlationIdHeader: correlationId},
      );
    }
  });

  return router;
}
