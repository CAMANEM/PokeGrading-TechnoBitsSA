/// @file
/// @brief

import 'scoring_models.dart';
import 'scoring_validators.dart';
import '../image_services/image_quality_service.dart';
import '../image_services/polyglot_detection.dart';
import '../../persistence/card_data_provider/evaluation_repository.dart';
import '../../shared/exception_service/exception_handler.dart';

Never _throwEvaluationError(String code, String err) {
  throw LogicException(feature: 'submit-evaluation', code: code, message: err);
}

/// @brief SubmitEvaluationCommand
class SubmitEvaluationCommand {
  final String frontImageData;
  final String backImageData;
  final String? cardId;

  const SubmitEvaluationCommand({
    required this.frontImageData,
    required this.backImageData,
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

  const EvaluationResult({
    required this.submissionId,
    required this.frontScore,
    required this.backScore,
    required this.status,
    required this.createdAt,
  });
}

/// @brief SubmitEvaluationLogic
class EvaluationLogic {
  final EvaluationRepository repository;
  static const String _evaluationErrorCode = 'image_rejected';

  const EvaluationLogic({required this.repository});

  Future<EvaluationResult> submit(
    SubmitEvaluationCommand command,
  ) async {
    _validate(command);

    final frontScore = await ImageQualityService.calculateScore(
      command.frontImageData,
    );

    if (frontScore.score < ImageQualityService.acceptedThreshold) {
      _throwEvaluationError(
        _evaluationErrorCode,
        'Imagen frontal no supera el IQS (${frontScore.score.toStringAsFixed(1)}/100). '
        'Motivos: ${frontScore.rejectionReasons.join(", ")}',
      );
    }

    final backScore = await ImageQualityService.calculateScore(
      command.backImageData,
    );

    if (backScore.score < ImageQualityService.acceptedThreshold) {
      _throwEvaluationError(
        _evaluationErrorCode,
        'Imagen trasera no supera el IQS (${backScore.score.toStringAsFixed(1)}/100). '
        'Motivos: ${backScore.rejectionReasons.join(", ")}',
      );
    }

    final frontPolyglotResult =
        PolyglotDetector.inspect(command.frontImageData);

    if (frontPolyglotResult.isPolyglot) {
      await repository.saveSecurityAudit(
        SecurityAuditEvent(
          eventType: 'polyglot_detected',
          details: 'Polyglot detected in front image',
          timestamp: DateTime.now().toUtc(),
        ),
      );

      _throwEvaluationError(
        _evaluationErrorCode,
        'Se detecto una archivo malicioso para la imagen frontal. '
        'Indicadores: ${frontPolyglotResult.indicators.join(', ')}',
      );
    }

    final backPolyglotResult = PolyglotDetector.inspect(command.backImageData);

    if (backPolyglotResult.isPolyglot) {
      await repository.saveSecurityAudit(
        SecurityAuditEvent(
          eventType: 'polyglot_detected',
          details: 'Polyglot detected in back image',
          timestamp: DateTime.now().toUtc(),
        ),
      );

      _throwEvaluationError(
        _evaluationErrorCode,
        'Se detecto un archivo malicioso para la imagen trasera. '
        'Indicadores: ${backPolyglotResult.indicators.join(', ')}',
      );
    }

    final saved = await repository.saveEvaluation(
      AddEvaluationInput(
        frontImageData: command.frontImageData,
        backImageData: command.backImageData,
        frontImageScore: frontScore.score,
        backImageScore: backScore.score,
        cardId: command.cardId,
      ),
    );

    return EvaluationResult(
      submissionId: saved.id,
      frontScore: frontScore.score,
      backScore: backScore.score,
      status: saved.status,
      createdAt: saved.createdAt,
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
}
