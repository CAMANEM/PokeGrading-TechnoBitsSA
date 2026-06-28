/// @file
/// @brief

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:image/image.dart' as img;

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_helpers.dart';
import '../../core/middleware/correlation_middleware.dart';
import '../../domain/scoring/evaluation_logic.dart';
import '../../domain/image_services/preprocessing/preprocessing.dart';
import '../../domain/scoring/grading/grading_orchestrator.dart';
import '../../domain/scoring/grading/baseline_registry.dart';
import '../../domain/scoring/grading/baseline_calibrator.dart';
import '../../domain/image_services/grading/enhanced_quality_service.dart';
import '../../persistence/card_data_provider/calibrated_baseline_repository.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';
import '../http_helpers.dart';

/// Simple in-memory idempotency cache for the grading endpoint.
class _GradingIdempotencyCache {
  final Map<String, _CachedGradingResponse> _cache = {};

  /// TTL for cached responses (30 minutes).
  static const _ttl = Duration(minutes: 30);

  /// Looks up a cached response by key. Returns null if expired or missing.
  Map<String, dynamic>? lookup(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().toUtc().difference(entry.createdAt) > _ttl) {
      _cache.remove(key);
      return null;
    }
    return entry.response;
  }

  /// Stores a response under the given key.
  void store(String key, Map<String, dynamic> response) {
    _cache[key] = _CachedGradingResponse(
      response: response,
      createdAt: DateTime.now().toUtc(),
    );
    // Evict old entries periodically
    if (_cache.length > 100) {
      final now = DateTime.now().toUtc();
      _cache.removeWhere((_, v) => now.difference(v.createdAt) > _ttl);
    }
  }

  /// Generates an idempotency key from image data + optional client key.
  static String generateKey(String imageData, String? clientIdempotencyKey) {
    final hash = md5.convert(utf8.encode(imageData)).toString();
    if (clientIdempotencyKey != null && clientIdempotencyKey.isNotEmpty) {
      return '$clientIdempotencyKey:$hash';
    }
    return hash;
  }
}

class _CachedGradingResponse {
  final Map<String, dynamic> response;
  final DateTime createdAt;
  const _CachedGradingResponse({required this.response, required this.createdAt});
}

