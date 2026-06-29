/// @file
/// @brief

import '../../domain/catalog/search_trace.dart';

/// @brief SearchTraceRepository
abstract class SearchTraceRepository {
  Future<void> save(SearchTrace trace);

  Future<List<SearchTrace>> findAll();

  Future<List<SearchTrace>> findRecent(int limit);
}
