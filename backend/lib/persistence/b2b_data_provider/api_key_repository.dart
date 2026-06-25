/// @file
/// @brief API key validation for B2B service accounts.

import '../../domain/b2b/b2b_models.dart';

/// Validates API keys and resolves B2B auth context.
abstract class ApiKeyRepository {
  Future<B2bAuthContext?> keyLookUp(String plaintextKey);
  Future<DateTime?> checkGracePeriod(int apiKeyId);
}
