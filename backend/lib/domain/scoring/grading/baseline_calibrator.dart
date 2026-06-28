/// @file
/// @brief Baseline calibrator from graded card datasets.
///
/// Takes a dataset of cards with PSA-confirmed grades and calibrates
/// optimal thresholds for a specific (set, finish) combination.
/// Uses statistical analysis to determine thresholds that best separate
/// different grade levels.

import 'dart:math';

import 'baseline_config.dart';
import 'baseline_registry.dart';

/// A single graded card record used for calibration.
class GradedCardRecord {
  /// Card image features extracted during preprocessing.
  final CardFeatures features;

  /// PSA-confirmed grade (1.0-10.0).
  final double psaGrade;

  /// Card set name.
  final String set;

  /// Card finish type.
  final String finish;

  const GradedCardRecord({
    required this.features,
    required this.psaGrade,
    required this.set,
    required this.finish,
  });
}

/// Extracted features from a card image for calibration.
class CardFeatures {
  /// Border symmetry ratio (left/right margin ratio).
  final double centeringSymmetry;

  /// Corner whitening percentage per corner.
  final List<double> cornerWhiteningPercentages;

  /// Edge whitening percentage per edge.
  final List<double> edgeWhiteningPercentages;

  /// Edge straightness CV per edge.
  final List<double> edgeStraightnessCVs;

  /// Surface scratch density (per 1000 pixels).
  final double surfaceScratchDensity;

  /// Surface uniformity CV.
  final double surfaceUniformityCV;

  const CardFeatures({
    required this.centeringSymmetry,
    required this.cornerWhiteningPercentages,
    required this.edgeWhiteningPercentages,
    required this.edgeStraightnessCVs,
    required this.surfaceScratchDensity,
    required this.surfaceUniformityCV,
  });
}

/// Result of calibration for a specific (set, finish).
class CalibrationResult {
  /// The calibrated baseline configuration.
  final BaselineConfig config;

  /// Number of cards used for calibration.
  final int cardCount;

  /// Average PSA grade of the calibration dataset.
  final double averagePsaGrade;

  /// Standard deviation of PSA grades.
  final double psaGradeStdDev;

  /// Calibration quality score (0.0-1.0, higher = better separation).
  final double qualityScore;

  /// Warnings or notes from calibration.
  final List<String> warnings;

  const CalibrationResult({
    required this.config,
    required this.cardCount,
    required this.averagePsaGrade,
    required this.psaGradeStdDev,
    required this.qualityScore,
    this.warnings = const [],
  });

  /// Whether this calibration has sufficient ground truth.
  bool get hasSufficientGroundTruth => cardCount >= BaselineRegistry.minimumReferenceCards;
}

/// Calibrates grading thresholds from a dataset of graded cards.
///
/// Uses percentile-based threshold optimization to find values that
/// best separate cards by PSA grade.
class BaselineCalibrator {
  /// Minimum cards required for calibration.
  static const int minimumCards = 15;

  /// Percentile to use for "perfect" thresholds (low defect = good).
  static const double perfectPercentile = 0.10;

  /// Percentile to use for "fail" thresholds (high defect = bad).
  static const double failPercentile = 0.90;

