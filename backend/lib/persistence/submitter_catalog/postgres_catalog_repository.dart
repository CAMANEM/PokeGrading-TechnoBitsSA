/// @file
/// @brief

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../domain/submitter_catalog/catalog_repository.dart';
import '../../domain/submitter_catalog/pokemon_card.dart';
import '../../domain/submitter_catalog/search_card/visual_features.dart';

/// @brief PostgresCatalogRepository
class PostgresCatalogRepository implements CatalogRepository {
  final Connection _connection;

  PostgresCatalogRepository._(this._connection);

  static Future<PostgresCatalogRepository> connect(
      DatabaseConfig config) async {
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
    return PostgresCatalogRepository._(connection);
  }

  @override
  Future<bool> identityTupleExists({
    required String set,
    required String number,
    required String edition,
    required String language,
    required String finish,
  }) async {
    final result = await _connection.execute(
      '''
      SELECT COUNT(1) FROM "CARTA" 
      WHERE LOWER("set_code") = LOWER(\$1)
        AND LOWER("numero_carta") = LOWER(\$2)
        AND LOWER("edicion") = LOWER(\$3)
        AND LOWER("idioma") = LOWER(\$4)
        AND LOWER("acabado") = LOWER(\$5)
      ''',
      parameters: [
        set.trim(),
        number.trim(),
        edition.trim(),
        language.trim(),
        finish.trim()
      ],
    );
    return (result.first.first as int) > 0;
  }

  @override
  Future<PokemonCard> saveCard(AddPokemonCardInput input) async {
    return await _connection.runTx((tx) async {
      // 1. Identity check to ensure no duplicates in concurrent transactions
      final existRes = await tx.execute(
        '''
        SELECT COUNT(1) FROM "CARTA" 
        WHERE LOWER("set_code") = LOWER(\$1)
          AND LOWER("numero_carta") = LOWER(\$2)
          AND LOWER("edicion") = LOWER(\$3)
          AND LOWER("idioma") = LOWER(\$4)
          AND LOWER("acabado") = LOWER(\$5)
        ''',
        parameters: [
          input.set.trim(),
          input.number.trim(),
          input.edition.trim(),
          input.language.trim(),
          input.finish.trim()
        ],
      );
      if ((existRes.first.first as int) > 0) {
        throw const CatalogIdentityConflictException(
          'Identidad rechazada: ya existe una carta con la misma combinación de Set, Número, Edición, Idioma y Acabado.',
        );
      }

      final now = DateTime.now().toUtc();

      // 2. Insert Front Image with visual hash
      final imgFrontIdRes = await tx
          .execute('SELECT COALESCE(MAX("id_imagen"), 0) + 1 FROM "IMAGEN"');
      final imgFrontId = imgFrontIdRes.first.first as int;
      final frontHash = input.visualFeatures != null
          ? 'ahash:${input.visualFeatures!.averageHashHex ?? ""}|dhash:${input.visualFeatures!.differenceHashHex ?? ""}'
          : null;
      await tx.execute(
        'INSERT INTO "IMAGEN" ("id_imagen", "ruta_cloud", "hash_visual", "fecha_subida") VALUES (\$1, \$2, \$3, \$4)',
        parameters: [
          imgFrontId,
          'local_base64_front_${now.millisecondsSinceEpoch}',
          frontHash,
          now,
        ],
      );

      // 3. Insert Back Image
      final imgBackIdRes = await tx
          .execute('SELECT COALESCE(MAX("id_imagen"), 0) + 1 FROM "IMAGEN"');
      final imgBackId = imgBackIdRes.first.first as int;
      await tx.execute(
        'INSERT INTO "IMAGEN" ("id_imagen", "ruta_cloud", "fecha_subida") VALUES (\$1, \$2, \$3)',
        parameters: [
          imgBackId,
          'local_base64_back_${now.millisecondsSinceEpoch}',
          now,
        ],
      );

      // 4. Insert Carta
      final cartaIdRes = await tx
          .execute('SELECT COALESCE(MAX("id_carta"), 0) + 1 FROM "CARTA"');
      final cartaId = cartaIdRes.first.first as int;

      // Determine creator: use the first existing user, or default to 1
      int creatorId = 1;
      final userResult = await tx.execute(
          'SELECT "id_usuario" FROM "USUARIO" ORDER BY "id_usuario" LIMIT 1');
      if (userResult.isNotEmpty) {
        creatorId = userResult.first.first as int;
      }

      final cardDisplayName = input.displayName?.trim().isNotEmpty == true
          ? input.displayName!.trim()
          : '${input.set.trim()} - ${input.number.trim()}';

      await tx.execute(
        '''
        INSERT INTO "CARTA" (
          "id_carta", "tipo", "nombre_display", "set_code", "numero_carta", "edicion", "idioma", "acabado",
          "anio", "rareza", "ilustrador", "id_imagen_derecho", "id_imagen_reves", "estado_aprobacion",
          "id_creador", "fecha_registro"
        ) VALUES (
          \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13, \$14, \$15, \$16
        )
        ''',
        parameters: [
          cartaId,
          'submitter',
          cardDisplayName,
          input.set.trim(),
          input.number.trim(),
          input.edition.trim(),
          input.language.trim(),
          input.finish.trim(),
          input.year,
          input.rarity?.trim(),
          input.illustrator?.trim(),
          imgFrontId,
          imgBackId,
          'pendiente',
          creatorId,
          now
        ],
      );

      return PokemonCard(
        id: cartaId.toString(),
        set: input.set.trim(),
        number: input.number.trim(),
        edition: input.edition.trim(),
        language: input.language.trim(),
        finish: input.finish.trim(),
        displayName: input.displayName?.trim(),
        imageData: input.imageData.trim(),
        rarity: input.rarity,
        pokemonType: input.pokemonType,
        hp: input.hp,
        illustrator: input.illustrator,
        year: input.year,
        createdBy: creatorId.toString(),
        backImageData: input.backImageData,
        status: PokemonCardStatus.pendingValidation,
        isActive: true,
        audit: [],
        createdAt: now,
      );
    });
  }

