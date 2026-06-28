/// @file
/// @brief Baseline registry for per-(set, finish) calibrated grading.
///
/// Manages calibrated baselines for each (set, finish) combination.
/// When ground truth is sufficient (≥15 cards), a calibrated baseline is used.
/// Otherwise, falls back to the global baseline. The selection is recorded
/// in the output for transparency.

import 'baseline_config.dart';

/// Metadata about a registered baseline.
class BaselineEntry {
  /// The calibrated baseline configuration.
  final BaselineConfig config;

  /// Number of reference cards used for calibration.
  final int referenceCardCount;

  /// When this baseline was calibrated.
  final DateTime calibratedAt;

  /// Average PSA grade of the reference cards (for validation).
  final double averagePsaGrade;

  const BaselineEntry({
    required this.config,
    required this.referenceCardCount,
    required this.calibratedAt,
    required this.averagePsaGrade,
  });

  /// Whether this baseline has sufficient ground truth (≥15 cards).
  bool get hasSufficientGroundTruth => referenceCardCount >= 15;

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'reference_card_count': referenceCardCount,
    'calibrated_at': calibratedAt.toIso8601String(),
    'average_psa_grade': averagePsaGrade,
    'has_sufficient_ground_truth': hasSufficientGroundTruth,
  };
}

/// Result of baseline selection, including which baseline was chosen.
class BaselineSelection {
  /// The selected baseline configuration.
  final BaselineConfig config;

  /// The baseline version string (for output).
  final String version;

  /// Whether this is a calibrated baseline or the global fallback.
  final bool isCalibrated;

  /// If calibrated, the (set, finish) it applies to.
  final String? set;
  final String? finish;

  /// Number of reference cards used for calibration (0 if global fallback).
  final int referenceCardCount;

  const BaselineSelection({
    required this.config,
    required this.version,
    required this.isCalibrated,
    this.set,
    this.finish,
    this.referenceCardCount = 0,
  });

  /// Creates a global fallback selection.
  factory BaselineSelection.global() {
    return BaselineSelection(
      config: BaselineConfig.globalFallback,
      version: BaselineConfig.globalFallback.version,
      isCalibrated: false,
      set: null,
      finish: null,
      referenceCardCount: 0,
    );
  }

  /// Converts to JSON for output registration.
  Map<String, dynamic> toJson() => {
    'baseline_version': version,
    'baseline_is_calibrated': isCalibrated,
    'baseline_set': set,
    'baseline_finish': finish,
    'baseline_reference_card_count': referenceCardCount,
  };
}

/// Registry of calibrated baselines per (set, finish) combination.
///
/// Usage:
/// ```dart
/// final registry = BaselineRegistry();
///
/// // Register a calibrated baseline
/// registry.register('Base Set', 'holo', BaselineEntry(
///   config: BaselineConfig(version: 'base_set_holo_v1.0', description: '...'),
///   referenceCardCount: 25,
///   calibratedAt: DateTime.now(),
///   averagePsaGrade: 7.5,
/// ));
///
/// // Select baseline for a card
/// final selection = registry.select('Base Set', 'holo');
/// // selection.isCalibrated == true (25 >= 15)
///
/// final selection2 = registry.select('Unknown Set', 'reverse');
/// // selection2.isCalibrated == false (global fallback)
/// ```
class BaselineRegistry {
  /// Registered baselines keyed by "set|finish".
  final Map<String, BaselineEntry> _baselines = {};

  /// Minimum number of reference cards for a calibrated baseline.
  static const int minimumReferenceCards = 15;

  /// Registers a calibrated baseline for a (set, finish) combination.
  ///
  /// If the entry has fewer than [minimumReferenceCards], it is stored
  /// but won't be used for automatic selection (will fall back to global).
  void register(String set, String finish, BaselineEntry entry) {
    final key = _key(set, finish);
    _baselines[key] = entry;
  }

  /// Selects the appropriate baseline for a given (set, finish).
  ///
  /// Returns a calibrated baseline if:
  /// 1. An entry exists for this (set, finish)
  /// 2. The entry has sufficient ground truth (≥15 cards)
  ///
  /// Otherwise returns the global fallback baseline.
  BaselineSelection select(String? set, String? finish) {
    if (set == null || finish == null) {
      return BaselineSelection.global();
    }

    final key = _key(set, finish);
    final entry = _baselines[key];

    if (entry == null || !entry.hasSufficientGroundTruth) {
      return BaselineSelection.global();
    }

    return BaselineSelection(
      config: entry.config,
      version: entry.config.version,
      isCalibrated: true,
      set: set,
      finish: finish,
      referenceCardCount: entry.referenceCardCount,
    );
  }

  /// Returns the registered entry for a (set, finish), or null.
  BaselineEntry? getEntry(String set, String finish) {
    return _baselines[_key(set, finish)];
  }

  /// Returns all registered (set, finish) keys.
  List<String> get registeredSets => _baselines.keys.toList();

  /// Returns the total number of registered baselines.
  int get length => _baselines.length;

  /// Removes a registered baseline.
  void remove(String set, String finish) {
    _baselines.remove(_key(set, finish));
  }

  /// Clears all registered baselines.
  void clear() {
    _baselines.clear();
  }

  /// Generates the map key for a (set, finish) combination.
  static String _key(String set, String finish) {
    return '${set.toLowerCase()}|${finish.toLowerCase()}';
  }
}
