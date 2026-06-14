import '../b2b_data_provider/idempotency_repository.dart';

class MockIdempotencyRepository implements IdempotencyRepository {
  final Map<String, IdempotencyRecord> _store = {};

  String _key(int apiKeyId, String requestId) => '$apiKeyId:$requestId';

  @override
  Future<IdempotencyRecord?> find({
    required int apiKeyId,
    required String requestId,
  }) async {
    return _store[_key(apiKeyId, requestId)];
  }

  @override
  Future<void> store({
    required int apiKeyId,
    required String requestId,
    required String requestHash,
    required Map<String, dynamic> responsePayload,
    required DateTime expiresAt,
  }) async {
    final etag = responsePayload['etag']?.toString() ?? '';
    final lastModifiedStr = responsePayload['last_modified']?.toString();
    final lastModified = lastModifiedStr != null
        ? DateTime.parse(lastModifiedStr)
        : DateTime.now().toUtc();

    _store[_key(apiKeyId, requestId)] = IdempotencyRecord(
      responsePayload: Map<String, dynamic>.from(responsePayload),
      etag: etag,
      lastModified: lastModified,
    );
  }
}
