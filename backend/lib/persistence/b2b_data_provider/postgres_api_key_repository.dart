/// @file
/// @brief PostgreSQL implementation of [ApiKeyRepository].

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
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
    final connection = await Connection.open(endpoint, settings: settings);
    return PostgresApiKeyRepository._(connection, hasher);
  }

  Future<void> close() async {
    await _connection.close();
  }

  @override
  Future<B2bAuthContext?> validateKey(String plaintextKey) async {
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

    if (result.isEmpty) return null;

    final row = result.first;
    final apiKeyStatus = row[2]?.toString() ?? '';
    final customerStatus = row[3]?.toString() ?? '';

    if (apiKeyStatus == 'revoked') {
      final graceEnds = await _connection.execute(
        'SELECT grace_period_ends_at FROM b2b_api_key WHERE id = \$1',
        parameters: [row[0]],
      );
      if (graceEnds.isNotEmpty && graceEnds.first.first != null) {
        final grace = graceEnds.first.first as DateTime;
        if (DateTime.now().toUtc().isAfter(grace)) {
          return null;
        }
      } else {
        return null;
      }
    }

    if (apiKeyStatus != 'active' && apiKeyStatus != 'revoked') {
      return null;
    }

    return B2bAuthContext(
      apiKeyId: row[0] as int,
      customerId: row[1] as int,
      customerStatus: customerStatus,
      apiKeyStatus: apiKeyStatus,
    );
  }
}
