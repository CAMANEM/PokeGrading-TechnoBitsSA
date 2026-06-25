import '../../domain/b2b/b2b_models.dart';
import '../b2b_data_provider/api_key_repository.dart';

class MockApiKeyRepository implements ApiKeyRepository {
  final String devApiKey;

  MockApiKeyRepository({
    required this.devApiKey,
  });

  @override
  Future<B2bAuthContext?> keyLookUp(String plaintextKey) async {
    if (plaintextKey.trim() != devApiKey.trim()) {
      return null;
    }
    return const B2bAuthContext(
      apiKeyId: 1,
      customerId: 1,
      customerStatus: 'active',
      apiKeyStatus: 'active',
    );
  }

  @override
  Future<DateTime?> checkGracePeriod(int apiKeyId) {
    // TODO: implement checkGracePeriod
    throw UnimplementedError();
  }
}
