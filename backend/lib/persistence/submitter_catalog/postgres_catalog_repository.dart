import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../domain/submitter_catalog/catalog_repository.dart';
import '../../domain/submitter_catalog/pokemon_card.dart';
import '../../domain/submitter_catalog/search_card/visual_features.dart';

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

      // 2. Insert Front Image (simulate cloud upload for now)
      final imgFrontIdRes = await tx
          .execute('SELECT COALESCE(MAX("id_imagen"), 0) + 1 FROM "IMAGEN"');
      final imgFrontId = imgFrontIdRes.first.first as int;
      await tx.execute(
        'INSERT INTO "IMAGEN" ("id_imagen", "ruta_cloud", "fecha_subida") VALUES (\$1, \$2, \$3)',
        parameters: [imgFrontId, 'local_base64_front_\$imgFrontId', now],
      );

      // 3. Insert Back Image (required by schema)
      final imgBackIdRes = await tx
          .execute('SELECT COALESCE(MAX("id_imagen"), 0) + 1 FROM "IMAGEN"');
      final imgBackId = imgBackIdRes.first.first as int;
      await tx.execute(
        'INSERT INTO "IMAGEN" ("id_imagen", "ruta_cloud", "fecha_subida") VALUES (\$1, \$2, \$3)',
        parameters: [imgBackId, 'local_base64_back_\$imgBackId', now],
      );

      // 4. Insert Carta
      final cartaIdRes = await tx
          .execute('SELECT COALESCE(MAX("id_carta"), 0) + 1 FROM "CARTA"');
      final cartaId = cartaIdRes.first.first as int;

      int creatorId = 1; // Default fallback to user ID 1
      if (input.author != null && input.author!.trim().isNotEmpty) {
        final parsed = int.tryParse(input.author!.trim());
        if (parsed != null) creatorId = parsed;
      }

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
          input.displayName?.trim().isNotEmpty == true
              ? input.displayName!.trim()
              : '\${input.set} - \${input.number}',
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

    return PokemonCard(
      id: row[0].toString(),
      set: row[1].toString(),
      number: row[2].toString(),
      edition: row[3].toString(),
      language: row[4].toString(),
      finish: row[5].toString(),
      displayName: row[6]?.toString(),
      imageData: '', // we don't return base64 here
      status: PokemonCardStatus.pendingValidation,
      isActive: true,
      audit: [],
      createdAt: row[8] as DateTime,
      createdBy: row[9].toString(),
    );
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
    ''');

    return result.map((row) {
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
    }).toList();
  }

  @override
  Future<List<PokemonCard>> findByVisualFeatures(VisualFeatures query) async {
    // TODO
    return [];
  }

  @override
  Future<List<PokemonCard>> fuzzySearchCards(String query) async {
    // TODO
    return [];
  }

  Future<void> close() async {
    await _connection.close();
  }
}