Router buildEvaluationRoutes(
  EvaluationLogic evaluationLogic, {
  BaselineRegistry? baselineRegistry,
  CalibratedBaselineRepository? baselineRepository,
}) {
  final router = Router();
  final registry = baselineRegistry ?? BaselineRegistry();
  final idempotencyCache = _GradingIdempotencyCache();

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

  // ─── Grading endpoint (testing) ──────────────────────────────
  router.post('/grade', (Request request) async {
    final payload = await readJson(request);
    final imageData = payload['image_data']?.toString() ?? '';
    final correlationId = request.context['correlation_id'] as String? ??
        resolveCorrelationId(request.headers);

    // Optional card identity for baseline selection
    final cardSetName = payload['set_name']?.toString();
    final cardFinish = payload['finish']?.toString();

    AppLogger.info(
      'PokéGrading.Routes.Grading',
      'Grading request received',
      context: {
        'correlation_id': correlationId,
        'has_image': imageData.isNotEmpty,
        'set_name': cardSetName,
        'finish': cardFinish,
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

    // Check idempotency cache (client may provide idempotency_key in body)
    final idempotencyKey = payload['idempotency_key']?.toString();
    final cacheKey = _GradingIdempotencyCache.generateKey(imageData, idempotencyKey);
    final cached = idempotencyCache.lookup(cacheKey);
    if (cached != null) {
      AppLogger.info(
        'PokéGrading.Routes.Grading',
        'Idempotency cache hit',
        context: {
          'correlation_id': correlationId,
          'cache_key': cacheKey,
        },
      );
      // Return cached response with correlation_id
      return jsonResponse(200, {
        ...cached,
        'idempotent_replay': true,
        'correlation_id': correlationId,
      });
    }

    try {
      // Step 1: Preprocess the image
      final preprocessResult = PreprocessingService.preprocess(imageData);

      if (!preprocessResult.success || preprocessResult.rois == null) {
        return jsonResponse(
          422,
          {
            'status': 'error',
            'error': preprocessResult.error?.name ?? 'preprocessing_failed',
            'message': preprocessResult.errorMessage ?? 'Preprocessing failed',
            'correlation_id': correlationId,
          },
        );
      }

      // Step 2: Decode full image for centering + quality analysis
      final base64Part = imageData.contains(',')
          ? imageData.split(',').last
          : imageData;
      final bytes = base64Decode(base64Part);
      final image = img.decodeImage(Uint8List.fromList(bytes));

      // Step 3: Select baseline for this (set, finish)
      final baselineSelection = registry.select(cardSetName, cardFinish);

      // Step 4: Run grading on the ROIs with baseline
      final gradingStart = DateTime.now().toUtc();
      final gradingResult = GradingOrchestrator.grade(
        preprocessResult.rois!,
        fullImage: image,
        baselineSelection: baselineSelection,
      );
      final gradingDuration =
          DateTime.now().toUtc().difference(gradingStart).inMilliseconds;

      // Step 5: Run enhanced quality analysis
      EnhancedQualityResult? qualityResult;
      if (image != null) {
        qualityResult = EnhancedQualityService.calculateEnhancedQuality(image);
      }

      AppLogger.info(
        'PokéGrading.Routes.Grading',
        'Grading completed',
        context: {
          'correlation_id': correlationId,
          'final_grade': gradingResult.finalGrade,
          'confidence': gradingResult.confidence,
          'grading_ms': gradingDuration,
          'baseline_version': gradingResult.baseline.version,
          'baseline_calibrated': gradingResult.baseline.isCalibrated,
        },
      );

      final responseBody = {
        'success': true,
        'grading': gradingResult.toJson(),
        'quality': qualityResult?.toJson(),
        'metadata': {
          'preprocessing_ms': preprocessResult.metadata.totalTimeMs,
          'grading_ms': gradingDuration,
          'algorithm_version': '1.0.0',
        },
        'correlation_id': correlationId,
      };

      // Cache for idempotency
      idempotencyCache.store(cacheKey, responseBody);

      return jsonResponse(200, responseBody);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Routes.Grading',
        'Grading failed unexpectedly',
        context: {'correlation_id': correlationId},
        error: error,
        stackTrace: stack,
      );
      return jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'grading_failed',
          'message': error.toString(),
          'correlation_id': correlationId,
        },
      );
    }
  });

  // ─── Calibration endpoint (admin) ──────────────────────────────
  router.post('/calibrate', (Request request) async {
    final payload = await readJson(request);
    final correlationId = request.context['correlation_id'] as String? ??
        resolveCorrelationId(request.headers);

    AppLogger.info(
      'PokéGrading.Routes.Calibration',
      'Calibration request received',
      context: {
        'correlation_id': correlationId,
      },
    );

    try {
      final setName = payload['set_name']?.toString();
      final finish = payload['finish']?.toString();
      final description = payload['description']?.toString() ?? 'Calibrated from dataset';

      if (setName == null || setName.isEmpty) {
        return jsonResponse(400, {
          'status': 'error',
          'error': 'missing_set_name',
          'message': 'set_name is required',
          'correlation_id': correlationId,
        });
      }
      if (finish == null || finish.isEmpty) {
        return jsonResponse(400, {
          'status': 'error',
          'error': 'missing_finish',
          'message': 'finish is required',
          'correlation_id': correlationId,
        });
      }

      // Parse dataset of graded cards
      final cardsJson = payload['cards'] as List?;
      if (cardsJson == null || cardsJson.isEmpty) {
        return jsonResponse(400, {
          'status': 'error',
          'error': 'missing_cards',
          'message': 'cards array is required and must not be empty',
          'correlation_id': correlationId,
        });
      }

      final cards = <GradedCardRecord>[];
      for (final cardJson in cardsJson) {
        if (cardJson is! Map) continue;
        final features = cardJson['features'] as Map?;
        if (features == null) continue;

        cards.add(GradedCardRecord(
          features: CardFeatures(
            centeringSymmetry: (features['centering_symmetry'] as num?)?.toDouble() ?? 0.5,
            cornerWhiteningPercentages: (features['corner_whitening_percentages'] as List?)
                ?.map((e) => (e as num).toDouble()).toList() ?? [0, 0, 0, 0],
            edgeWhiteningPercentages: (features['edge_whitening_percentages'] as List?)
                ?.map((e) => (e as num).toDouble()).toList() ?? [0, 0, 0, 0],
            edgeStraightnessCVs: (features['edge_straightness_cvs'] as List?)
                ?.map((e) => (e as num).toDouble()).toList() ?? [0.1, 0.1, 0.1, 0.1],
            surfaceScratchDensity: (features['surface_scratch_density'] as num?)?.toDouble() ?? 0,
            surfaceUniformityCV: (features['surface_uniformity_cv'] as num?)?.toDouble() ?? 0.3,
          ),
          psaGrade: (cardJson['psa_grade'] as num?)?.toDouble() ?? 5.0,
          set: setName,
          finish: finish,
        ));
      }

      // Calibrate
      final baselineVersion = '${setName.toLowerCase()}_${finish.toLowerCase()}_v1.0';
      final result = BaselineCalibrator.calibrate(
        cards: cards,
        baselineVersion: baselineVersion,
        description: description,
      );

      // Register in the in-memory registry
      if (result.hasSufficientGroundTruth) {
        baselineRegistry?.register(setName, finish, BaselineEntry(
          config: result.config,
          referenceCardCount: result.cardCount,
          calibratedAt: DateTime.now().toUtc(),
          averagePsaGrade: result.averagePsaGrade,
        ));
      }

      // Persist to database if repository is available
      if (baselineRepository != null) {
        await baselineRepository.storeBaseline(StoreBaselineInput(
          setName: setName,
          finish: finish,
          config: result.config,
          referenceCardCount: result.cardCount,
          averagePsaGrade: result.averagePsaGrade,
          psaGradeStdDev: result.psaGradeStdDev,
          qualityScore: result.qualityScore,
        ));
      }

      AppLogger.info(
        'PokéGrading.Routes.Calibration',
        'Calibration completed',
        context: {
          'correlation_id': correlationId,
          'set_name': setName,
          'finish': finish,
          'card_count': result.cardCount,
          'has_sufficient_ground_truth': result.hasSufficientGroundTruth,
          'quality_score': result.qualityScore,
        },
      );

      return jsonResponse(
        200,
        {
          'success': true,
          'calibration': {
            'set_name': setName,
            'finish': finish,
            'baseline_version': baselineVersion,
            'card_count': result.cardCount,
            'has_sufficient_ground_truth': result.hasSufficientGroundTruth,
            'average_psa_grade': result.averagePsaGrade,
            'psa_grade_std_dev': result.psaGradeStdDev,
            'quality_score': result.qualityScore,
            'warnings': result.warnings,
            'registered': result.hasSufficientGroundTruth,
          },
          'correlation_id': correlationId,
        },
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Routes.Calibration',
        'Calibration failed unexpectedly',
        context: {'correlation_id': correlationId},
        error: error,
        stackTrace: stack,
      );
      return jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'calibration_failed',
          'message': error.toString(),
          'correlation_id': correlationId,
        },
      );
    }
  });

  return router;
}
