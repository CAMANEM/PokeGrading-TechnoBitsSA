/// @file
/// @brief Repository for persisting and loading calibrated baselines.

import '../../domain/scoring/grading/baseline_config.dart';
import '../../domain/scoring/grading/baseline_registry.dart';

/// Input for storing a calibrated baseline.
class StoreBaselineInput {
  final String setName;
  final String finish;
  final BaselineConfig config;
  final int referenceCardCount;
  final double averagePsaGrade;
  final double psaGradeStdDev;
  final double qualityScore;

  const StoreBaselineInput({
    required this.setName,
    required this.finish,
    required this.config,
    required this.referenceCardCount,
    required this.averagePsaGrade,
    required this.psaGradeStdDev,
    required this.qualityScore,
  });
}

/// Abstract repository for calibrated baseline persistence.
abstract class CalibratedBaselineRepository {
  /// Stores or updates a calibrated baseline for a (set, finish).
  Future<void> storeBaseline(StoreBaselineInput input);

  /// Finds a calibrated baseline by (set, finish).
  /// Returns null if none exists or if inactive.
  Future<BaselineEntry?> findBaseline({
    required String set,
    required String finish,
  });

  /// Returns all active calibrated baselines.
  Future<List<StoredBaseline>> findAllBaselines();

  /// Deactivates a baseline for a (set, finish).
  Future<void> deactivateBaseline({
    required String set,
    required String finish,
  });
}

/// A stored baseline record from the database.
class StoredBaseline {
  final int id;
  final String setName;
  final String finish;
  final BaselineEntry entry;

  const StoredBaseline({
    required this.id,
    required this.setName,
    required this.finish,
    required this.entry,
  });
}
