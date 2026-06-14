/// @file
/// @brief Append-only audit persistence for B2B consult requests.

/// Append-only audit log for B2B consult requests.
abstract class B2bAuditRepository {
  Future<void> recordConsult({
    required int apiKeyId,
    required int customerId,
    String? requestId,
    String? ipAddress,
    required int cardCount,
    required String apiVersion,
    required String outcome,
  });
}
