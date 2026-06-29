/// @file
/// @brief Grading orchestrator that combines all grading metrics.
///
/// Combines centering, corners, edges, and surface analysis into
/// a final pre-grade score following BGS (Beckett Grading Services)
/// weight standards. Supports calibrated baselines per (set, finish).

import 'dart:math';

import 'package:image/image.dart' as img;

import '../../image_services/preprocessing/roi_segmenter.dart';
import 'pregrading.dart';
import 'baseline_registry.dart';
import '../../image_services/grading/corner_whitening_detector.dart';
import '../../image_services/grading/edge_whitening_detector.dart';
import '../../image_services/grading/surface_scratch_detector.dart';
import '../../../core/config/app_config.dart';

/// Complete grading result with all sub-grades.
class GradingResult {
  /// Centering grade (1.0-10.0).
  final double centeringGrade;

  /// Corner grading result.
  final CornerGradingResult corners;

  /// Edge grading result.
  final EdgeGradingResult edges;

  /// Surface grading result.
  final SurfaceGradingResult surface;

  /// Final estimated grade (1.0-10.0).
  final double finalGrade;

  /// Confidence in the grading (0.0-1.0).
  final double confidence;

  /// Grade explanation.
  final String explanation;

  /// Baseline used for this grading.
  final BaselineSelection baseline;

  /// Uncertainty band: lower bound of the grade.
  final double gradeLowerBound;

  /// Uncertainty band: upper bound of the grade.
  final double gradeUpperBound;

  /// Whether the coherence rule was applied (final ≤ lowest subgrade + 0.5).
  final bool coherenceRuleApplied;

  /// The lowest subgrade value.
  final double lowestSubgrade;

  const GradingResult({
    required this.centeringGrade,
    required this.corners,
    required this.edges,
    required this.surface,
    required this.finalGrade,
    required this.confidence,
    required this.explanation,
    required this.baseline,
    required this.gradeLowerBound,
    required this.gradeUpperBound,
    required this.coherenceRuleApplied,
    required this.lowestSubgrade,
  });

  /// Converts to JSON for output.
  Map<String, dynamic> toJson() => {
    'centering_grade': double.parse(centeringGrade.toStringAsFixed(2)),
    'corners': corners.toJson(),
    'edges': edges.toJson(),
    'surface': surface.toJson(),
    'final_grade': double.parse(finalGrade.toStringAsFixed(2)),
    'confidence': double.parse(confidence.toStringAsFixed(4)),
    'explanation': explanation,
    // Baseline info
    ...baseline.toJson(),
    // Uncertainty band
    'grade_lower_bound': double.parse(gradeLowerBound.toStringAsFixed(2)),
    'grade_upper_bound': double.parse(gradeUpperBound.toStringAsFixed(2)),
    // Coherence
    'coherence_rule_applied': coherenceRuleApplied,
    'lowest_subgrade': double.parse(lowestSubgrade.toStringAsFixed(2)),
  };
}

/// Orchestrates the complete grading pipeline.
///
/// Combines all grading metrics using BGS-standard weights:
/// - Centering: 40%
/// - Corners: 20%
/// - Edges: 20%
/// - Surface: 20%
class GradingOrchestrator {
  /// Algorithm version identifier. Immutable — old evaluations reference the
  /// version that produced them and are never re-graded.
  static const String algorithmVersion = '1.0.0';

  /// Minimum grade value.
  static const double minGrade = 1.0;

  /// Maximum grade value.
  static const double maxGrade = 10.0;

  /// Maximum confidence value (when stdDev is high).
  static const double minConfidence = 0.5;

  /// --- Explanation Thresholds ---

  /// Centering grade below this triggers "desalineado" warning.
  static const double centeringWarningThreshold = 7.0;

  /// Average whitening above this triggers corner warning.
  static const double cornerWhiteningWarningThreshold = 0.3;

  /// Average edge quality below this triggers edge warning.
  static const double edgeQualityWarningThreshold = 0.6;

  /// Number of corners/edges for display.
  static const int totalRegions = 4;

