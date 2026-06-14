/// @file
/// @brief

import '../../domain/scoring/scoring_models.dart';

/// @brief AddEvaluationInput
class AddEvaluationInput {
  final String frontImageData;
  final String backImageData;
  final double frontImageScore;
  final double backImageScore;
  final String? cardId;
  final String correlationId;

  const AddEvaluationInput({
    required this.frontImageData,
    required this.backImageData,
    required this.frontImageScore,
    required this.backImageScore,
    required this.correlationId,
    this.cardId,
  });
}

/// @brief EvaluationRepository
abstract class EvaluationRepository {
  Future<EvaluationRequest> saveEvaluation(
    AddEvaluationInput input,
  );

  Future<EvaluationRequest?> findById(String id);
}
