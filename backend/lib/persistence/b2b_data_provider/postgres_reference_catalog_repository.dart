/// @file
/// @brief PostgreSQL lookup against `card_reference` for B2B consult.

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/b2b/b2b_models.dart';
import '../../domain/b2b/b2b_validators.dart';
import '../lookup/lookup_resolver.dart';
import 'reference_catalog_repository.dart';

class PostgresReferenceCatalogRepository implements ReferenceCatalogRepository {
  final Connection _connection;
  final LookupResolver _lookups;

  PostgresReferenceCatalogRepository._(this._connection, this._lookups);

  static Future<PostgresReferenceCatalogRepository> connect(
    DatabaseConfig config,
  ) async {
    AppLogger.info(
      'PokéGrading.Persistence.ReferenceCatalogRepository',
      'Connecting to PostgreSQL reference catalog database',
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
        'PokéGrading.Persistence.ReferenceCatalogRepository',
        'PostgreSQL reference catalog repository connected',
      );
      return PostgresReferenceCatalogRepository._(
        connection,
        LookupResolver(connection),
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.ReferenceCatalogRepository',
        'Failed to connect to PostgreSQL reference catalog database',
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
  Future<List<ReferenceCard>> findActiveMatches({
    required String set,
    required String number,
    String? edition,
    String? languageLookupName,
    String? finish,
  }) async {
    try {
      final cardNumber = int.tryParse(number.trim());
      if (cardNumber == null) {
        AppLogger.warning(
          'PokéGrading.Persistence.ReferenceCatalogRepository',
          'Invalid card number in reference search',
          context: {'raw_number': number},
        );
        return [];
      }

      int? languageId;
      if (languageLookupName != null && languageLookupName.isNotEmpty) {
        languageId = await _lookups.resolveLanguageId(
            B2bValidators.lookupNameForLanguageCode(languageLookupName));
        if (languageId == null) {
          AppLogger.info(
            'PokéGrading.Persistence.ReferenceCatalogRepository',
            'Language not found in reference search',
            context: {'language': languageLookupName},
          );
          return [];
        }
      }

      final conditions = <String>[
        'cr.active = true',
        'LOWER(cr.set_name) = LOWER(\$1)',
        'cr.card_number = \$2',
      ];
      final params = <dynamic>[set.trim(), cardNumber];
      var paramIndex = 3;

      if (edition != null && edition.isNotEmpty) {
        conditions.add('LOWER(cr.edition) = LOWER(\$$paramIndex)');
        params.add(edition.trim());
        paramIndex++;
      }

      if (languageId != null) {
        conditions.add('cr.language_id = \$$paramIndex');
        params.add(languageId);
        paramIndex++;
      }

      if (finish != null && finish.isNotEmpty) {
        conditions.add('LOWER(cr.finish) = LOWER(\$$paramIndex)');
        params.add(finish.trim());
        paramIndex++;
      }

      final sql = '''
        SELECT cr.id, cr.set_name, cr.card_number, cr.edition, l.name AS language_name,
               cr.finish, cr.modification_date
        FROM card_submitter cr
        LEFT JOIN language l ON cr.language_id = l.id
        WHERE ${conditions.join(' AND ')}
        ORDER BY cr.id ASC
      ''';

      final result = await _connection.execute(sql, parameters: params);

      AppLogger.info(
        'PokéGrading.Persistence.ReferenceCatalogRepository',
        'Reference search completed',
        context: {
          'set': set,
          'number': number,
          'result_count': result.length,
        },
      );

      return result.map((row) {
        final languageName = row[4]?.toString() ?? '';
        return ReferenceCard(
          id: row[0].toString(),
          identity: B2bCardIdentity(
            set: row[1]?.toString() ?? '',
            number: row[2]?.toString() ?? '',
            edition: row[3]?.toString() ?? '',
            language: B2bValidators.languageCodeForLookupName(languageName),
            finish: row[5]?.toString() ?? '',
          ),
          modificationDate: row[6] as DateTime?,
        );
      }).toList();
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.ReferenceCatalogRepository',
        'Reference search failed',
        context: {'set': set, 'number': number},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
