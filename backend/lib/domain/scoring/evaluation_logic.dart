/// @file
/// @brief

import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'scoring_models.dart';
import 'scoring_validators.dart';
import '../image_services/image_quality_service.dart';
import '../image_services/polyglot_detection.dart';
import '../image_services/visual_features.dart';
import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../persistence/card_data_provider/evaluation_repository.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';
import 'package:pokegrading_logging/pokegrading_logging.dart';
import '../image_services/preprocessing/preprocessing_service.dart';
import 'grading/grading_orchestrator.dart';
import 'grading/baseline_registry.dart';

Never _throwEvaluationError(String code, String err) {
  throw LogicException(feature: 'submit-evaluation', code: code, message: err);
}

/// @brief SubmitEvaluationCommand
class SubmitEvaluationCommand {
  final String frontImageData;
  final String backImageData;
  final String? cardId;
  final String correlationId;
  final String? setFinish;
  final String? setName;

  const SubmitEvaluationCommand({
    required this.frontImageData,
    required this.backImageData,
    required this.correlationId,
    this.cardId,
    this.setFinish,
    this.setName,
  });
}

/// @brief EvaluationSubmittedResult
class EvaluationResult {
  final String submissionId;
  final double frontScore;
  final double backScore;
  final EvaluationStatus status;
  final DateTime createdAt;
  final String correlationId;
  final GradingResult? gradingResult;
  final String? rejectionReason;

  const EvaluationResult({
    required this.submissionId,
    required this.frontScore,
    required this.backScore,
    required this.status,
    required this.createdAt,
    required this.correlationId,
    this.gradingResult,
    this.rejectionReason,
  });
}

/// @brief SubmitEvaluationLogic
class EvaluationLogic {
  static const _loggerName = 'PokéGrading.Evaluation';

  final EvaluationRepository repository;
  final BaselineRegistry baselineRegistry;
  final ThresholdConfig _thresholds;
  static const String _evaluationErrorCode = 'image_rejected';

  EvaluationLogic({
    required this.repository,
    BaselineRegistry? baselineRegistry,
    ThresholdConfig? thresholds,
  })  : baselineRegistry = baselineRegistry ?? BaselineRegistry(),
        _thresholds = thresholds ?? const ThresholdConfig();