  /// Calibrates a baseline from a dataset of graded cards.
  ///
  /// [cards] must all have the same (set, finish).
  /// [baselineVersion] is the version string for the new baseline.
  /// [description] describes the calibration source.
  ///
  /// Returns a [CalibrationResult] with the calibrated baseline.
  static CalibrationResult calibrate({
    required List<GradedCardRecord> cards,
    required String baselineVersion,
    required String description,
  }) {
    final warnings = <String>[];

    if (cards.isEmpty) {
      return CalibrationResult(
        config: BaselineConfig.globalFallback,
        cardCount: 0,
        averagePsaGrade: 0,
        psaGradeStdDev: 0,
        qualityScore: 0,
        warnings: ['No cards provided for calibration'],
      );
    }

    if (cards.length < minimumCards) {
      warnings.add('Insufficient cards: ${cards.length}/$minimumCards minimum');
    }

    // Extract features from all cards
    final cornerWhitening = cards.expand((c) => c.features.cornerWhiteningPercentages).toList();
    final edgeWhitening = cards.expand((c) => c.features.edgeWhiteningPercentages).toList();
    final edgeStraightness = cards.expand((c) => c.features.edgeStraightnessCVs).toList();
    final surfaceScratch = cards.map((c) => c.features.surfaceScratchDensity).toList();
    final surfaceUniformity = cards.map((c) => c.features.surfaceUniformityCV).toList();

    // Calculate calibrated thresholds
    final cornerBrightnessThreshold = _calibrateBrightnessThreshold(cards);
    final edgeBrightnessThreshold = _calibrateBrightnessThreshold(cards);
    final scratchThreshold = _calibrateScratchThreshold(surfaceScratch, cards);

    // Calculate quality score based on grade separation
    final qualityScore = _calculateQualityScore(cards);

    final config = BaselineConfig(
      version: baselineVersion,
      description: description,
      // Centering: keep standard thresholds
      artworkVarianceThreshold: 300.0,
      artworkConsensusThreshold: 0.2,
      maxScanDepth: 150,
      // Corners: calibrated brightness threshold
      cornerWhiteningBrightnessThreshold: cornerBrightnessThreshold,
      cornerWhiteningSaturationThreshold: 10.0,
      cornerTipFraction: 0.4,
      cornerWhiteningPerfectThreshold: _percentile(cornerWhitening, perfectPercentile),
      cornerWhiteningFailThreshold: _percentile(cornerWhitening, failPercentile),
      // Edges: calibrated brightness threshold
      edgeWhiteningBrightnessThreshold: edgeBrightnessThreshold,
      edgeWhiteningSaturationThreshold: 10.0,
      outerEdgeRows: 3,
      edgeWhiteningPerfectThreshold: _percentile(edgeWhitening, perfectPercentile),
      edgeWhiteningFailThreshold: _percentile(edgeWhitening, failPercentile),
      straightnessCVPerfect: _percentile(edgeStraightness, perfectPercentile),
      straightnessCVPoor: _percentile(edgeStraightness, failPercentile),
      // Surface: calibrated thresholds
      scratchGradientThreshold: scratchThreshold.scratchGradient,
      maxComponentSizeForScratch: 10,
      perfectScratchDensity: _percentile(surfaceScratch, perfectPercentile),
      maxScratchDensity: _percentile(surfaceScratch, failPercentile),
      printLineCVThreshold: 0.40,
      uniformityBlockSize: 60,
      uniformCVThreshold: _percentile(surfaceUniformity, perfectPercentile),
      nonUniformCVThreshold: _percentile(surfaceUniformity, failPercentile),
    );

    final avgPsa = cards.map((c) => c.psaGrade).reduce((a, b) => a + b) / cards.length;
    final stdDevPsa = _standardDeviation(cards.map((c) => c.psaGrade).toList());

    return CalibrationResult(
      config: config,
      cardCount: cards.length,
      averagePsaGrade: avgPsa,
      psaGradeStdDev: stdDevPsa,
      qualityScore: qualityScore,
      warnings: warnings,
    );
  }

  /// Calibrates brightness threshold based on grade separation.
  ///
  /// Uses the Otsu-like method: find the brightness value that best
  /// separates high-grade cards (low whitening) from low-grade cards.
  static double _calibrateBrightnessThreshold(List<GradedCardRecord> cards) {
    if (cards.length < 10) return 245.0;

    // Sort by PSA grade
    final sorted = List<GradedCardRecord>.from(cards)
      ..sort((a, b) => b.psaGrade.compareTo(a.psaGrade));

    // Take top 25% (high grade) and bottom 25% (low grade)
    final topQuarter = sorted.sublist(0, sorted.length ~/ 4);
    final bottomQuarter = sorted.sublist(sorted.length * 3 ~/ 4);

    // Calculate average whitening for each group
    final topWhitening = topQuarter
        .expand((c) => c.features.cornerWhiteningPercentages)
        .toList();
    final bottomWhitening = bottomQuarter
        .expand((c) => c.features.cornerWhiteningPercentages)
        .toList();

    if (topWhitening.isEmpty || bottomWhitening.isEmpty) return 245.0;

    final topAvg = topWhitening.reduce((a, b) => a + b) / topWhitening.length;
    final bottomAvg = bottomWhitening.reduce((a, b) => a + b) / bottomWhitening.length;

    // The threshold should be between the two averages
    // Use the midpoint as a reasonable starting point
    final midpoint = (topAvg + bottomAvg) / 2;

    // Map back to brightness (higher whitening % = lower brightness threshold)
    // If high-grade cards have low whitening, use a higher brightness threshold
    return (245.0 + (5.0 * (1.0 - midpoint / 10.0))).clamp(230.0, 255.0);
  }

