import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import 'b2b_audit_repository.dart';

class PostgresB2bAuditRepository implements B2bAuditRepository {
  final Connection _connection;

  PostgresB2bAuditRepository._(this._connection);

  static Future<PostgresB2bAuditRepository> connect(DatabaseConfig config) async {
    AppLogger.info(
      'PokéGrading.Persistence.B2bAuditRepository',
      'Connecting to PostgreSQL B2B audit database',
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
        'PokéGrading.Persistence.B2bAuditRepository',
        'PostgreSQL B2B audit repository connected',
      );
      return PostgresB2bAuditRepository._(connection);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.B2bAuditRepository',
        'Failed to connect to PostgreSQL B2B audit database',
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
  Future<void> recordConsult({
    required int apiKeyId,
    required int customerId,
    String? requestId,
    String? ipAddress,
    required int cardCount,
    required String apiVersion,
    required String outcome,
  }) async {
    try {
      await _connection.execute(
        '''
        INSERT INTO b2b_consult_audit (
          api_key_id, customer_id, request_id, ip_address,
          card_count, api_version, outcome, created_at
        ) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, NOW())
        ''',
        parameters: [
          apiKeyId,
          customerId,
          requestId,
          ipAddress,
          cardCount,
          apiVersion,
          outcome,
        ],
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.B2bAuditRepository',
        'Failed to record B2B consult audit',
        context: {
          'api_key_id': apiKeyId,
          'customer_id': customerId,
          'outcome': outcome,
        },
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
