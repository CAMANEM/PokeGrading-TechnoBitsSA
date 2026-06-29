import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import 'rate_limit_repository.dart';

class PostgresRateLimitRepository implements RateLimitRepository {
  final Connection _connection;

  PostgresRateLimitRepository._(this._connection);

  static Future<PostgresRateLimitRepository> connect(
    DatabaseConfig config,
  ) async {
    AppLogger.info(
      'PokéGrading.Persistence.RateLimitRepository',
      'Connecting to PostgreSQL rate limit database',
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
        'PokéGrading.Persistence.RateLimitRepository',
        'PostgreSQL rate limit repository connected',
      );
      return PostgresRateLimitRepository._(connection);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.RateLimitRepository',
        'Failed to connect to PostgreSQL rate limit database',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> close() async {
    await _connection.close();
  }

  String _windowKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Future<int> obtainConsumed({
    required int apiKeyId,
  }) async {
    try {
      final windowKey = _windowKey();

      return _connection.runTx<int>((tx) async {
        final existing = await tx.execute(
          '''
          SELECT cards_consumed FROM b2b_rate_usage
          WHERE api_key_id = \$1 AND window_key = \$2
          FOR UPDATE
          ''',
          parameters: [apiKeyId, windowKey],
        );

        if (existing.isNotEmpty) {
          return existing.first.first as int;
        }

        return 0;
      });
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.RateLimitRepository',
        'Rate limit consumption failed',
        context: {'api_key_id': apiKeyId},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<void> recordConsume(
      {required int apiKeyId, required int cardsConsumed}) {
    try {
      final windowKey = _windowKey();
      return _connection.runTx<void>((tx) async {
        await tx.execute(
          '''
            INSERT INTO b2b_rate_usage (api_key_id, window_key, cards_consumed)
            VALUES (\$1, \$2, \$3)
            ''',
          parameters: [apiKeyId, windowKey, cardsConsumed],
        );
      });
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.RateLimitRepository',
        'Rate limit inserting failed',
        context: {
          'api_key_id': apiKeyId,
          'card_count': cardsConsumed,
        },
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateConsume(
      {required int apiKeyId, required int cardsConsumed}) {
    try {
      final windowKey = _windowKey();
      return _connection.runTx<void>((tx) async {
        await tx.execute(
          '''
            UPDATE b2b_rate_usage
            SET cards_consumed = cards_consumed + \$3
            WHERE api_key_id = \$1 AND window_key = \$2
            ''',
          parameters: [apiKeyId, windowKey, cardsConsumed],
        );
      });
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.RateLimitRepository',
        'Rate limit updating failed',
        context: {
          'api_key_id': apiKeyId,
          'card_count': cardsConsumed,
        },
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
