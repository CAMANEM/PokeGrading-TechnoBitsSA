/// @file
/// @brief

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../domain/submitter_catalog/submit_evaluation/evaluation_logic.dart';
import '../http_helpers.dart';

Router buildSubmitEvaluationRoutes(
    SubmitEvaluationLogic submitEvaluationLogic) {
  final router = Router();

  router.post('/evaluations', (Request request) async {
    final payload = await readJson(request);
    final frontImageData = payload['front_image_data'].toString();
    final backImageData = (payload['back_image_data'] ?? '').toString();
    final cardId = payload['card_id']?.toString();

    try {
      final result = await submitEvaluationLogic.submit(
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
    } on SubmitEvaluationLogicException catch (error) {
      return jsonResponse(
        submitEvaluationStatusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error) {
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
