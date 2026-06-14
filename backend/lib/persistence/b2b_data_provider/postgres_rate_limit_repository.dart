import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import 'rate_limit_repository.dart';

class PostgresRateLimitRepository implements RateLimitRepository {
  final Connection _connection;

  PostgresRateLimitRepository._(this._connection);

  static Future<PostgresRateLimitRepository> connect(
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
    return PostgresRateLimitRepository._(connection);
  }

  Future<void> close() async {
    await _connection.close();
  }

  String _windowKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  int _secondsUntilNextMonth() {
    final now = DateTime.now().toUtc();
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    return nextMonth.difference(now).inSeconds;
  }

  @override
  Future<int?> tryConsume({
    required int apiKeyId,
    required int cardCount,
    required int monthlyLimit,
  }) async {
    final windowKey = _windowKey();

    return _connection.runTx<int?>((tx) async {
      final existing = await tx.execute(
        '''
        SELECT cards_consumed FROM b2b_rate_usage
        WHERE api_key_id = \$1 AND window_key = \$2
        FOR UPDATE
        ''',
        parameters: [apiKeyId, windowKey],
      );

      var consumed = 0;
      if (existing.isNotEmpty) {
        consumed = existing.first.first as int;
      }

      if (consumed + cardCount > monthlyLimit) {
        return _secondsUntilNextMonth();
      }

      if (existing.isEmpty) {
        await tx.execute(
          '''
          INSERT INTO b2b_rate_usage (api_key_id, window_key, cards_consumed)
          VALUES (\$1, \$2, \$3)
          ''',
          parameters: [apiKeyId, windowKey, cardCount],
        );
      } else {
        await tx.execute(
          '''
          UPDATE b2b_rate_usage
          SET cards_consumed = cards_consumed + \$3
          WHERE api_key_id = \$1 AND window_key = \$2
          ''',
          parameters: [apiKeyId, windowKey, cardCount],
        );
      }

      return null;
    });
  }
}
