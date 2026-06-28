/// @file
/// @brief

enum EvaluationStatus {
  pending,
  underReview,
  completed,
  rejected,
  unableToGrade,
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
  final String? algorithmVersion;

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
    this.algorithmVersion,
  });
}

class PregradeResult {
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

  const PregradeResult(
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

  Map<String, dynamic> toJson() {
    return {
      'grade_id': gradeId,
      'status': status,
      'submitted_date': submittedDate,
      'centering_grade': centering_grade,
      'corners_grade': corners_grade,
      'edges_grade': edges_grade,
      'surface_grade': surface_grade,
      'grade': grade,
      'confidence': confidence,
      'graded_date': gradedDate,
    };
  }
}
