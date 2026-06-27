/// @file
/// @brief

enum EvaluationStatus {
  pending,
  underReview,
  completed,
  rejected,
}

/// @brief EvaluationRequest
class EvaluationRequest {
  final String id;
  final String frontImageData;
  final String backImageData;
  final double frontImageScore;
  final double backImageScore;
  final EvaluationStatus status;
  final DateTime createdAt;
  final String? cardId;
  final String? logId;

  const EvaluationRequest({
    required this.id,
    required this.frontImageData,
    required this.backImageData,
    required this.frontImageScore,
    required this.backImageScore,
    required this.status,
    required this.createdAt,
    this.cardId,
    this.logId,
  });
}

class GradingResult {
  final double centerGrade;
  final double cornersGrade;
  final double edgesGrade;
  final double surfaceGrade;
  final double finalGrade;

  const GradingResult(
      {required this.centerGrade,
      required this.cornersGrade,
      required this.edgesGrade,
      required this.surfaceGrade,
      required this.finalGrade});
}
