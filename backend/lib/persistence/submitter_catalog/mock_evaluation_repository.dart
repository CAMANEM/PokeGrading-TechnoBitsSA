/*
 Mock in-memory implementation of `CatalogRepository` for development and tests.

 Behavior:
 - Generates card IDs using an `IdGenerator` (UUID by default).
 - Persists `PokemonCard` instances in a memory map and tracks identity
   tuples to prevent duplicates.
 - Records a simple `audit` entry when a card is created.
*/
import '../../domain/submitter_catalog/submit_evaluation/evaluation_repository.dart';
import '../../domain/submitter_catalog/submit_evaluation/evaluation_request.dart';
import 'id_generator.dart';

class MockEvaluationRepository implements EvaluationRepository {
  final IdGenerator _idGenerator;
  final Map<String, EvaluationRequest> _requests =
      <String, EvaluationRequest>{};

  final List<SecurityAuditEvent> _auditEvents = <SecurityAuditEvent>[];

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
      status: EvaluationStatus.pending,
      createdAt: now,
    );

    _requests[id] = request;
    return request;
  }

  @override
  Future<EvaluationRequest?> findById(String id) async {
    return _requests[id];
  }

  @override
  Future<void> saveSecurityAudit(
    SecurityAuditEvent event,
  ) async {
    _auditEvents.add(event);
  }
}
