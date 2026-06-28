/// @file
/// @brief

import 'scoring_models.dart';
import 'scoring_validators.dart';
import '../image_services/image_quality_service.dart';
import '../image_services/polyglot_detection.dart';
import '../image_services/visual_features.dart';
import '../../core/logging/app_logger.dart';
import '../../persistence/card_data_provider/evaluation_repository.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';
import 'package:pokegrading_logging/pokegrading_logging.dart';
import '../image_services/preprocessing/preprocessing_service.dart';
import 'grading/pregrading.dart';

Never _throwEvaluationError(String code, String err) {
  throw LogicException(feature: 'submit-evaluation', code: code, message: err);
}

/// @brief SubmitEvaluationCommand
class SubmitEvaluationCommand {
  final String frontImageData;
  final String backImageData;
  final String? cardId;
  final String correlationId;

  const SubmitEvaluationCommand({
    required this.frontImageData,
    required this.backImageData,
    required this.correlationId,
    this.cardId,
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

  const EvaluationResult({
    required this.submissionId,
    required this.frontScore,
    required this.backScore,
    required this.status,
    required this.createdAt,
    required this.correlationId,
  });
}

/// @brief SubmitEvaluationLogic
class EvaluationLogic {
  static const _loggerName = 'PokéGrading.Evaluation';

  final EvaluationRepository repository;
  static const String _evaluationErrorCode = 'image_rejected';

  const EvaluationLogic({required this.repository});

  Future<EvaluationResult> submit(
    SubmitEvaluationCommand command,
  ) async {
    final correlationId = command.correlationId;

    _validate(command);

    final frontIqsStarted = DateTime.now().toUtc();
    final frontScore = await ImageQualityService.calculateScore(
      command.frontImageData,
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
      context: {
        'stage': 'iqs_front',
        'duration_ms': frontIqsDuration,
      },
    );

    if (frontScore.score < ImageQualityService.acceptedThreshold) {
      _logGradingFailure(
        correlationId: correlationId,
        stage: 'iqs_front',
        reason: frontScore.rejectionReasons.join(', '),
      );
      _throwEvaluationError(
        _evaluationErrorCode,
        'Imagen frontal no supera el IQS (${frontScore.score.toStringAsFixed(1)}/100). '
        'Motivos: ${frontScore.rejectionReasons.join(", ")}',
      );
    }

    final backIqsStarted = DateTime.now().toUtc();
    final backScore = await ImageQualityService.calculateScore(
      command.backImageData,
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
      context: {
        'stage': 'iqs_back',
        'duration_ms': backIqsDuration,
      },
    );

    if (backScore.score < ImageQualityService.acceptedThreshold) {
      _logGradingFailure(
        correlationId: correlationId,
        stage: 'iqs_back',
        reason: backScore.rejectionReasons.join(', '),
      );
      _throwEvaluationError(
        _evaluationErrorCode,
        'Imagen trasera no supera el IQS (${backScore.score.toStringAsFixed(1)}/100). '
        'Motivos: ${backScore.rejectionReasons.join(", ")}',
      );
    }

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

    final persistStarted = DateTime.now().toUtc();

    /// Preprocess image as part of evaluation process
    /// final correctedImage = PreprocessingService.preproces(command.frontiImageData);
    /// TODO

    final correctedFrontImage =
        PreprocessingService.preprocess(command.frontImageData);

    if (correctedFrontImage.rois == null) {
      _throwEvaluationError(
        _evaluationErrorCode,
        'No se pudieron extraer las regiones de interes (ROIs) de la imagen frontal.',
      );
    }

    final gradeResult = Grading.subgrades(correctedFrontImage.rois!);

    final frontFeatures =
        VisualFeatureExtractor.extract(command.frontImageData);

    final saved = await repository.saveEvaluation(
        AddEvaluationInput(
          frontImageData: command.frontImageData,
          backImageData: command.backImageData,
          frontImageScore: frontScore.score,
          backImageScore: backScore.score,
          cardId: command.cardId,
          correlationId: correlationId,
          frontVisualFeatures: frontFeatures,
        ),
        gradeResult);
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
      },
    );

    return EvaluationResult(
      submissionId: saved.id,
      frontScore: frontScore.score,
      backScore: backScore.score,
      status: saved.status,
      createdAt: saved.createdAt,
      correlationId: correlationId,
    );
  }

  void _validate(
    SubmitEvaluationCommand command,
  ) {
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
