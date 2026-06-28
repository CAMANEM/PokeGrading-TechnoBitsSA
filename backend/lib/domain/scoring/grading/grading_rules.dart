import 'dart:math';
import 'package:image/image.dart' as img;
import '../../image_services/preprocessing/roi_segmenter.dart';
import '../scoring_models.dart';

/// Business rules for grading validation and post-processing.
///
/// Enforces the grading protocol:
/// 1. Final grade cannot exceed lowest subgrade + 0.5
/// 2. Uncertainty band is calculated from subgrade standard deviation
/// 3. Internal coherence checks detect anomalies for manual review
/// 4. Corrupt ROI detection routes to manual queue
class GradingRules {
  /// Maximum allowed difference between final grade and minimum subgrade.
  static const double maxFinalGradeOffset = 0.5;

  /// Standard deviation threshold above which the result is considered uncertain.
  static const double uncertaintyThreshold = 1.5;

  /// Minimum allowed subgrade before flagging for manual review.
  static const double minimumSubgrade = 2.0;

  /// Maximum allowed deviation between any subgrade and the average.
  static const double maxCoherenceDeviation = 2.0;

  /// Minimum ROI dimension (pixels) to be considered valid.
  static const int minRoiDimension = 50;

  /// Applies grading rules to raw subgrades and returns a validated [GradingResult].
  ///
  /// Steps:
  /// 1. Calculate final grade as average of subgrades
  /// 2. Clamp: final grade <= min(subgrade) + 0.5
  /// 3. Calculate uncertainty band (std dev of subgrades)
  /// 4. Check coherence (no subgrade too far from average)
  /// 5. Flag for manual review if rules violated
  static GradingResult apply({
    required double centerGrade,
    required double cornersGrade,
    required double edgesGrade,
    required double surfaceGrade,
    String baselineUsed = 'global_v1',
    String algorithmVersion = '1.0.0',
  }) {
    final subgrades = [centerGrade, cornersGrade, edgesGrade, surfaceGrade];

    // Step 1: Raw average
    final rawAverage = subgrades.reduce((a, b) => a + b) / subgrades.length;

    // Step 2: Clamp final grade
    final clampedFinal = _clampFinalGrade(rawAverage, subgrades);

    // Step 3: Uncertainty band
    final uncertainty = _calculateUncertainty(subgrades);

    // Step 4: Coherence check
    final coherence = _validateCoherence(subgrades);

    // Step 5: Determine if manual review needed
    bool needsReview = false;
    String? reviewReason;

    if (coherence != null) {
      needsReview = true;
      reviewReason = coherence;
    } else if (uncertainty > uncertaintyThreshold) {
      needsReview = true;
      reviewReason =
          'Alta incertidumbre: desviacion estandar ${uncertainty.toStringAsFixed(2)} '
          'supera umbral de $uncertaintyThreshold';
    }

    // Check for critically low subgrades
    for (int i = 0; i < subgrades.length; i++) {
      if (subgrades[i] < minimumSubgrade) {
        needsReview = true;
        final dimension = ['centering', 'corners', 'edges', 'surface'][i];
        reviewReason =
            'Subgrado $dimension (${subgrades[i].toStringAsFixed(1)}) '
            'por debajo del minimo ($minimumSubgrade)';
        break;
      }
    }

    // Confidence score: inverse of uncertainty, normalised to 0-1
    final confidence = max(0.0, 1.0 - (uncertainty / 5.0));

    return GradingResult(
      centerGrade: centerGrade,
      cornersGrade: cornersGrade,
      edgesGrade: edgesGrade,
      surfaceGrade: surfaceGrade,
      finalGrade: clampedFinal,
      confidenceScore: confidence,
      uncertaintyBand: uncertainty,
      baselineUsed: baselineUsed,
      requiresManualReview: needsReview,
      reviewReason: reviewReason,
    );
  }

  /// Clamps the final grade so it does not exceed the lowest subgrade + offset.
  static double _clampFinalGrade(double rawAverage, List<double> subgrades) {
    final minSubgrade = subgrades.reduce(min);
    final maxAllowed = minSubgrade + maxFinalGradeOffset;
    return min(rawAverage, maxAllowed);
  }

  /// Calculates the standard deviation of subgrades as the uncertainty band.
  static double _calculateUncertainty(List<double> subgrades) {
    final mean = subgrades.reduce((a, b) => a + b) / subgrades.length;
    final squaredDiffs = subgrades.map((g) => pow(g - mean, 2)).toList();
    final variance =
        squaredDiffs.reduce((a, b) => a + b) / squaredDiffs.length;
    return sqrt(variance);
  }

  /// Validates internal coherence between subgrades.
  ///
  /// Returns an error message if any subgrade deviates too much from the
  /// average, or `null` if coherent.
  static String? _validateCoherence(List<double> subgrades) {
    final mean = subgrades.reduce((a, b) => a + b) / subgrades.length;
    final names = ['centering', 'corners', 'edges', 'surface'];

    for (int i = 0; i < subgrades.length; i++) {
      final deviation = (subgrades[i] - mean).abs();
      if (deviation > maxCoherenceDeviation) {
        return 'Incoherencia interna: ${names[i]} '
            '(${subgrades[i].toStringAsFixed(1)}) difiere '
            '${deviation.toStringAsFixed(2)} puntos del promedio '
            '(${mean.toStringAsFixed(1)})';
      }
    }

    return null;
  }

  /// Checks if a set of ROIs are valid (not corrupt or too small).
  ///
  /// Returns `true` if all ROIs have acceptable dimensions.
  static bool validateRois(RoiResult rois) {
    return _isValidImage(rois.centering) &&
        _isValidImage(rois.cornerTopLeft) &&
        _isValidImage(rois.cornerTopRight) &&
        _isValidImage(rois.cornerBottomLeft) &&
        _isValidImage(rois.cornerBottomRight) &&
        _isValidImage(rois.edgeTop) &&
        _isValidImage(rois.edgeBottom) &&
        _isValidImage(rois.edgeLeft) &&
        _isValidImage(rois.edgeRight) &&
        _isValidImage(rois.surface);
  }

  /// Checks if a single ROI image is valid.
  static bool _isValidImage(img.Image image) {
    return image.width >= minRoiDimension && image.height >= minRoiDimension;
  }
}
