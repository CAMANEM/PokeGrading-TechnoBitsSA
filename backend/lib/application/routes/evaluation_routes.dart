/// @file
/// @brief

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_helpers.dart';
import '../../core/middleware/correlation_middleware.dart';
import '../../domain/scoring/evaluation_logic.dart';
import '../../domain/image_services/preprocessing/preprocessing.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';
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

  // ─── Preprocess endpoint (testing) ──────────────────────────────
  router.post('/preprocess', (Request request) async {
    final payload = await readJson(request);
    final imageData = payload['image_data']?.toString() ?? '';
    final correlationId = request.context['correlation_id'] as String? ??
        resolveCorrelationId(request.headers);

    AppLogger.info(
      'PokéGrading.Routes.Preprocess',
      'Preprocess request received',
      context: {
        'correlation_id': correlationId,
        'has_image': imageData.isNotEmpty,
      },
    );

    if (imageData.isEmpty) {
      return jsonResponse(
        400,
        {
          'status': 'error',
          'error': 'missing_image',
          'message': 'image_data is required',
          'correlation_id': correlationId,
        },
      );
    }

    try {
      final result = PreprocessingService.preprocess(imageData);

      if (!result.success) {
        AppLogger.info(
          'PokéGrading.Routes.Preprocess',
          'Preprocessing failed',
          context: {
            'correlation_id': correlationId,
            'error': result.error?.name,
            'message': result.errorMessage,
          },
        );

        return jsonResponse(
          422,
          {
            'status': 'error',
            'error': result.error?.name ?? 'unknown',
            'message': result.errorMessage ?? 'Preprocessing failed',
            'correlation_id': correlationId,
            'metadata': {
              'detection_ms': result.metadata.detectionTimeMs,
              'correction_ms': result.metadata.correctionTimeMs,
              'total_ms': result.metadata.totalTimeMs,
              'algorithm_version': PreprocessingMetadata.algorithmVersion,
            },
          },
        );
      }

      // Save corrected image to preprocess_output folder
      final outputDir = Directory('../preprocess_output');
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().toUtc().toIso8601String()
          .replaceAll(':', '-').replaceAll('.', '-');
      final filename = 'preprocessed_${timestamp}.jpg';
      final file = File('${outputDir.path}/$filename');

      // Decode base64 and write to file
      final base64Data = result.correctedImageData!.contains(',')
          ? result.correctedImageData!.split(',').last
          : result.correctedImageData!;
      final bytes = base64Decode(base64Data);
      await file.writeAsBytes(bytes);

      AppLogger.info(
        'PokéGrading.Routes.Preprocess',
        'Preprocessing successful',
        context: {
          'correlation_id': correlationId,
          'output_file': file.path,
          'corners': result.detectedCorners?.map((c) => {'x': c.x, 'y': c.y}).toList(),
          'detection_ms': result.metadata.detectionTimeMs,
          'correction_ms': result.metadata.correctionTimeMs,
        },
      );

      return jsonResponse(
        200,
        {
          'success': true,
          'corrected_image': result.correctedImageData,
          'output_file': filename,
          'corners': result.detectedCorners?.map((c) => {'x': c.x, 'y': c.y}).toList(),
          'metadata': {
            'detection_ms': result.metadata.detectionTimeMs,
            'correction_ms': result.metadata.correctionTimeMs,
            'total_ms': result.metadata.totalTimeMs,
            'algorithm_version': PreprocessingMetadata.algorithmVersion,
          },
          'correlation_id': correlationId,
        },
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Routes.Preprocess',
        'Preprocessing failed unexpectedly',
        context: {'correlation_id': correlationId},
        error: error,
        stackTrace: stack,
      );
      return jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'preprocess_failed',
          'message': error.toString(),
          'correlation_id': correlationId,
        },
      );
    }
  });

  return router;
}
