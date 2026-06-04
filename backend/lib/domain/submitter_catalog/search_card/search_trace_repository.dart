import 'search_trace.dart';

abstract class SearchTraceRepository {
  Future<void> save(SearchTrace trace);

  Future<List<SearchTrace>> findAll();

  Future<List<SearchTrace>> findRecent(int limit);
}
