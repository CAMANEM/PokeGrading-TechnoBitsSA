import '../b2b_data_provider/b2b_audit_repository.dart';

class MockB2bAuditRepository implements B2bAuditRepository {
  final List<Map<String, dynamic>> records = [];

  @override
  Future<void> recordConsult({
    required int apiKeyId,
    required int customerId,
    String? requestId,
    String? ipAddress,
    required int cardCount,
    required String apiVersion,
    required String outcome,
  }) async {
    records.add({
      'api_key_id': apiKeyId,
      'customer_id': customerId,
      'request_id': requestId,
      'ip_address': ipAddress,
      'card_count': cardCount,
      'api_version': apiVersion,
      'outcome': outcome,
    });
  }
}
