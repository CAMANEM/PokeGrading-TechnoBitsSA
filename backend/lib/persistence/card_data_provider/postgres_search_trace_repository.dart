/// @file
/// @brief

import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../domain/catalog/search_trace.dart';
import '../../domain/image_services/visual_features.dart';
import '../../domain/catalog/catalog_models.dart';
import 'search_trace_repository.dart';

/// PostgreSQL implementation of [SearchTraceRepository].
///
/// Stores search traces in the BUSQUEDA_TRACE table.
/// VisualFeatures and candidates are serialized as JSON.
class PostgresSearchTraceRepository implements SearchTraceRepository {
  final Connection _connection;

  PostgresSearchTraceRepository._(this._connection);

  /// Creates and opens a PostgreSQL connection using the provided config.
  static Future<PostgresSearchTraceRepository> connect(
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
    return PostgresSearchTraceRepository._(connection);
  }

  @override
  Future<void> save(SearchTrace trace) async {
    try {
      await _connection.execute(
        'INSERT INTO "BUSQUEDA_TRACE" ("id_trace", "metodo", "caracteristicas_query", "metadata_query", "candidatos", "decision", "razon_decision", "fecha_creacion") VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8)',
        parameters: [
          trace.id,
          trace.method,
          trace.queryFeatures != null
              ? jsonEncode(_featuresToMap(trace.queryFeatures!))
              : null,
          trace.queryMetadata != null
              ? jsonEncode(_metadataToMap(trace.queryMetadata!))
              : null,
          jsonEncode(trace.candidates
              .map((c) => {
                    'card_id': c.cardId,
                    'display_name': c.displayName,
                    'confidence': c.confidence,
                  })
              .toList()),
          trace.decision,
          trace.decisionReason,
          trace.timestamp,
        ],
      );
    } catch (_) {
      // Table may not exist if migration 002 hasn't been applied
    }
  }

  @override
  Future<List<SearchTrace>> findAll() async {
    final result = await _connection.execute(
      'SELECT "id_trace", "metodo", "caracteristicas_query", "metadata_query", "candidatos", "decision", "razon_decision", "fecha_creacion" FROM "BUSQUEDA_TRACE" ORDER BY "fecha_creacion" DESC',
    );
    return result.map((row) => _rowToTrace(row)).toList();
  }

  @override
  Future<List<SearchTrace>> findRecent(int limit) async {
    final result = await _connection.execute(
      'SELECT "id_trace", "metodo", "caracteristicas_query", "metadata_query", "candidatos", "decision", "razon_decision", "fecha_creacion" FROM "BUSQUEDA_TRACE" ORDER BY "fecha_creacion" DESC LIMIT \$1',
      parameters: [limit],
    );
    return result.map((row) => _rowToTrace(row)).toList();
  }

  SearchTrace _rowToTrace(List<dynamic> row) {
    final candidatesRaw = jsonDecode(row[4].toString()) as List<dynamic>;
    final candidates = candidatesRaw.map((c) {
      final m = c as Map<String, dynamic>;
      return ScoredCandidateEntry(
        cardId: m['card_id'].toString(),
        displayName: m['display_name']?.toString(),
        confidence: (m['confidence'] as num).toDouble(),
      );
    }).toList();

    VisualFeatures? features;
    if (row[2] != null) {
      final f = jsonDecode(row[2].toString()) as Map<String, dynamic>;
      features = VisualFeatures(
        averageHashHex: f['average_hash_hex']?.toString(),
        differenceHashHex: f['difference_hash_hex']?.toString(),
        centerAverageHashHex: f['center_average_hash_hex']?.toString(),
        centerDifferenceHashHex: f['center_difference_hash_hex']?.toString(),
        edgeHashHex: f['edge_hash_hex']?.toString(),
      );
    }

    CardIdentity? metadata;
    if (row[3] != null) {
      final m = jsonDecode(row[3].toString()) as Map<String, dynamic>;
      metadata = CardIdentity(
        set: m['set'].toString(),
        number: m['number'].toString(),
        edition: m['edition'].toString(),
        language: m['language'].toString(),
        finish: m['finish'].toString(),
      );
    }

    return SearchTrace(
      id: row[0].toString(),
      timestamp: row[7] as DateTime,
      method: row[1].toString(),
      queryFeatures: features,
      queryMetadata: metadata,
      candidates: candidates,
      decision: row[5].toString(),
      decisionReason: row[6]?.toString(),
    );
  }

  Map<String, dynamic> _featuresToMap(VisualFeatures f) => {
        'average_hash_hex': f.averageHashHex,
        'difference_hash_hex': f.differenceHashHex,
        'center_average_hash_hex': f.centerAverageHashHex,
        'center_difference_hash_hex': f.centerDifferenceHashHex,
        'edge_hash_hex': f.edgeHashHex,
        'back_average_hash_hex': f.backAverageHashHex,
        'back_difference_hash_hex': f.backDifferenceHashHex,
        'back_center_average_hash_hex': f.backCenterAverageHashHex,
        'back_center_difference_hash_hex': f.backCenterDifferenceHashHex,
        'back_edge_hash_hex': f.backEdgeHashHex,
      };

  Map<String, dynamic> _metadataToMap(CardIdentity m) => {
        'set': m.set,
        'number': m.number,
        'edition': m.edition,
        'language': m.language,
        'finish': m.finish,
      };

  Future<void> close() async {
    await _connection.close();
  }
}
