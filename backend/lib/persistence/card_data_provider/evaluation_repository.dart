/// @file
/// @brief

import '../../domain/image_services/visual_features.dart';
import '../../domain/scoring/scoring_models.dart';

/// @brief AddEvaluationInput
class AddEvaluationInput {
  final String frontImageData;
  final String backImageData;
  final double frontImageScore;
  final double backImageScore;
  final String? cardId;
  final String correlationId;
  final VisualFeatures? frontVisualFeatures;
  final String? algorithmVersion;
  final EvaluationStatus? status;
  final PregradeResult? pregradings;

  const AddEvaluationInput(
      {required this.frontImageData,
      required this.backImageData,
      required this.frontImageScore,
      required this.backImageScore,
      required this.correlationId,
      this.cardId,
      this.frontVisualFeatures,
      this.algorithmVersion,
      this.status,
      this.pregradings});
}

/// @brief EvaluationRepository
abstract class EvaluationRepository {
  Future<EvaluationRequest> saveEvaluation(
    AddEvaluationInput input,
  );

  Future<List<PregradeResult>> getEvaluations();

  Future<EvaluationRequest?> findById(String id);
}