  /// Uncertainty factor: how much to expand the confidence interval.
  /// Based on confidence: lower confidence = wider band.
  static const double uncertaintyFactor = 0.5;

  /// Performs complete grading on a card's ROIs.
  ///
  /// [rois] contains all extracted regions from the card.
  /// [fullImage] is the original card image (for centering detection).
  /// [baselineSelection] is the selected baseline for this (set, finish).
  ///   If null, uses the global fallback.
  ///
  /// Returns a [GradingResult] with all sub-grades and final score.
  static GradingResult grade(
    RoiResult rois, {
    img.Image? fullImage,
    BaselineSelection? baselineSelection,
    ThresholdConfig? thresholds,
  }) {
    final t = thresholds ?? const ThresholdConfig();
    // Select baseline (use global if not provided)
    final baseline = baselineSelection ?? BaselineSelection.global();

    // 1. Centering grade - use full image if provided for white border detection
    final centeringGrade = Grading.centerGrade(
      fullImage ?? rois.centering,
    );

    // 2. Corner grading (clone to avoid mutation from grayscale/sobel)
    final cornerImages = {
      'top_left': img.Image.from(rois.cornerTopLeft),
      'top_right': img.Image.from(rois.cornerTopRight),
      'bottom_left': img.Image.from(rois.cornerBottomLeft),
      'bottom_right': img.Image.from(rois.cornerBottomRight),
    };
    final corners = CornerWhiteningDetector.analyzeAllCorners(cornerImages);

    // 3. Edge grading (clone to avoid mutation)
    final edgeImages = {
      'top': img.Image.from(rois.edgeTop),
      'bottom': img.Image.from(rois.edgeBottom),
      'left': img.Image.from(rois.edgeLeft),
      'right': img.Image.from(rois.edgeRight),
    };
    final edges = EdgeWhiteningDetector.analyzeAllEdges(edgeImages);

    // 4. Surface grading (clone to avoid mutation)
    final surfaceImage = img.Image.from(rois.surface);
    final surface = SurfaceScratchDetector.analyzeSurface(surfaceImage);

    // 5. Calculate weighted grade
    final weightedGrade = centeringGrade * t.gradingCenteringWeight +
        corners.grade * t.gradingCornersWeight +
        edges.grade * t.gradingEdgesWeight +
        surface.grade * t.gradingSurfaceWeight;

    // 6. Apply coherence rule: final grade ≤ lowest subgrade + 0.5
    final lowestSubgrade = _findLowestSubgrade(
      centeringGrade,
      corners.grade,
      edges.grade,
      surface.grade,
    );
    final coherenceMax = lowestSubgrade + 0.5;
    final coherenceRuleApplied = weightedGrade > coherenceMax;
    final finalGrade = (coherenceRuleApplied ? coherenceMax : weightedGrade)
        .clamp(minGrade, maxGrade);

    // 7. Calculate confidence based on consistency
    final confidence = _calculateConfidence(
      centeringGrade: centeringGrade,
      corners: corners,
      edges: edges,
      surface: surface,
      thresholds: t,
    );

    // 8. Calculate uncertainty band
    final uncertainty = _calculateUncertainty(
      finalGrade: finalGrade,
      confidence: confidence,
      subgrades: [centeringGrade, corners.grade, edges.grade, surface.grade],
    );

    // 9. Generate explanation
    final explanation = _generateExplanation(
      centeringGrade: centeringGrade,
      corners: corners,
      edges: edges,
      surface: surface,
      finalGrade: finalGrade,
      coherenceRuleApplied: coherenceRuleApplied,
      lowestSubgrade: lowestSubgrade,
    );

    return GradingResult(
      centeringGrade: centeringGrade,
      corners: corners,
      edges: edges,
      surface: surface,
      finalGrade: finalGrade,
      confidence: confidence,
      explanation: explanation,
      baseline: baseline,
      gradeLowerBound: max(minGrade, finalGrade - uncertainty),
      gradeUpperBound: min(maxGrade, finalGrade + uncertainty),
      coherenceRuleApplied: coherenceRuleApplied,
      lowestSubgrade: lowestSubgrade,
    );
  }

