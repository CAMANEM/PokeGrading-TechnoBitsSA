import 'evaluation_request.dart';

class AddEvaluationInput {
  final String frontImageData;
  final String backImageData;

  final double frontImageScore;
  final double backImageScore;

  const AddEvaluationInput({
    required this.frontImageData,
    required this.backImageData,
    required this.frontImageScore,
    required this.backImageScore,
  });
}

abstract class EvaluationRepository {
  Future<EvaluationRequest> saveEvaluation(
    AddEvaluationInput input,
  );

  Future<EvaluationRequest?> findById(String id);
}
