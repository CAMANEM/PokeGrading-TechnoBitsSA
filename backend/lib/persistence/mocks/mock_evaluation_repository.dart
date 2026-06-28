/*
 Mock in-memory implementation of `EvaluationRepository` for development and tests.
*/
import '../card_data_provider/evaluation_repository.dart';
import '../../domain/scoring/scoring_models.dart';
import '../id_service/id_generator.dart';

/// @brief MockEvaluationRepository
class MockEvaluationRepository implements EvaluationRepository {
  final IdGenerator _idGenerator;
  final Map<String, EvaluationRequest> _requests =
      <String, EvaluationRequest>{};

  MockEvaluationRepository({IdGenerator? idGenerator})
      : _idGenerator = idGenerator ?? UuidIdGenerator();

  @override
  Future<EvaluationRequest> saveEvaluation(AddEvaluationInput input) async {
    final id = _idGenerator.generateCardId();
    final now = DateTime.now().toUtc();
    final request = EvaluationRequest(
      id: id,
      frontImageData: input.frontImageData.trim(),
      backImageData: input.backImageData.trim(),
      frontImageScore: input.frontImageScore,
      backImageScore: input.backImageScore,
      status: input.status ?? EvaluationStatus.pending,
      createdAt: now,
      cardId: input.cardId,
      logId: input.correlationId,
      algorithmVersion: input.algorithmVersion,
    );

    _requests[id] = request;
    return request;
  }

  @override
  Future<EvaluationRequest?> findById(String id) async {
    return _requests[id];
  }

  @override
  Future<List<PregradeResult>> getEvaluations() {
    // TODO: implement getEvaluations
    throw UnimplementedError();
  }
}
