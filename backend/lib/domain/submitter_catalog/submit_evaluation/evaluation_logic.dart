import 'evaluation_repository.dart';
import 'evaluation_request.dart';
import 'evaluation_validators.dart';
import 'image_quality_service.dart';
import 'polyglot_detection.dart';

class SubmitEvaluationLogicException implements Exception {
  /// Short error code for programmatic handling.
  final String code;

  /// Human readable message describing the reason for the exception.
  final String message;

  const SubmitEvaluationLogicException(
      {required this.code, required this.message});

  @override
  String toString() => 'SubmitEvaluationLogicException($code): $message';
}

class SubmitEvaluationCommand {
  final String frontImageData;
  final String backImageData;

  const SubmitEvaluationCommand({
    required this.frontImageData,
    required this.backImageData,
  });
}

class EvaluationSubmittedResult {
  final String submissionId;

  final double frontScore;
  final double backScore;

  final EvaluationStatus status;

  final DateTime createdAt;

  const EvaluationSubmittedResult({
    required this.submissionId,
    required this.frontScore,
    required this.backScore,
    required this.status,
    required this.createdAt,
  });
}

class SubmitEvaluationLogic {
  final EvaluationRepository repository;
  final ImageQualityService imageQualityService;
  final PolyglotDetector polyglotDetector;

  const SubmitEvaluationLogic({
    required this.repository,
    required this.imageQualityService,
    required this.polyglotDetector,
  });

  Future<EvaluationSubmittedResult> submit(
    SubmitEvaluationCommand command,
  ) async {
    _validate(command);

    final frontScore = await imageQualityService.calculateScore(
      command.frontImageData,
    );

    if (frontScore.score < 60) {
      throw SubmitEvaluationLogicException(
        code: 'image_rejected',
        message:
            'Front image obtained ${frontScore.score.toStringAsFixed(1)} for IQS. '
            'Reasons: ${frontScore.rejectionReasons.join(", ")}',
      );
    }

    final backScore = await imageQualityService.calculateScore(
      command.backImageData,
    );

    if (backScore.score < 60) {
      throw SubmitEvaluationLogicException(
        code: 'image_rejected',
        message:
            'Back image obtained ${backScore.score.toStringAsFixed(1)} for IQS. '
            'Reasons: ${backScore.rejectionReasons.join(", ")}',
      );
    }

    final frontPolyglotResult =
        polyglotDetector.inspect(command.frontImageData);

    if (frontPolyglotResult.isPolyglot) {
      await repository.saveSecurityAudit(
        SecurityAuditEvent(
          eventType: 'polyglot_detected',
          details: 'Polyglot detected in front image',
          timestamp: DateTime.now().toUtc(),
        ),
      );

      throw SubmitEvaluationLogicException(
        code: 'image_rejected',
        message: 'Malicious file detected in Front Image',
      );
    }

    final backPolyglotResult = polyglotDetector.inspect(command.backImageData);

    if (backPolyglotResult.isPolyglot) {
      await repository.saveSecurityAudit(
        SecurityAuditEvent(
          eventType: 'polyglot_detected',
          details: 'Polyglot detected in back image',
          timestamp: DateTime.now().toUtc(),
        ),
      );

      throw SubmitEvaluationLogicException(
        code: 'image_rejected',
        message: 'Malicious file detected in Back Image',
      );
    }

    final saved = await repository.saveEvaluation(
      AddEvaluationInput(
        frontImageData: command.frontImageData,
        backImageData: command.backImageData,
        frontImageScore: frontScore.score,
        backImageScore: backScore.score,
      ),
    );

    return EvaluationSubmittedResult(
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
      throw SubmitEvaluationLogicException(
        code: 'image_rejected',
        message: frontError,
      );
    }

    final backError = EvaluationValidators.validateImage(
      command.backImageData,
    );

    if (backError != null) {
      throw SubmitEvaluationLogicException(
        code: 'image_rejected',
        message: backError,
      );
    }
  }
}
