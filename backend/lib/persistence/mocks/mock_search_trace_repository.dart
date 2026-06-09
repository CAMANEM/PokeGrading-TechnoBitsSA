/// @file
/// @brief

import '../../domain/catalog/search_trace.dart';
import '../card_data_provider/search_trace_repository.dart';

/// @brief MockSearchTraceRepository
class MockSearchTraceRepository implements SearchTraceRepository {
  final List<SearchTrace> _traces = [];

  @override
  Future<void> save(SearchTrace trace) async {
    _traces.add(trace);
  }

  @override
  Future<List<SearchTrace>> findAll() async {
    return List.unmodifiable(_traces);
  }

  @override
  Future<List<SearchTrace>> findRecent(int limit) async {
    final start = _traces.length > limit ? _traces.length - limit : 0;
    return List.unmodifiable(_traces.sublist(start));
  }
}