  @override
  Future<PokemonCard?> findById(String id) async {
    final parsedId = int.tryParse(id);
    if (parsedId == null) return null;

    final result = await _connection.execute(
      'SELECT "id_carta", "set_code", "numero_carta", "edicion", "idioma", "acabado", "nombre_display", "estado_aprobacion", "fecha_registro", "id_creador" FROM "CARTA" WHERE "id_carta" = \$1',
      parameters: [parsedId],
    );

    if (result.isEmpty) return null;
    final row = result.first;

    return _rowToCard(row);
  }

  @override
  Future<List<PokemonCard>> searchCards() async {
    final result = await _connection.execute('''
    SELECT
      "id_carta",
      "set_code",
      "numero_carta",
      "edicion",
      "idioma",
      "acabado",
      "nombre_display",
      "estado_aprobacion",
      "fecha_registro",
      "id_creador"
    FROM "CARTA"
    ORDER BY "fecha_registro" DESC
    ''');

    return result.map((row) => _rowToCard(row)).toList();
  }

  @override
  Future<List<PokemonCard>> findByVisualFeatures(VisualFeatures query) async {
    // Build search patterns from query hashes
    final conditions = <String>[];
    final params = <dynamic>[];
    int paramIdx = 1;

    if (query.averageHashHex != null && query.averageHashHex!.length == 16) {
      conditions.add('"hash_visual" LIKE \$$paramIdx');
      params.add('%ahash:${query.averageHashHex}%');
      paramIdx++;
    }
    if (query.differenceHashHex != null &&
        query.differenceHashHex!.length == 16) {
      conditions.add('"hash_visual" LIKE \$$paramIdx');
      params.add('%dhash:${query.differenceHashHex}%');
      paramIdx++;
    }

    if (conditions.isEmpty) return [];

    final result = await _connection.execute(
      'SELECT c."id_carta", c."set_code", c."numero_carta", c."edicion", c."idioma", c."acabado", c."nombre_display", c."estado_aprobacion", c."fecha_registro", c."id_creador" FROM "CARTA" c LEFT JOIN "IMAGEN" i ON c."id_imagen_derecho" = i."id_imagen" WHERE ${conditions.join(' OR ')} ORDER BY c."fecha_registro" DESC LIMIT 20',
      parameters: params,
    );

    return result.map((row) => _rowToCard(row)).toList();
  }

  @override
  Future<List<PokemonCard>> fuzzySearchCards(String query) async {
    final searchTerm = query.trim();
    if (searchTerm.isEmpty) return [];

    final result = await _connection.execute(
      'SELECT "id_carta", "set_code", "numero_carta", "edicion", "idioma", "acabado", "nombre_display", "estado_aprobacion", "fecha_registro", "id_creador" FROM "CARTA" WHERE "nombre_display" ILIKE \$1 OR "set_code" ILIKE \$1 OR "numero_carta" ILIKE \$1 ORDER BY "fecha_registro" DESC LIMIT 20',
      parameters: ['%$searchTerm%'],
    );

    return result.map((row) => _rowToCard(row)).toList();
  }

  PokemonCard _rowToCard(List<dynamic> row) {
    return PokemonCard(
      id: row[0].toString(),
      set: row[1].toString(),
      number: row[2].toString(),
      edition: row[3].toString(),
      language: row[4].toString(),
      finish: row[5].toString(),
      displayName: row[6]?.toString(),
      imageData: '',
      status: PokemonCardStatus.pendingValidation,
      isActive: true,
      audit: [],
      createdAt: row[8] as DateTime,
      createdBy: row[9].toString(),
    );
  }

  Future<void> close() async {
    await _connection.close();
  }
}