  Future<EvaluationResult> submit(
    SubmitEvaluationCommand command,
  ) async {
    final correlationId = command.correlationId;

    _validate(command);

    // ─── Polyglot Detection (security — hard reject, never saved) ──
    final frontPolyglotStarted = DateTime.now().toUtc();
    final frontPolyglotResult =
        PolyglotDetector.inspect(command.frontImageData);
    final frontPolyglotDuration =
        DateTime.now().toUtc().difference(frontPolyglotStarted).inMilliseconds;

    _logStage(
      stage: 'polyglot_front',
      durationMs: frontPolyglotDuration,
      outputs: {
        'is_polyglot': frontPolyglotResult.isPolyglot,
        'indicators': frontPolyglotResult.indicators,
      },
    );

    if (frontPolyglotResult.isPolyglot) {
      AppLogger.audit(
        _loggerName,
        AuditEventTypes.securityPolyglotDetected,
        result: 'failure',
        context: {
          'side': 'front',
          'indicators': frontPolyglotResult.indicators,
        },
      );
      _throwEvaluationError(
        _evaluationErrorCode,
        'Se detecto una archivo malicioso para la imagen frontal. '
        'Indicadores: ${frontPolyglotResult.indicators.join(', ')}',
      );
    }

    final backPolyglotStarted = DateTime.now().toUtc();
    final backPolyglotResult = PolyglotDetector.inspect(command.backImageData);
    final backPolyglotDuration =
        DateTime.now().toUtc().difference(backPolyglotStarted).inMilliseconds;

    _logStage(
      stage: 'polyglot_back',
      durationMs: backPolyglotDuration,
      outputs: {
        'is_polyglot': backPolyglotResult.isPolyglot,
        'indicators': backPolyglotResult.indicators,
      },
    );

    if (backPolyglotResult.isPolyglot) {
      AppLogger.audit(
        _loggerName,
        AuditEventTypes.securityPolyglotDetected,
        result: 'failure',
        context: {
          'side': 'back',
          'indicators': backPolyglotResult.indicators,
        },
      );
      _throwEvaluationError(
        _evaluationErrorCode,
        'Se detecto un archivo malicioso para la imagen trasera. '
        'Indicadores: ${backPolyglotResult.indicators.join(', ')}',
      );
    }

    // ─── IQS Front (on original image — JPEG preprocessing hurts sharpness) ──
    final frontIqsStarted = DateTime.now().toUtc();
    final frontScore = await ImageQualityService.calculateScore(
      command.frontImageData,
      thresholds: _thresholds,
    );
    final frontIqsDuration =
        DateTime.now().toUtc().difference(frontIqsStarted).inMilliseconds;

    _logStage(
      stage: 'iqs_front',
      durationMs: frontIqsDuration,
      outputs: {
        'iqs_score': frontScore.score,
        'rejection_reasons': frontScore.rejectionReasons,
      },
    );

    AppLogger.metric(
      _loggerName,
      'stage.latency',
      context: {'stage': 'iqs_front', 'duration_ms': frontIqsDuration},
    );

    if (frontScore.score < _thresholds.iqsAcceptedThreshold) {
      return _saveUnableToGrade(
        command: command,
        frontScore: frontScore.score,
        backScore: 0,
        reason: 'Imagen frontal no supera el IQS '
            '(${frontScore.score.toStringAsFixed(1)}/100). '
            'Motivos: ${frontScore.rejectionReasons.join(", ")}',
      );
    }

    // ─── IQS Back (on original image) ───────────────────────────
    final backIqsStarted = DateTime.now().toUtc();
    final backScore = await ImageQualityService.calculateScore(
      command.backImageData,
      thresholds: _thresholds,
    );
    final backIqsDuration =
        DateTime.now().toUtc().difference(backIqsStarted).inMilliseconds;

    _logStage(
      stage: 'iqs_back',
      durationMs: backIqsDuration,
      outputs: {
        'iqs_score': backScore.score,
        'rejection_reasons': backScore.rejectionReasons,
      },
    );

    AppLogger.metric(
      _loggerName,
      'stage.latency',
      context: {'stage': 'iqs_back', 'duration_ms': backIqsDuration},
    );

    if (backScore.score < _thresholds.iqsAcceptedThreshold) {
      AppLogger.info(
        _loggerName,
        'Back image IQS below threshold — proceeding anyway',
        context: {
          'correlation_id': correlationId,
          'back_iqs': backScore.score,
          'reasons': backScore.rejectionReasons,
        },
      );
    }

    // ─── Preprocessing (for grading — ROI extraction, perspective correction) ──
    final frontPreprocess =
        PreprocessingService.preprocess(command.frontImageData);

    if (!frontPreprocess.success || frontPreprocess.rois == null) {
      return _saveUnableToGrade(
        command: command,
        frontScore: frontScore.score,
        backScore: backScore.score,
        reason: 'Preprocessing frontal falló: ${frontPreprocess.errorMessage}',
      );
    }

    final backPreprocess =
        PreprocessingService.preprocess(command.backImageData);

    if (!backPreprocess.success || backPreprocess.rois == null) {
      return _saveUnableToGrade(
        command: command,
        frontScore: frontScore.score,
        backScore: backScore.score,
        reason: 'Preprocessing trasero falló: ${backPreprocess.errorMessage}',
      );
    }

    // ─── Decode full image for grading ──────────────────────────
    final base64Part = command.frontImageData.contains(',')
        ? command.frontImageData.split(',').last
        : command.frontImageData;
    final bytes = base64Decode(base64Part);
    final fullImage = img.decodeImage(Uint8List.fromList(bytes));

    // ─── Baseline selection ─────────────────────────────────────
    final baselineSelection = baselineRegistry.select(
      command.setName,
      command.setFinish,
    );

    // ─── Grading ────────────────────────────────────────────────
    final gradingStart = DateTime.now().toUtc();
    final gradingResult = GradingOrchestrator.grade(
      frontPreprocess.rois!,
      fullImage: fullImage,
      baselineSelection: baselineSelection,
    );
    final gradingDuration =
        DateTime.now().toUtc().difference(gradingStart).inMilliseconds;

    _logStage(
      stage: 'grading',
      durationMs: gradingDuration,
      outputs: {
        'final_grade': gradingResult.finalGrade,
        'confidence': gradingResult.confidence,
        'coherence_applied': gradingResult.coherenceRuleApplied,
      },
    );

    // ─── Determine final status ─────────────────────────────────
    EvaluationStatus finalStatus = EvaluationStatus.completed;

    if (gradingResult.coherenceRuleApplied) {
      final weightedGrade =
          gradingResult.centeringGrade * _thresholds.gradingCenteringWeight +
              gradingResult.corners.grade * _thresholds.gradingCornersWeight +
              gradingResult.edges.grade * _thresholds.gradingEdgesWeight +
              gradingResult.surface.grade * _thresholds.gradingSurfaceWeight;
      final gap = weightedGrade - gradingResult.lowestSubgrade;

      if (gradingResult.confidence < _thresholds.evalReviewConfidenceThreshold ||
          gap > _thresholds.evalReviewGapThreshold) {
        finalStatus = EvaluationStatus.underReview;
        AppLogger.info(
          _loggerName,
          'Evaluation flagged for human review',
          context: {
            'correlation_id': correlationId,
            'confidence': gradingResult.confidence,
            'gap': gap,
            'reason': gradingResult.confidence < _thresholds.evalReviewConfidenceThreshold
                ? 'low_confidence'
                : 'large_coherence_gap',
          },
        );
      }
    }

    // ─── Visual features (non-critical) ─────────────────────────
    VisualFeatures? frontFeatures;
    try {
      frontFeatures = VisualFeatureExtractor.extract(command.frontImageData);
    } catch (_) {
      // non-critical
    }

    // ─── Persist ────────────────────────────────────────────────
    final persistStarted = DateTime.now().toUtc();
    final saved = await repository.saveEvaluation(
      AddEvaluationInput(
          frontImageData: command.frontImageData,
          backImageData: command.backImageData,
          frontImageScore: frontScore.score,
          backImageScore: backScore.score,
          cardId: command.cardId,
          correlationId: correlationId,
          frontVisualFeatures: frontFeatures,
          algorithmVersion: GradingOrchestrator.algorithmVersion,
          status: finalStatus,
          pregradings: PregradeResult(
              status: finalStatus.toString(),
              submittedDate: persistStarted.toIso8601String().split('T')[0],
              centering_grade: gradingResult.centeringGrade,
              corners_grade: gradingResult.corners.grade,
              edges_grade: gradingResult.edges.grade,
              surface_grade: gradingResult.surface.grade,
              grade: gradingResult.finalGrade,
              confidence: gradingResult.confidence,
              gradedDate: persistStarted.toIso8601String().split('T')[0])),
    );
    final persistDuration =
        DateTime.now().toUtc().difference(persistStarted).inMilliseconds;

    _logStage(
      stage: 'persist_pre_grade',
      durationMs: persistDuration,
      inputs: {'card_id': command.cardId},
      outputs: {
        'evaluation_id': saved.id,
        'status': saved.status.name,
      },
    );

    AppLogger.grading(
      _loggerName,
      'Evaluation submitted',
      context: {
        'evaluation_id': saved.id,
        'correlation_id': correlationId,
        'front_iqs': frontScore.score,
        'back_iqs': backScore.score,
        'final_grade': gradingResult.finalGrade,
        'status': saved.status.name,
      },
    );

    return EvaluationResult(
      submissionId: saved.id,
      frontScore: frontScore.score,
      backScore: backScore.score,
      status: saved.status,
      createdAt: saved.createdAt,
      correlationId: correlationId,
      gradingResult: gradingResult,
    );
  }

