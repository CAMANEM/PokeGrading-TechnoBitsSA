/// @file
/// @brief Idempotency store for B2B consult replays.

/// Idempotency store for B2B consult replays.
abstract class IdempotencyRepository {
  Future<IdempotencyRecord?> find({
    required int apiKeyId,
    required String requestId,
  });

  Future<void> store({
    required int apiKeyId,
    required String requestId,
    required String requestHash,
    required Map<String, dynamic> responsePayload,
    required DateTime expiresAt,
  });
}

class IdempotencyRecord {
  final Map<String, dynamic> responsePayload;
  final String etag;
  final DateTime lastModified;

  const IdempotencyRecord({
    required this.responsePayload,
    required this.etag,
    required this.lastModified,
  });
}
