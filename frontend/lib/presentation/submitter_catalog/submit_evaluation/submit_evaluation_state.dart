/// @file
/// @brief

enum SubmitEvaluationStage {
  capture,
  validating,
  submitting,
  success,
  error,
}

/// @brief SubmitEvaluationPayload
class SubmitEvaluationPayload {
  final String frontImageData;
  final String backImageData;
  final String? cardId;

  const SubmitEvaluationPayload({
    required this.frontImageData,
    required this.backImageData,
    this.cardId,
  });
}

/// @brief SubmitEvaluationResult
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

/// @brief SubmitEvaluationState
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

class Grading {
  final int gradeId;
  final String status;
  final String submittedDate;
  final double? centering_grade;
  final double? corners_grade;
  final double? edges_grade;
  final double? surface_grade;
  final double? grade;
  final double? confidence;
  final String? gradedDate;

  const Grading(
      {required this.gradeId,
      required this.status,
      required this.submittedDate,
      this.centering_grade,
      this.corners_grade,
      this.edges_grade,
      this.surface_grade,
      this.grade,
      this.confidence,
      this.gradedDate});

  factory Grading.fromJson(Map<String, dynamic> json) {
    return Grading(
        gradeId: json['grade_id'],
        status: json['status'],
        submittedDate: json['submitted_date'],
        centering_grade: json['centering_grade'],
        corners_grade: json['corners_grade'],
        edges_grade: json['edges_grade'],
        surface_grade: json['surface_grade'],
        grade: json['grade'],
        confidence: json['confidence'],
        gradedDate: json['graded_date']);
  }
}
