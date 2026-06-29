import 'package:postgres/postgres.dart';

import '../../core/logging/app_logger.dart';

/// Resolves lookup table names to PostgreSQL FK ids.
class LookupResolver {
  final Session _session;

  LookupResolver(this._session);

  Future<int?> resolveLanguageId(
    String name, {
    bool insertIfMissing = false,
  }) async {
    return _resolveId(
      table: 'language',
      name: name,
      insertIfMissing: insertIfMissing,
    );
  }

  Future<int?> resolveCountryId(
    String name, {
    bool insertIfMissing = false,
  }) async {
    return _resolveId(
      table: 'country',
      name: name,
      insertIfMissing: insertIfMissing,
    );
  }

  Future<int?> resolveCardTypeId(String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    return _resolveId(table: 'card_type', name: name);
  }

  Future<int?> resolveRarityId(String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    return _resolveId(table: 'rarity', name: name);
  }

  Future<int> resolveStatusId(String name) async {
    final id = await _resolveId(table: 'status', name: name);
    if (id == null) {
      AppLogger.error(
        'PokéGrading.Persistence.LookupResolver',
        'Required status lookup not found',
        context: {'status_name': name},
      );
      throw StateError('Status "$name" not found in lookup table');
    }
    return id;
  }

  Future<int?> _resolveId({
    required String table,
    required String name,
    bool insertIfMissing = false,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return null;

    try {
      final existing = await _session.execute(
        'SELECT id FROM "$table" WHERE LOWER(name) = LOWER(\$1) LIMIT 1',
        parameters: [normalized],
      );
      if (existing.isNotEmpty) {
        return existing.first.first as int;
      }

      if (!insertIfMissing) {
        AppLogger.warning(
          'PokéGrading.Persistence.LookupResolver',
          'Lookup value not found',
          context: {'table': table, 'name': name},
        );
        return null;
      }

      final inserted = await _session.execute(
        'INSERT INTO "$table" (name) VALUES (\$1) RETURNING id',
        parameters: [normalized],
      );
      return inserted.first.first as int;
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.LookupResolver',
        'Lookup resolution failed',
        context: {'table': table, 'name': name},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
