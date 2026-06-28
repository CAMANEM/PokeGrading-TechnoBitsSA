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
  final String? setName;
  final String? setFinish;

  const SubmitEvaluationPayload({
    required this.frontImageData,
    required this.backImageData,
    this.cardId,
    this.setName,
    this.setFinish,
  });
}

/// @brief SubmitEvaluationResult
class SubmitEvaluationResult {
  final String evaluationId;
  final String status;
  final DateTime createdAt;
  final String? estimatedTime;
  final Map<String, dynamic>? gradingResult;
  final String? rejectionReason;
  final String? algorithmVersion;

  const SubmitEvaluationResult({
    required this.evaluationId,
    required this.status,
    required this.createdAt,
    this.estimatedTime,
    this.gradingResult,
    this.rejectionReason,
    this.algorithmVersion,
  });

  /// Whether the evaluation completed with a grade.
  bool get hasGrading => gradingResult != null;

  /// Whether the evaluation needs manual review.
  bool get needsReview => status == 'underReview' || status == 'under_review';

  /// Whether the evaluation could not be graded.
  bool get unableToGrade => status == 'unableToGrade' || status == 'unable_to_grade';

  /// Final grade from the grading result, if available.
  double? get finalGrade => gradingResult?['final_grade'] as double?;

  /// Confidence from the grading result, if available.
  double? get confidence => gradingResult?['confidence'] as double?;

  /// Lower bound of the uncertainty band.
  double? get gradeLowerBound => gradingResult?['grade_lower_bound'] as double?;

  /// Upper bound of the uncertainty band.
  double? get gradeUpperBound => gradingResult?['grade_upper_bound'] as double?;

  /// Whether the coherence rule was applied.
  bool get coherenceApplied => gradingResult?['coherence_rule_applied'] as bool? ?? false;

  /// Centering grade.
  double? get centeringGrade => gradingResult?['centering_grade'] as double?;

  /// Corners grade.
  double? get cornersGrade => (gradingResult?['corners'] as Map<String, dynamic>?)?['grade'] as double?;

  /// Edges grade.
  double? get edgesGrade => (gradingResult?['edges'] as Map<String, dynamic>?)?['grade'] as double?;

  /// Surface grade.
  double? get surfaceGrade => (gradingResult?['surface'] as Map<String, dynamic>?)?['grade'] as double?;

  /// Explanation text.
  String? get explanation => gradingResult?['explanation']?.toString();

  /// Baseline version used.
  String? get baselineVersion => gradingResult?['baseline_version']?.toString();

  /// Whether a calibrated baseline was used.
  bool get isCalibrated => gradingResult?['baseline_is_calibrated'] as bool? ?? false;
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
