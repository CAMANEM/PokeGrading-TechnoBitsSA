import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/scoring/grading/baseline_config.dart';
import '../../domain/scoring/grading/baseline_registry.dart';
import 'calibrated_baseline_repository.dart';

class PostgresCalibratedBaselineRepository
    implements CalibratedBaselineRepository {
  final Connection _connection;

  PostgresCalibratedBaselineRepository._(this._connection);

  static Future<PostgresCalibratedBaselineRepository> connect(
    DatabaseConfig config,
  ) async {
    AppLogger.info(
      'PokéGrading.Persistence.CalibratedBaselineRepository',
      'Connecting to PostgreSQL calibrated baseline database',
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
        'PokéGrading.Persistence.CalibratedBaselineRepository',
        'PostgreSQL calibrated baseline repository connected',
      );
      return PostgresCalibratedBaselineRepository._(connection);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CalibratedBaselineRepository',
        'Failed to connect to PostgreSQL calibrated baseline database',
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
  Future<void> storeBaseline(StoreBaselineInput input) async {
    try {
      await _connection.execute(
        '''
        INSERT INTO calibrated_baseline (
          set_name, finish, baseline_version, description, config_json,
          reference_card_count, average_psa_grade, psa_grade_std_dev,
          quality_score, calibrated_at, active, created_at, modified_at
        ) VALUES (
          \$1, \$2, \$3, \$4, \$5::jsonb,
          \$6, \$7, \$8,
          \$9, NOW(), true, NOW(), NOW()
        )
        ON CONFLICT (LOWER(set_name), LOWER(finish)) WHERE active = true
        DO UPDATE SET
          baseline_version = EXCLUDED.baseline_version,
          description = EXCLUDED.description,
          config_json = EXCLUDED.config_json,
          reference_card_count = EXCLUDED.reference_card_count,
          average_psa_grade = EXCLUDED.average_psa_grade,
          psa_grade_std_dev = EXCLUDED.psa_grade_std_dev,
          quality_score = EXCLUDED.quality_score,
          calibrated_at = NOW(),
          modified_at = NOW()
        ''',
        parameters: [
          input.setName,
          input.finish,
          input.config.version,
          input.config.description,
          jsonEncode(input.config.toJson()),
          input.referenceCardCount,
          input.averagePsaGrade,
          input.psaGradeStdDev,
          input.qualityScore,
        ],
      );

      AppLogger.info(
        'PokéGrading.Persistence.CalibratedBaselineRepository',
        'Baseline stored',
        context: {
          'set_name': input.setName,
          'finish': input.finish,
          'version': input.config.version,
          'reference_card_count': input.referenceCardCount,
        },
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CalibratedBaselineRepository',
        'Failed to store baseline',
        context: {
          'set_name': input.setName,
          'finish': input.finish,
        },
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<BaselineEntry?> findBaseline({
    required String set,
    required String finish,
  }) async {
    try {
      final result = await _connection.execute(
        '''
        SELECT config_json, reference_card_count, calibrated_at, average_psa_grade
        FROM calibrated_baseline
        WHERE LOWER(set_name) = LOWER(\$1)
          AND LOWER(finish) = LOWER(\$2)
          AND active = true
        ORDER BY modified_at DESC
        LIMIT 1
        ''',
        parameters: [set, finish],
      );

      if (result.isEmpty) return null;

      final row = result.first;
      final configJson = Map<String, dynamic>.from(row[0] as Map);
      final referenceCardCount = row[1] as int;
      final calibratedAt = row[2] as DateTime;
      final averagePsaGrade = (row[3] as num?)?.toDouble() ?? 0.0;

      if (referenceCardCount < BaselineRegistry.minimumReferenceCards) {
        return null; // Insufficient ground truth
      }

      return BaselineEntry(
        config: BaselineConfig.fromJson(configJson),
        referenceCardCount: referenceCardCount,
        calibratedAt: calibratedAt,
        averagePsaGrade: averagePsaGrade,
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CalibratedBaselineRepository',
        'Failed to find baseline',
        context: {'set_name': set, 'finish': finish},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<List<StoredBaseline>> findAllBaselines() async {
    try {
      final result = await _connection.execute(
        '''
        SELECT id, set_name, finish, config_json, reference_card_count,
               calibrated_at, average_psa_grade
        FROM calibrated_baseline
        WHERE active = true
        ORDER BY set_name, finish
        ''',
      );

      return result.map((row) {
        final configJson = Map<String, dynamic>.from(row[3] as Map);
        return StoredBaseline(
          id: row[0] as int,
          setName: row[1] as String,
          finish: row[2] as String,
          entry: BaselineEntry(
            config: BaselineConfig.fromJson(configJson),
            referenceCardCount: row[4] as int,
            calibratedAt: row[5] as DateTime,
            averagePsaGrade: (row[6] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }).toList();
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CalibratedBaselineRepository',
        'Failed to list baselines',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<void> deactivateBaseline({
    required String set,
    required String finish,
  }) async {
    try {
      await _connection.execute(
        '''
        UPDATE calibrated_baseline
        SET active = false, modified_at = NOW()
        WHERE LOWER(set_name) = LOWER(\$1)
          AND LOWER(finish) = LOWER(\$2)
          AND active = true
        ''',
        parameters: [set, finish],
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CalibratedBaselineRepository',
        'Failed to deactivate baseline',
        context: {'set_name': set, 'finish': finish},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