  Future<List<PregradeResult>> getEvaluations() async {
    return await repository.getEvaluations();
  }

  /// Saves an evaluation with `unableToGrade` status when the image cannot
  /// be processed (IQS failure or preprocessing failure).
  Future<EvaluationResult> _saveUnableToGrade({
    required SubmitEvaluationCommand command,
    required double frontScore,
    required double backScore,
    required String reason,
  }) async {
    _logGradingFailure(
      correlationId: command.correlationId,
      stage: 'unable_to_grade',
      reason: reason,
    );

    final saved = await repository.saveEvaluation(
      AddEvaluationInput(
        frontImageData: command.frontImageData,
        backImageData: command.backImageData,
        frontImageScore: frontScore,
        backImageScore: backScore,
        cardId: command.cardId,
        correlationId: command.correlationId,
        algorithmVersion: GradingOrchestrator.algorithmVersion,
        status: EvaluationStatus.unableToGrade,
      ),
    );

    AppLogger.grading(
      _loggerName,
      'Evaluation saved as unableToGrade',
      context: {
        'evaluation_id': saved.id,
        'correlation_id': command.correlationId,
        'reason': reason,
      },
    );

    return EvaluationResult(
      submissionId: saved.id,
      frontScore: frontScore,
      backScore: backScore,
      status: EvaluationStatus.unableToGrade,
      createdAt: saved.createdAt,
      correlationId: command.correlationId,
      rejectionReason: reason,
    );
  }

  void _validate(SubmitEvaluationCommand command) {
    final frontError = EvaluationValidators.validateImage(
      command.frontImageData,
    );

    if (frontError != null) {
      _throwEvaluationError(_evaluationErrorCode, frontError);
    }

    final backError = EvaluationValidators.validateImage(
      command.backImageData,
    );

    if (backError != null) {
      _throwEvaluationError(_evaluationErrorCode, backError);
    }
  }

  void _logStage({
    required String stage,
    required int durationMs,
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? outputs,
  }) {
    AppLogger.grading(
      _loggerName,
      'Evaluation stage completed',
      context: {
        'stage': stage,
        'duration_ms': durationMs,
        if (inputs != null) 'inputs': inputs,
        if (outputs != null) 'outputs': outputs,
      },
    );
  }

  void _logGradingFailure({
    required String correlationId,
    required String stage,
    required String reason,
  }) {
    AppLogger.grading(
      _loggerName,
      'Evaluation stage rejected',
      context: {
        'correlation_id': correlationId,
        'stage': stage,
        'reason': reason,
      },
    );
  }
}
