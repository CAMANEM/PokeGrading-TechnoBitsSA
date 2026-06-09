/// @file
/// @brief

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../domain/scoring/evaluation_logic.dart';
import '../../shared/exception_service/exception_handler.dart';
import '../http_helpers.dart';

final _log = Logger('PokéGrading.Routes.Evaluation');

Router buildEvaluationRoutes(EvaluationLogic evaluationLogic) {
  final router = Router();

  router.post('/evaluations', (Request request) async {
    final payload = await readJson(request);
    final frontImageData = payload['front_image_data'].toString();
    final backImageData = (payload['back_image_data'] ?? '').toString();
    final cardId = payload['card_id']?.toString();

    try {
      final result = await evaluationLogic.submit(
        SubmitEvaluationCommand(
          frontImageData: frontImageData,
          backImageData: backImageData,
          cardId: cardId,
        ),
      );

      return jsonResponse(
        201,
        {
          'evaluation_id': result.submissionId,
          'status': result.status.toString(),
          'created_at': result.createdAt.toIso8601String(),
          'estimated_time': "0 seconds"
        },
      );
    } on LogicException catch (error) {
      return jsonResponse(
        submitEvaluationStatusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error, stack) {
      _log.severe('Evaluation submission failed: $error\n$stack');
      return jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'submission_failed',
          'message': error.toString(),
        },
      );
    }
  });

  return router;
}
