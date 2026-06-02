enum SubmitEvaluationStage {
  capture,
  validating,
  submitting,
  success,
  error,
}

class SubmitEvaluationPayload {
  final String frontImageData;
  final String backImageData;

  const SubmitEvaluationPayload({
    required this.frontImageData,
    required this.backImageData,
  });
}

class SubmitEvaluationResult {
  final String evaluationId;
  final String status;
  final DateTime createdAt;
  final String? estimatedTime;

  const SubmitEvaluationResult({
    required this.evaluationId,
    required this.status,
    required this.createdAt,
    this.estimatedTime,
  });
}

class SubmitEvaluationState {
  final SubmitEvaluationStage stage;
  final SubmitEvaluationResult? result;
  final String? message;

  const SubmitEvaluationState({
    required this.stage,
    this.result,
    this.message,
  });

  const SubmitEvaluationState.initial()
      : stage = SubmitEvaluationStage.capture,
        result = null,
        message = null;

  SubmitEvaluationState copyWith({
    SubmitEvaluationStage? stage,
    SubmitEvaluationResult? result,
    String? message,
  }) {
    return SubmitEvaluationState(
      stage: stage ?? this.stage,
      result: result ?? this.result,
      message: message,
    );
  }
}
