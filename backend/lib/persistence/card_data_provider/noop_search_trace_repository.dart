import '../../domain/catalog/search_trace.dart';
import 'search_trace_repository.dart';

/// No-op implementation: search trace persistence is disabled.
class NoOpSearchTraceRepository implements SearchTraceRepository {
  const NoOpSearchTraceRepository();

  @override
  Future<void> save(SearchTrace trace) async {}

  @override
  Future<List<SearchTrace>> findAll() async => [];

  @override
  Future<List<SearchTrace>> findRecent(int limit) async => [];
}
