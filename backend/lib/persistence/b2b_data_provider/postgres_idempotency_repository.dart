import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import 'idempotency_repository.dart';

class PostgresIdempotencyRepository implements IdempotencyRepository {
  final Connection _connection;

  PostgresIdempotencyRepository._(this._connection);

  static Future<PostgresIdempotencyRepository> connect(
    DatabaseConfig config,
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
    return PostgresIdempotencyRepository._(connection);
  }

  Future<void> close() async {
    await _connection.close();
  }

  @override
  Future<IdempotencyRecord?> find({
    required int apiKeyId,
    required String requestId,
  }) async {
    final result = await _connection.execute(
      '''
      SELECT response_json, created_at
      FROM b2b_idempotency
      WHERE api_key_id = \$1 AND request_id = \$2 AND expires_at > NOW()
      ''',
      parameters: [apiKeyId, requestId],
    );

    if (result.isEmpty) return null;

    final jsonStr = result.first[0]?.toString() ?? '{}';
    final createdAt = result.first[1] as DateTime? ?? DateTime.now().toUtc();
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    final body = decoded['body'] as Map<String, dynamic>? ?? decoded;
    final etag = decoded['etag']?.toString() ?? '';
    final lastModifiedStr = decoded['last_modified']?.toString();
    final lastModified = lastModifiedStr != null
        ? DateTime.parse(lastModifiedStr)
        : createdAt;

    return IdempotencyRecord(
      responsePayload: body,
      etag: etag,
      lastModified: lastModified,
    );
  }

  @override
  Future<void> store({
    required int apiKeyId,
    required String requestId,
    required String requestHash,
    required Map<String, dynamic> responsePayload,
    required DateTime expiresAt,
  }) async {
    final wrapper = {
      'body': responsePayload,
      'etag': responsePayload['etag'] ?? '',
      'last_modified': responsePayload['last_modified'] ?? '',
    };
    await _connection.execute(
      '''
      INSERT INTO b2b_idempotency (
        api_key_id, request_id, request_hash, response_json, created_at, expires_at
      ) VALUES (\$1, \$2, \$3, \$4::jsonb, NOW(), \$5)
      ON CONFLICT (api_key_id, request_id) DO UPDATE
        SET response_json = EXCLUDED.response_json,
            request_hash = EXCLUDED.request_hash,
            expires_at = EXCLUDED.expires_at
      ''',
      parameters: [
        apiKeyId,
        requestId,
        requestHash,
        jsonEncode(wrapper),
        expiresAt,
      ],
    );
  }
}