  /// Finds the lowest subgrade among the four dimensions.
  static double _findLowestSubgrade(
    double centering,
    double corners,
    double edges,
    double surface,
  ) {
    return min(centering, min(corners, min(edges, surface)));
  }

  /// Calculates uncertainty band width based on confidence and subgrade spread.
  ///
  /// Lower confidence and higher subgrade spread = wider uncertainty band.
  static double _calculateUncertainty({
    required double finalGrade,
    required double confidence,
    required List<double> subgrades,
  }) {
    // Base uncertainty from confidence (lower confidence = wider band)
    final confidenceUncertainty = (1.0 - confidence) * uncertaintyFactor;

    // Additional uncertainty from subgrade spread
    final mean = subgrades.reduce((a, b) => a + b) / subgrades.length;
    final sumSquaredDev = subgrades
        .map((g) => (g - mean) * (g - mean))
        .reduce((a, b) => a + b);
    final stdDev = sqrt(sumSquaredDev / subgrades.length);
    final spreadUncertainty = stdDev * 0.3;

    return (confidenceUncertainty + spreadUncertainty).clamp(0.0, 2.0);
  }

  /// Calculates confidence score based on consistency of sub-grades.
  ///
  /// High consistency (low stdDev) = high confidence.
  /// Low consistency (high stdDev) = low confidence.
  static double _calculateConfidence({
    required double centeringGrade,
    required CornerGradingResult corners,
    required EdgeGradingResult edges,
    required SurfaceGradingResult surface,
    ThresholdConfig? thresholds,
  }) {
    final t = thresholds ?? const ThresholdConfig();
    final grades = [centeringGrade, corners.grade, edges.grade, surface.grade];

    // Calculate standard deviation
    final mean = grades.reduce((a, b) => a + b) / grades.length;
    final sumSquaredDev = grades
        .map((g) => (g - mean) * (g - mean))
        .reduce((a, b) => a + b);
    final stdDev = sqrt(sumSquaredDev / grades.length);

    // Map stdDev to confidence
    if (stdDev <= t.gradingHighConfidenceStdDev) return 1.0;
    if (stdDev >= t.gradingLowConfidenceStdDev) return minConfidence;
    return 1.0 - (stdDev - t.gradingHighConfidenceStdDev) /
        (t.gradingLowConfidenceStdDev - t.gradingHighConfidenceStdDev);
  }

  /// Generates human-readable explanation of the grade.
  static String _generateExplanation({
    required double centeringGrade,
    required CornerGradingResult corners,
    required EdgeGradingResult edges,
    required SurfaceGradingResult surface,
    required double finalGrade,
    required bool coherenceRuleApplied,
    required double lowestSubgrade,
  }) {
    final issues = <String>[];

    // Check centering
    if (centeringGrade < centeringWarningThreshold) {
      issues.add('Centering desalineado (${centeringGrade.toStringAsFixed(1)}/10)');
    }

    // Check corners
    if (corners.averageWhitening > cornerWhiteningWarningThreshold) {
      issues.add('Esquinas con whitening (${corners.passedCount}/$totalRegions pasan)');
    }

    // Check edges
    if (edges.averageQuality < edgeQualityWarningThreshold) {
      issues.add('Bordes con defectos (${edges.passedCount}/$totalRegions pasan)');
    }

    // Check surface
    if (!surface.passes) {
      issues.add('Superficie con ${surface.scratchCount} defectos detectados');
    }

    // Note coherence rule application
    if (coherenceRuleApplied) {
      issues.add('Grade ajustado por regla de coherencia (max: ${lowestSubgrade.toStringAsFixed(1)} + 0.5)');
    }

    if (issues.isEmpty) {
      return 'Carta en excelente estado. Grade estimado: ${finalGrade.toStringAsFixed(1)}/10';
    }

    return 'Defectos detectados: ${issues.join("; ")}. Grade estimado: ${finalGrade.toStringAsFixed(1)}/10';
  }
}