  /// Calibrates scratch gradient threshold.
  static ({double scratchGradient}) _calibrateScratchThreshold(
    List<double> surfaceScratch,
    List<GradedCardRecord> cards,
  ) {
    if (surfaceScratch.isEmpty) return (scratchGradient: 500.0);

    // Sort by grade and use the scratch density of high-grade cards
    // as the threshold (scratches below this are acceptable)
    final sorted = List<GradedCardRecord>.from(cards)
      ..sort((a, b) => b.psaGrade.compareTo(a.psaGrade));

    final highGradeScratch = sorted
        .take(sorted.length ~/ 2)
        .map((c) => c.features.surfaceScratchDensity)
        .toList();

    if (highGradeScratch.isEmpty) return (scratchGradient: 500.0);

    final maxAcceptable = _percentile(highGradeScratch, 0.90);
    return (scratchGradient: 500.0 * (1.0 + maxAcceptable / 10.0));
  }

  /// Calculates calibration quality score based on grade separation.
  ///
  /// Higher scores indicate the calibrated thresholds better separate
  /// different PSA grade levels.
  static double _calculateQualityScore(List<GradedCardRecord> cards) {
    if (cards.length < 10) return 0.5;

    // Group cards by grade range (1-3, 4-6, 7-10)
    final groups = <int, List<GradedCardRecord>>{
      1: [], // Low grades
      2: [], // Mid grades
      3: [], // High grades
    };

    for (final card in cards) {
      if (card.psaGrade <= 3) {
        groups[1]!.add(card);
      } else if (card.psaGrade <= 6) {
        groups[2]!.add(card);
      } else {
        groups[3]!.add(card);
      }
    }

    // Check if groups are well-separated
    final groupSizes = groups.values.map((g) => g.length).toList();
    final totalCards = groupSizes.reduce((a, b) => a + b);

    if (totalCards == 0) return 0.5;

    // Calculate balance score (how evenly distributed are the groups)
    final expectedPerGroup = totalCards / 3;
    final balanceScore = groupSizes
        .map((s) => 1.0 - (s - expectedPerGroup).abs() / totalCards)
        .reduce((a, b) => a + b) / 3;

    // Calculate separation score (how different are the features between groups)
    final separationScore = _calculateGroupSeparation(groups);

    // Combined quality score
    return (balanceScore * 0.4 + separationScore * 0.6).clamp(0.0, 1.0);
  }

  /// Calculates how well-separated the feature distributions are between groups.
  static double _calculateGroupSeparation(Map<int, List<GradedCardRecord>> groups) {
    // Simple metric: compare average whitening between groups
    final group1Avg = _averageCornerWhitening(groups[1]!);
    final group2Avg = _averageCornerWhitening(groups[2]!);
    final group3Avg = _averageCornerWhitening(groups[3]!);

    // Higher separation = better
    final range = max(group1Avg, max(group2Avg, group3Avg)) -
        min(group1Avg, min(group2Avg, group3Avg));

    return (range / 10.0).clamp(0.0, 1.0);
  }

  static double _averageCornerWhitening(List<GradedCardRecord> cards) {
    if (cards.isEmpty) return 0;
    final allWhitening = cards.expand((c) => c.features.cornerWhiteningPercentages).toList();
    if (allWhitening.isEmpty) return 0;
    return allWhitening.reduce((a, b) => a + b) / allWhitening.length;
  }

  /// Calculates a percentile value from a sorted list.
  static double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final index = (sorted.length * percentile).round().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  /// Calculates the standard deviation of a list of values.
  static double _standardDeviation(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSquaredDev = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    return sqrt(sumSquaredDev / values.length);
  }
}
