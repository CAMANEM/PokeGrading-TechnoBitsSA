import '../../domain/scoring/grading/baseline_registry.dart';
import '../card_data_provider/calibrated_baseline_repository.dart';

/// In-memory mock of CalibratedBaselineRepository for testing.
class MockCalibratedBaselineRepository implements CalibratedBaselineRepository {
  final Map<String, BaselineEntry> _baselines = {};

  @override
  Future<void> storeBaseline(StoreBaselineInput input) async {
    final key = '${input.setName.toLowerCase()}|${input.finish.toLowerCase()}';
    _baselines[key] = BaselineEntry(
      config: input.config,
      referenceCardCount: input.referenceCardCount,
      calibratedAt: DateTime.now().toUtc(),
      averagePsaGrade: input.averagePsaGrade,
    );
  }

  @override
  Future<BaselineEntry?> findBaseline({
    required String set,
    required String finish,
  }) async {
    final key = '${set.toLowerCase()}|${finish.toLowerCase()}';
    final entry = _baselines[key];
    if (entry == null || !entry.hasSufficientGroundTruth) return null;
    return entry;
  }

  @override
  Future<List<StoredBaseline>> findAllBaselines() async {
    int id = 0;
    return _baselines.entries.map((e) {
      final parts = e.key.split('|');
      return StoredBaseline(
        id: id++,
        setName: parts[0],
        finish: parts[1],
        entry: e.value,
      );
    }).toList();
  }

  @override
  Future<void> deactivateBaseline({
    required String set,
    required String finish,
  }) async {
    final key = '${set.toLowerCase()}|${finish.toLowerCase()}';
    _baselines.remove(key);
  }
}
