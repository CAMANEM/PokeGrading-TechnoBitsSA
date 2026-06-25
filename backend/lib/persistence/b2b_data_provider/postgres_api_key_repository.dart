/// @file
/// @brief PostgreSQL implementation of [ApiKeyRepository].

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/security/api_key_hasher.dart';
import '../../domain/b2b/b2b_models.dart';
import 'api_key_repository.dart';

class PostgresApiKeyRepository implements ApiKeyRepository {
  final Connection _connection;
  final ApiKeyHasher _hasher;

  PostgresApiKeyRepository._(this._connection, this._hasher);

  static Future<PostgresApiKeyRepository> connect(
    DatabaseConfig config,
    ApiKeyHasher hasher,
  ) async {
    AppLogger.info(
      'PokéGrading.Persistence.ApiKeyRepository',
      'Connecting to PostgreSQL API key database',
      context: {'host': config.host, 'database': config.name},
    );
    final endpoint = Endpoint(
      host: config.host,
      port: config.port,
      database: config.name,
      username: config.user,
      password: config.password,
    );
    final settings = ConnectionSettings(
      connectTimeout: config.connectionTimeout,
      sslMode: SslMode.disable,
    );
    try {
      final connection = await Connection.open(endpoint, settings: settings);
      AppLogger.info(
        'PokéGrading.Persistence.ApiKeyRepository',
        'PostgreSQL API key repository connected',
      );
      return PostgresApiKeyRepository._(connection, hasher);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.ApiKeyRepository',
        'Failed to connect to PostgreSQL API key database',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> close() async {
    await _connection.close();
  }

  @override
  Future<B2bAuthContext?> keyLookUp(String plaintextKey) async {
    try {
      final keyHash = _hasher.hash(plaintextKey);
      final result = await _connection.execute(
        '''
        SELECT k.id, k.customer_id, k.status, c.status AS customer_status
        FROM b2b_api_key k
        INNER JOIN b2b_customer c ON c.id = k.customer_id
        WHERE k.key_hash = \$1
        LIMIT 1
        ''',
        parameters: [keyHash],
      );

      if (result.isEmpty) {
        AppLogger.warning(
          'PokéGrading.Persistence.ApiKeyRepository',
          'API key validation failed - key not found',
        );
        return null;
      }

      final row = result.first;
      final apiKeyStatus = row[2]?.toString() ?? '';
      final customerStatus = row[3]?.toString() ?? '';

      return B2bAuthContext(
        apiKeyId: row[0] as int,
        customerId: row[1] as int,
        customerStatus: customerStatus,
        apiKeyStatus: apiKeyStatus,
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.ApiKeyRepository',
        'API key validation failed with error',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<DateTime?> checkGracePeriod(int apiKeyId) async {
    final result = await _connection.execute(
      'SELECT grace_period_ends_at FROM b2b_api_key WHERE id = \$1',
      parameters: [apiKeyId],
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first.first as DateTime?;
  }
}
