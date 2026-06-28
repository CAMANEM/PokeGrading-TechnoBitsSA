/// @file
/// @brief

import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/catalog/catalog_models.dart';
import '../../domain/image_services/visual_features.dart';
import '../../domain/scoring/grading/baseline_calibrator.dart';
import '../../domain/scoring/grading/grading_feature_extractor.dart';
import '../image_provider/image_storage_repository.dart';
import '../lookup/lookup_resolver.dart';
import 'catalog_repository.dart';

/// @brief PostgresCatalogRepository
class PostgresCatalogRepository implements CatalogRepository {
  final Connection _connection;
  final LookupResolver _lookups;
  final ImageStorageRepository _images;

  PostgresCatalogRepository._(
    this._connection,
    this._lookups,
    this._images,
  );

  static Future<PostgresCatalogRepository> connect(
    DatabaseConfig config,
    ImageStorageRepository images,
  ) async {
    AppLogger.info(
      'PokéGrading.Persistence.CatalogRepository',
      'Connecting to PostgreSQL catalog database',
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
        'PokéGrading.Persistence.CatalogRepository',
        'PostgreSQL catalog repository connected',
      );
      return PostgresCatalogRepository._(
        connection,
        LookupResolver(connection),
        images,
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CatalogRepository',
        'Failed to connect to PostgreSQL catalog database',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  static const _selectColumns = '''
    cr.id,
    cr.set_name,
    cr.card_number,
    cr.edition,
    l.name AS language_name,
    cr.finish,
    cr.display_name,
    cr.registration_date,
    cr.responsible_id,
    cr.year,
    r.name AS rarity_name,
    cr.illustrator,
    cr.hp,
    ct.name AS type_name,
    hr.average_hash_hex,
    hr.difference_hash_hex,
    hr.center_average_hash_hex,
    hr.center_difference_hash_hex,
    cr.psa_grade,
    cr.grading_features_json
  ''';

  static const _fromClause = '''
    FROM card_reference cr
    LEFT JOIN language l ON cr.language_id = l.id
    LEFT JOIN rarity r ON cr.rarity_id = r.id
    LEFT JOIN card_type ct ON cr.type_id = ct.id
    LEFT JOIN hash_reference hr ON cr.hash_id = hr.id
  ''';

  @override
  Future<bool> identityTupleExists({required CardIdentity identity}) async {
    try {
      final languageId = await _lookups.resolveLanguageId(identity.language);
      if (languageId == null) return false;

      final cardNumber = int.tryParse(identity.number.trim());
      if (cardNumber == null) return false;

      final result = await _connection.execute(
        '''
        SELECT COUNT(1) FROM card_reference
        WHERE LOWER(set_name) = LOWER(\$1)
          AND card_number = \$2
          AND LOWER(edition) = LOWER(\$3)
          AND language_id = \$4
          AND LOWER(finish) = LOWER(\$5)
          AND soft_delete = false
        ''',
        parameters: [
          identity.set.trim(),
          cardNumber,
          identity.edition.trim(),
          languageId,
          identity.finish.trim(),
        ],
      );
      final exists = (result.first.first as int) > 0;
      AppLogger.info(
        'PokéGrading.Persistence.CatalogRepository',
        'Identity tuple existence check',
        context: {
          'set': identity.set,
          'number': identity.number,
          'exists': exists,
        },
      );
      return exists;
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CatalogRepository',
        'Identity tuple check failed',
        context: {
          'set': identity.set,
          'number': identity.number,
        },
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<PokemonCard> saveCard(AddPokemonCardInput input) async {
    AppLogger.info(
      'PokéGrading.Persistence.CatalogRepository',
      'Saving card',
      context: {
        'set': input.identity.set,
        'number': input.identity.number,
        'edition': input.identity.edition,
      },
    );

    try {
      final card = await _connection.runTx<PokemonCard>((tx) async {
        final now = DateTime.now().toUtc();
        final lookups = LookupResolver(tx);
        final languageId =
            await lookups.resolveLanguageId(input.identity.language);
        final typeId =
            await lookups.resolveCardTypeId(input.display?.pokemonType);
        final rarityId = await lookups.resolveRarityId(input.display?.rarity);
        final cardNumber = int.parse(input.identity.number.trim());

        final adminResult = await tx.execute(
          'SELECT id FROM admin ORDER BY id LIMIT 1',
        );
        if (adminResult.isEmpty) {
          throw StateError(
            'No admin exists. Register an admin before creating cards.',
          );
        }
        final adminId = adminResult.first.first as int;

        final hashResult = await tx.execute(
          '''
          INSERT INTO hash_reference (
            average_hash_hex,
            difference_hash_hex,
            center_average_hash_hex,
            center_difference_hash_hex,
            date
          ) VALUES (\$1, \$2, \$3, \$4, \$5)
          RETURNING id
          ''',
          parameters: [
            input.visualFeatures?.averageHashHex,
            input.visualFeatures?.differenceHashHex,
            input.visualFeatures?.centerAverageHashHex,
            input.visualFeatures?.centerDifferenceHashHex,
            now,
          ],
        );
        final hashId = hashResult.first.first as int;

        final cardDisplayName =
            input.display?.displayName?.trim().isNotEmpty == true
                ? input.display!.displayName!.trim()
                : '${input.identity.set.trim()} - ${input.identity.number.trim()}';

        final cardResult = await tx.execute(
          '''
          INSERT INTO card_reference (
            responsible_id,
            hash_id,
            display_name,
            set_name,
            card_number,
            edition,
            finish,
            illustrator,
            year,
            hp,
            language_id,
            type_id,
            rarity_id,
            psa_grade,
            grading_features_json,
            registration_date,
            active
          ) VALUES (
            \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13, \$14, \$15::jsonb, \$16, \$17
          )
          RETURNING id
          ''',
          parameters: [
            adminId,
            hashId,
            cardDisplayName,
            input.identity.set.trim(),
            cardNumber,
            input.identity.edition.trim(),
            input.identity.finish.trim(),
            input.display?.illustrator?.trim(),
            input.display?.year,
            input.display?.hp,
            languageId,
            typeId,
            rarityId,
            input.psaGrade,
            input.gradingFeaturesJson != null
                ? jsonEncode(input.gradingFeaturesJson)
                : null,
            now,
            true,
          ],
        );
        final cardId = cardResult.first.first as int;

        return PokemonCard(
          id: cardId.toString(),
          identity: input.identity,
          display: input.display,
          imageData: input.imageData.trim(),
          backImageData: input.backImageData,
          visualFeatures: input.visualFeatures,
          status: PokemonCardStatus.pendingValidation,
          isActive: true,
          audit: [],
          createdAt: now,
        );
      });

      final parsedId = int.parse(card.id);
      final perceptualHash = input.visualFeatures != null
          ? 'ahash:${input.visualFeatures!.averageHashHex ?? ''}|dhash:${input.visualFeatures!.differenceHashHex ?? ''}'
          : null;

      await _images.saveReferenceImages(
        cardReferenceId: parsedId,
        frontBase64: input.imageData,
        backBase64: input.backImageData ?? '',
        perceptualHash: perceptualHash,
      );

      AppLogger.info(
        'PokéGrading.Persistence.CatalogRepository',
        'Card saved successfully',
        context: {'card_id': card.id, 'set': input.identity.set},
      );

      return card;
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CatalogRepository',
        'Card save failed',
        context: {
          'set': input.identity.set,
          'number': input.identity.number,
        },
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<PokemonCard?> findById(String id) async {
    try {
      final parsedId = int.tryParse(id);
      if (parsedId == null) {
        AppLogger.warning(
          'PokéGrading.Persistence.CatalogRepository',
          'Invalid card ID format for findById',
          context: {'raw_id': id},
        );
        return null;
      }

      final result = await _connection.execute(
        'SELECT $_selectColumns $_fromClause WHERE cr.id = \$1',
        parameters: [parsedId],
      );

      if (result.isEmpty) {
        AppLogger.info(
          'PokéGrading.Persistence.CatalogRepository',
          'Card not found by ID',
          context: {'card_id': id},
        );
        return null;
      }
      return _rowToCard(result.first);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CatalogRepository',
        'findById failed',
        context: {'card_id': id},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<List<PokemonCard>> searchCards() async {
    try {
      final result = await _connection.execute('''
      SELECT $_selectColumns
      $_fromClause
      ORDER BY cr.registration_date DESC
      ''');

      AppLogger.info(
        'PokéGrading.Persistence.CatalogRepository',
        'Card search completed',
        context: {'result_count': result.length},
      );

      return result.map((row) => _rowToCard(row)).toList();
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CatalogRepository',
        'searchCards failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<List<PokemonCard>> findByVisualFeatures(VisualFeatures query) async {
    try {
      final conditions = <String>[];
      final params = <dynamic>[];
      var paramIdx = 1;

      const expectedHashLength = VisualFeatureExtractor.multiChannelHashHexLength;

      if (query.averageHashHex != null &&
          query.averageHashHex!.length == expectedHashLength) {
        conditions.add('hr.average_hash_hex = \$$paramIdx');
        params.add(query.averageHashHex);
        paramIdx++;
      }
      if (query.differenceHashHex != null &&
          query.differenceHashHex!.length == expectedHashLength) {
        conditions.add('hr.difference_hash_hex = \$$paramIdx');
        params.add(query.differenceHashHex);
        paramIdx++;
      }

      if (conditions.isEmpty) {
        AppLogger.warning(
          'PokéGrading.Persistence.CatalogRepository',
          'findByVisualFeatures called with empty query',
        );
        return [];
      }

      final result = await _connection.execute(
        '''
        SELECT $_selectColumns
        $_fromClause
        WHERE ${conditions.join(' OR ')}
        ORDER BY cr.registration_date DESC
        LIMIT 20
        ''',
        parameters: params,
      );

      AppLogger.info(
        'PokéGrading.Persistence.CatalogRepository',
        'Visual feature search completed',
        context: {'result_count': result.length},
      );

      return result.map((row) => _rowToCard(row)).toList();
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CatalogRepository',
        'findByVisualFeatures failed',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<List<PokemonCard>> fuzzySearchCards(String query) async {
    try {
      final searchTerm = query.trim();
      if (searchTerm.isEmpty) {
        AppLogger.warning(
          'PokéGrading.Persistence.CatalogRepository',
          'fuzzySearchCards called with empty query',
        );
        return [];
      }

      final result = await _connection.execute(
        '''
        SELECT $_selectColumns
        $_fromClause
        WHERE cr.display_name ILIKE \$1
           OR cr.set_name ILIKE \$1
           OR CAST(cr.card_number AS TEXT) ILIKE \$1
        ORDER BY cr.registration_date DESC
        LIMIT 20
        ''',
        parameters: ['%$searchTerm%'],
      );

      AppLogger.info(
        'PokéGrading.Persistence.CatalogRepository',
        'Fuzzy search completed',
        context: {'query': searchTerm, 'result_count': result.length},
      );

      return result.map((row) => _rowToCard(row)).toList();
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CatalogRepository',
        'fuzzySearchCards failed',
        context: {'query': query},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  PokemonCard _rowToCard(List<dynamic> row) {
    final cardNumber = row[2]?.toString() ?? '';
    final identity = CardIdentity(
      set: row[1]?.toString() ?? '',
      number: cardNumber,
      edition: row[3]?.toString() ?? '',
      language: row[4]?.toString() ?? '',
      finish: row[5]?.toString() ?? '',
    );

    final visualFeatures = VisualFeatures(
      averageHashHex: row[14]?.toString(),
      differenceHashHex: row[15]?.toString(),
      centerAverageHashHex: row[16]?.toString(),
      centerDifferenceHashHex: row[17]?.toString(),
    );

    final psaGrade = (row[18] as num?)?.toDouble();

    final rawGradingJson = row[19];
    Map<String, dynamic>? gradingFeaturesJson;
    if (rawGradingJson is Map) {
      gradingFeaturesJson = Map<String, dynamic>.from(rawGradingJson);
    }

    final display = CardDisplay(
      displayName: row[6]?.toString(),
      rarity: row[10]?.toString(),
      pokemonType: row[13]?.toString(),
      hp: row[12] as int?,
      illustrator: row[11]?.toString(),
      year: row[9] as int?,
      author: row[8]?.toString(),
      psaGrade: psaGrade,
    );

    return PokemonCard(
      id: row[0].toString(),
      identity: identity,
      display: display,
      imageData: '',
      visualFeatures: visualFeatures.isEmpty ? null : visualFeatures,
      gradingFeaturesJson: gradingFeaturesJson,
      status: PokemonCardStatus.pendingValidation,
      isActive: true,
      audit: [],
      createdAt: row[7] as DateTime,
    );
  }

  @override
  Future<List<GradedCardRecord>> findGradedCardsForCalibration({
    required String set,
    required String finish,
  }) async {
    try {
      final result = await _connection.execute(
        '''
        SELECT psa_grade, grading_features_json
        FROM card_reference
        WHERE LOWER(set_name) = LOWER(\$1)
          AND LOWER(finish) = LOWER(\$2)
          AND psa_grade IS NOT NULL
          AND grading_features_json IS NOT NULL
          AND active = true
          AND soft_delete = false
        ''',
        parameters: [set, finish],
      );

      final cards = <GradedCardRecord>[];
      for (final row in result) {
        final psaGrade = (row[0] as num).toDouble();
        final featuresJson = Map<String, dynamic>.from(row[1] as Map);
        final features = GradingFeatureExtractor.fromMap(featuresJson);
        if (features != null) {
          cards.add(GradedCardRecord(
            features: features,
            psaGrade: psaGrade,
            set: set,
            finish: finish,
          ));
        }
      }

      AppLogger.info(
        'PokéGrading.Persistence.CatalogRepository',
        'Found graded cards for calibration',
        context: {
          'set': set,
          'finish': finish,
          'card_count': cards.length,
        },
      );

      return cards;
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.CatalogRepository',
        'findGradedCardsForCalibration failed',
        context: {'set': set, 'finish': finish},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> close() async {
    await _connection.close();
  }
}
