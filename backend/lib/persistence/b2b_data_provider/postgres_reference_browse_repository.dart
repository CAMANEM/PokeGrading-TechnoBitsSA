/// @file
/// @brief PostgreSQL browse queries for `card_reference`.

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../domain/b2b/b2b_validators.dart';
import '../../domain/catalog/card_browse_models.dart';
import 'reference_browse_repository.dart';

class PostgresReferenceBrowseRepository implements ReferenceBrowseRepository {
  final Connection _connection;

  PostgresReferenceBrowseRepository._(this._connection);

  static Future<PostgresReferenceBrowseRepository> connect(
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
    return PostgresReferenceBrowseRepository._(connection);
  }

  Future<void> close() async {
    await _connection.close();
  }

  @override
  Future<List<CatalogCardSummary>> listCards() async {
    final result = await _connection.execute('''
      SELECT cr.id, cr.display_name, cr.set_name, cr.card_number,
             cr.edition, l.name AS language_name, cr.finish,
             r.name AS rarity_name, ct.name AS type_name, cr.hp,
             cr.active, cr.soft_delete, cr.registration_date
      FROM card_reference cr
      LEFT JOIN language l ON cr.language_id = l.id
      LEFT JOIN rarity r ON cr.rarity_id = r.id
      LEFT JOIN card_type ct ON cr.type_id = ct.id
      WHERE cr.soft_delete = false
      ORDER BY cr.set_name, cr.card_number, cr.id
    ''');

    return result.map(_rowToSummary).toList();
  }

  @override
  Future<CatalogCardSummary?> findSummaryById(String id) async {
    final parsedId = int.tryParse(id);
    if (parsedId == null) return null;

    final result = await _connection.execute(
      '''
      SELECT cr.id, cr.display_name, cr.set_name, cr.card_number,
             cr.edition, l.name AS language_name, cr.finish,
             r.name AS rarity_name, ct.name AS type_name, cr.hp,
             cr.active, cr.soft_delete, cr.registration_date
      FROM card_reference cr
      LEFT JOIN language l ON cr.language_id = l.id
      LEFT JOIN rarity r ON cr.rarity_id = r.id
      LEFT JOIN card_type ct ON cr.type_id = ct.id
      WHERE cr.id = \$1
      ''',
      parameters: [parsedId],
    );

    if (result.isEmpty) return null;
    return _rowToSummary(result.first);
  }

  CatalogCardSummary _rowToSummary(List<dynamic> row) {
    final languageName = row[5]?.toString() ?? '';
    final active = row[10] as bool? ?? false;
    final softDelete = row[11] as bool? ?? false;

    return CatalogCardSummary(
      id: row[0].toString(),
      source: 'reference',
      displayName: row[1]?.toString(),
      set: row[2]?.toString() ?? '',
      number: row[3]?.toString() ?? '',
      edition: row[4]?.toString() ?? '',
      language: B2bValidators.languageCodeForLookupName(languageName),
      finish: row[6]?.toString() ?? '',
      rarity: row[7]?.toString(),
      pokemonType: row[8]?.toString(),
      hp: row[9] as int?,
      active: active && !softDelete,
      createdAt: row[12] as DateTime?,
      hasImages: false,
    );
  }
}
