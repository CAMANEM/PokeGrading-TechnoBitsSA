import 'evaluation_request.dart';

class AddEvaluationInput {
  final String frontImageData;
  final String backImageData;

  final double frontImageScore;
  final double backImageScore;
  final String? cardId;

  const AddEvaluationInput({
    required this.frontImageData,
    required this.backImageData,
    required this.frontImageScore,
    required this.backImageScore,
    this.cardId,
  });
}

class SecurityAuditEvent {
  final String eventType;
  final String details;
  final DateTime timestamp;

  const SecurityAuditEvent({
    required this.eventType,
    required this.details,
    required this.timestamp,
  });
}

abstract class EvaluationRepository {
  Future<EvaluationRequest> saveEvaluation(
    AddEvaluationInput input,
  );

  Future<EvaluationRequest?> findById(String id);

  Future<void> saveSecurityAudit(
    SecurityAuditEvent event,
  );
}
