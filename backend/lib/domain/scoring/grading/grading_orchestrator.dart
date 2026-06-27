/// @file
/// @brief Grading orchestrator that combines all grading metrics.
///
/// Combines centering, corners, edges, and surface analysis into
/// a final pre-grade score following BGS (Beckett Grading Services)
/// weight standards.

import 'dart:math';

import 'package:image/image.dart' as img;

import '../../image_services/preprocessing/roi_segmenter.dart';
import 'pregrading.dart';
import '../../image_services/grading/corner_whitening_detector.dart';
import '../../image_services/grading/edge_whitening_detector.dart';
import '../../image_services/grading/surface_scratch_detector.dart';

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

  const GradingResult({
    required this.centeringGrade,
    required this.corners,
    required this.edges,
    required this.surface,
    required this.finalGrade,
    required this.confidence,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
    'centering_grade': double.parse(centeringGrade.toStringAsFixed(2)),
    'corners': corners.toJson(),
    'edges': edges.toJson(),
    'surface': surface.toJson(),
    'final_grade': double.parse(finalGrade.toStringAsFixed(2)),
    'confidence': double.parse(confidence.toStringAsFixed(4)),
    'explanation': explanation,
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
  /// Weight for centering grade (BGS standard: 40%).
  static const double centeringWeight = 0.40;

  /// Weight for corners grade (BGS standard: 20%).
  static const double cornersWeight = 0.20;

  /// Weight for edges grade (BGS standard: 20%).
  static const double edgesWeight = 0.20;

  /// Weight for surface grade (BGS standard: 20%).
  static const double surfaceWeight = 0.20;

  /// Minimum grade value.
  static const double minGrade = 1.0;

  /// Maximum grade value.
  static const double maxGrade = 10.0;

  /// --- Confidence Calculation Constants ---

  /// Standard deviation threshold for high confidence.
  static const double highConfidenceStdDev = 0.5;

  /// Standard deviation threshold for low confidence.
  static const double lowConfidenceStdDev = 2.0;

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

  /// Performs complete grading on a card's ROIs.
  ///
  /// [rois] contains all extracted regions from the card.
  /// [fullImage] is the original card image (for centering detection).
  /// If null, uses the centering ROI (may not work for white-bordered cards).
  ///
  /// Returns a [GradingResult] with all sub-grades and final score.
  static GradingResult grade(RoiResult rois, {img.Image? fullImage}) {
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

    // 5. Calculate final grade using BGS weights
    final finalGrade = (centeringGrade * centeringWeight +
            corners.grade * cornersWeight +
            edges.grade * edgesWeight +
            surface.grade * surfaceWeight)
        .clamp(minGrade, maxGrade);

    // 6. Calculate confidence based on consistency
    final confidence = _calculateConfidence(
      centeringGrade: centeringGrade,
      corners: corners,
      edges: edges,
      surface: surface,
    );

    // 7. Generate explanation
    final explanation = _generateExplanation(
      centeringGrade: centeringGrade,
      corners: corners,
      edges: edges,
      surface: surface,
      finalGrade: finalGrade,
    );

    return GradingResult(
      centeringGrade: centeringGrade,
      corners: corners,
      edges: edges,
      surface: surface,
      finalGrade: finalGrade,
      confidence: confidence,
      explanation: explanation,
    );
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
  }) {
    final grades = [centeringGrade, corners.grade, edges.grade, surface.grade];

    // Calculate standard deviation
    final mean = grades.reduce((a, b) => a + b) / grades.length;
    final sumSquaredDev = grades
        .map((g) => (g - mean) * (g - mean))
        .reduce((a, b) => a + b);
    final stdDev = sqrt(sumSquaredDev / grades.length);

    // Map stdDev to confidence
    if (stdDev <= highConfidenceStdDev) return 1.0;
    if (stdDev >= lowConfidenceStdDev) return minConfidence;
    return 1.0 - (stdDev - highConfidenceStdDev) /
        (lowConfidenceStdDev - highConfidenceStdDev);
  }

  /// Generates human-readable explanation of the grade.
  static String _generateExplanation({
    required double centeringGrade,
    required CornerGradingResult corners,
    required EdgeGradingResult edges,
    required SurfaceGradingResult surface,
    required double finalGrade,
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

    if (issues.isEmpty) {
      return 'Carta en excelente estado. Grade estimado: ${finalGrade.toStringAsFixed(1)}/10';
    }

    return 'Defectos detectados: ${issues.join("; ")}. Grade estimado: ${finalGrade.toStringAsFixed(1)}/10';
  }
}
