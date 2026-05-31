import 'evaluation_repository.dart';
import 'evaluation_request.dart';
import 'evaluation_validators.dart';
import 'image_quality_service.dart';

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

  const SubmitEvaluationLogic({
    required this.repository,
    required this.imageQualityService,
  });

  Future<EvaluationSubmittedResult> submit(
    SubmitEvaluationCommand command,
  ) async {
    _validate(command);

    final frontScore = await imageQualityService.calculateScore(
      command.frontImageData,
    );

    final backScore = await imageQualityService.calculateScore(
      command.backImageData,
    );

    final saved = await repository.saveEvaluation(
      AddEvaluationInput(
        frontImageData: command.frontImageData,
        backImageData: command.backImageData,
        frontImageScore: frontScore,
        backImageScore: backScore,
      ),
    );

    return EvaluationSubmittedResult(
      submissionId: saved.id,
      frontScore: frontScore,
      backScore: backScore,
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
