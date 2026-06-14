/// @file
/// @brief

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../domain/catalog/catalog_models.dart';
import '../../domain/image_services/hash_prefilter.dart';
import '../../domain/image_services/visual_features.dart';
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
    return PostgresCatalogRepository._(
      connection,
      LookupResolver(connection),
      images,
    );
  }

  static const _selectColumns = '''
    cs.id,
    cs.set_name,
    cs.card_number,
    cs.edition,
    l.name AS language_name,
    cs.finish,
    cs.display_name,
    cs.registration_date,
    cs.submitter_id,
    cs.year,
    r.name AS rarity_name,
    cs.illustrator,
    cs.hp,
    ct.name AS type_name,
    hs.average_hash_hex,
    hs.difference_hash_hex,
    hs.center_average_hash_hex,
    hs.center_difference_hash_hex,
    hs.edge_hash_hex,
    hs.back_average_hash_hex,
    hs.back_difference_hash_hex,
    hs.back_center_average_hash_hex,
    hs.back_center_difference_hash_hex,
    hs.back_edge_hash_hex
  ''';

  static const _fromClause = '''
    FROM card_submitter cs
    LEFT JOIN language l ON cs.language_id = l.id
    LEFT JOIN rarity r ON cs.rarity_id = r.id
    LEFT JOIN card_type ct ON cs.type_id = ct.id
    LEFT JOIN hash_submitter hs ON cs.hash_id = hs.id
  ''';

  @override
  Future<bool> identityTupleExists({required CardIdentity identity}) async {
    final languageId = await _lookups.resolveLanguageId(identity.language);
    if (languageId == null) return false;

    final cardNumber = int.tryParse(identity.number.trim());
    if (cardNumber == null) return false;

    final result = await _connection.execute(
      '''
      SELECT COUNT(1) FROM card_submitter
      WHERE LOWER(set_name) = LOWER(\$1)
        AND card_number = \$2
        AND LOWER(edition) = LOWER(\$3)
        AND language_id = \$4
        AND LOWER(finish) = LOWER(\$5)
      ''',
      parameters: [
        identity.set.trim(),
        cardNumber,
        identity.edition.trim(),
        languageId,
        identity.finish.trim(),
      ],
    );
    return (result.first.first as int) > 0;
  }

  @override
  Future<PokemonCard> saveCard(AddPokemonCardInput input) async {
    final card = await _connection.runTx<PokemonCard>((tx) async {
      final now = DateTime.now().toUtc();
      final lookups = LookupResolver(tx);
      final languageId =
          await lookups.resolveLanguageId(input.identity.language);
      final typeId =
          await lookups.resolveCardTypeId(input.display?.pokemonType);
      final rarityId = await lookups.resolveRarityId(input.display?.rarity);
      final cardNumber = int.parse(input.identity.number.trim());

      final submitterResult = await tx.execute(
        'SELECT id FROM submitter ORDER BY id LIMIT 1',
      );
      if (submitterResult.isEmpty) {
        throw StateError(
          'No submitter exists. Register a user before creating cards.',
        );
      }
      final submitterId = submitterResult.first.first as int;

      final hashResult = await tx.execute(
        '''
        INSERT INTO hash_submitter (
          average_hash_hex,
          difference_hash_hex,
          center_average_hash_hex,
          center_difference_hash_hex,
          edge_hash_hex,
          back_average_hash_hex,
          back_difference_hash_hex,
          back_center_average_hash_hex,
          back_center_difference_hash_hex,
          back_edge_hash_hex,
          date
        ) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11)
        RETURNING id
        ''',
        parameters: [
          input.visualFeatures?.averageHashHex,
          input.visualFeatures?.differenceHashHex,
          input.visualFeatures?.centerAverageHashHex,
          input.visualFeatures?.centerDifferenceHashHex,
          input.visualFeatures?.edgeHashHex,
          input.visualFeatures?.backAverageHashHex,
          input.visualFeatures?.backDifferenceHashHex,
          input.visualFeatures?.backCenterAverageHashHex,
          input.visualFeatures?.backCenterDifferenceHashHex,
          input.visualFeatures?.backEdgeHashHex,
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
        INSERT INTO card_submitter (
          submitter_id,
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
          registration_date,
          active
        ) VALUES (
          \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13, \$14, \$15
        )
        RETURNING id
        ''',
        parameters: [
          submitterId,
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

    await _images.saveSubmitterImages(
      cardSubmitterId: parsedId,
      frontBase64: input.imageData,
      backBase64: input.backImageData ?? '',
      perceptualHash: perceptualHash,
    );

    return card;
  }

  @override
  Future<PokemonCard?> findById(String id) async {
    final parsedId = int.tryParse(id);
    if (parsedId == null) return null;

    final result = await _connection.execute(
      'SELECT $_selectColumns $_fromClause WHERE cs.id = \$1',
      parameters: [parsedId],
    );

    if (result.isEmpty) return null;
    return _rowToCard(result.first);
  }

  @override
  Future<List<PokemonCard>> searchCards() async {
    final result = await _connection.execute('''
    SELECT $_selectColumns
    $_fromClause
    ORDER BY cs.registration_date DESC
    ''');

    return result.map((row) => _rowToCard(row)).toList();
  }

  @override
  Future<List<PokemonCard>> findByVisualFeatures(VisualFeatures query) async {
    final result = await _connection.execute('''
      SELECT cs.id,
        hs.average_hash_hex,
        hs.difference_hash_hex,
        hs.center_average_hash_hex,
        hs.center_difference_hash_hex,
        hs.edge_hash_hex,
        hs.back_average_hash_hex,
        hs.back_difference_hash_hex,
        hs.back_center_average_hash_hex,
        hs.back_center_difference_hash_hex,
        hs.back_edge_hash_hex
      FROM card_submitter cs
      INNER JOIN hash_submitter hs ON cs.hash_id = hs.id
      WHERE cs.active = true
    ''');

    final scores = <int, int>{};

    for (final row in result) {
      final id = row[0] as int;
      final catalog = VisualFeatures(
        averageHashHex: row[1]?.toString(),
        differenceHashHex: row[2]?.toString(),
        centerAverageHashHex: row[3]?.toString(),
        centerDifferenceHashHex: row[4]?.toString(),
        edgeHashHex: row[5]?.toString(),
        backAverageHashHex: row[6]?.toString(),
        backDifferenceHashHex: row[7]?.toString(),
        backCenterAverageHashHex: row[8]?.toString(),
        backCenterDifferenceHashHex: row[9]?.toString(),
        backEdgeHashHex: row[10]?.toString(),
      );

      final score = scoreHashChunkOverlap(query, catalog);
      if (score > 0) {
        final existing = scores[id] ?? 0;
        if (score > existing) scores[id] = score;
      }
    }

    if (scores.isEmpty) return [];

    final sortedIds = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final cards = <PokemonCard>[];
    for (final entry in sortedIds.take(20)) {
      final card = await findById(entry.key.toString());
      if (card != null) cards.add(card);
    }

    return cards;
  }

  @override
  Future<List<PokemonCard>> fuzzySearchCards(String query) async {
    final searchTerm = query.trim();
    if (searchTerm.isEmpty) return [];

    final result = await _connection.execute(
      '''
      SELECT $_selectColumns
      $_fromClause
      WHERE cs.display_name ILIKE \$1
         OR cs.set_name ILIKE \$1
         OR CAST(cs.card_number AS TEXT) ILIKE \$1
      ORDER BY cs.registration_date DESC
      LIMIT 20
      ''',
      parameters: ['%$searchTerm%'],
    );

    return result.map((row) => _rowToCard(row)).toList();
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
      edgeHashHex: row[18]?.toString(),
      backAverageHashHex: row[19]?.toString(),
      backDifferenceHashHex: row[20]?.toString(),
      backCenterAverageHashHex: row[21]?.toString(),
      backCenterDifferenceHashHex: row[22]?.toString(),
      backEdgeHashHex: row[23]?.toString(),
    );

    final display = CardDisplay(
      displayName: row[6]?.toString(),
      rarity: row[10]?.toString(),
      pokemonType: row[13]?.toString(),
      hp: row[12] as int?,
      illustrator: row[11]?.toString(),
      year: row[9] as int?,
      author: row[8]?.toString(),
    );

    return PokemonCard(
      id: row[0].toString(),
      identity: identity,
      display: display,
      imageData: '',
      visualFeatures: visualFeatures.isEmpty ? null : visualFeatures,
      status: PokemonCardStatus.pendingValidation,
      isActive: true,
      audit: [],
      createdAt: row[7] as DateTime,
    );
  }

  Future<void> close() async {
    await _connection.close();
  }
}
