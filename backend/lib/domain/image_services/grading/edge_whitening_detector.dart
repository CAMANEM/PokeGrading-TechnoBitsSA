/// @file
/// @brief Edge whitening detection service.
///
/// Detects whitening and damage defects on card edges by analyzing
/// the outermost pixels of the edge strip. White borders are NORMAL
/// on Pokemon cards, so we only check the very outer edge for damage.

import 'dart:math';

import 'package:image/image.dart' as img;

/// Result of edge analysis for a single edge.
class EdgeWhiteningResult {
  /// Edge position identifier (e.g., "top", "bottom", "left", "right").
  final String position;

  /// Whitening score: 0.0 (perfect) to 1.0 (severe whitening).
  final double whiteningScore;

  /// Edge straightness score: 0.0 (very rough) to 1.0 (perfectly straight).
  final double straightnessScore;

  /// Combined edge quality score (0.0-1.0).
  final double qualityScore;

  /// Percentage of pixels detected as whitened along the edge.
  final double whiteningPercentage;

  /// Whether this edge passes quality threshold.
  final bool passes;

  const EdgeWhiteningResult({
    required this.position,
    required this.whiteningScore,
    required this.straightnessScore,
    required this.qualityScore,
    required this.whiteningPercentage,
    required this.passes,
  });

  Map<String, dynamic> toJson() => {
    'position': position,
    'whitening_score': double.parse(whiteningScore.toStringAsFixed(4)),
    'straightness_score': double.parse(straightnessScore.toStringAsFixed(4)),
    'quality_score': double.parse(qualityScore.toStringAsFixed(4)),
    'whitening_percentage': double.parse(whiteningPercentage.toStringAsFixed(2)),
    'passes': passes,
  };
}

/// Combined result for all four edges.
class EdgeGradingResult {
  /// Individual edge results.
  final List<EdgeWhiteningResult> edges;

  /// Overall edge grade (1.0-10.0 scale).
  final double grade;

  /// Average quality score across all edges (0.0-1.0).
  final double averageQuality;

  /// Number of edges that passed.
  final int passedCount;

  const EdgeGradingResult({
    required this.edges,
    required this.grade,
    required this.averageQuality,
    required this.passedCount,
  });

  Map<String, dynamic> toJson() => {
    'edges': edges.map((e) => e.toJson()).toList(),
    'grade': double.parse(grade.toStringAsFixed(2)),
    'average_quality': double.parse(averageQuality.toStringAsFixed(4)),
    'passed_count': passedCount,
    'total_edges': edges.length,
  };
}

/// Detects whitening and damage defects on card edges.
///
/// Pokemon cards have white borders as part of their design. This is NORMAL.
/// Whitening damage only occurs at the very outer edge of the card where
/// the cardstock core is exposed. We analyze only the outermost row/column
/// of pixels to avoid false positives from white borders.
class EdgeWhiteningDetector {
  /// Brightness threshold for detecting white cardstock pixels (0-255).
  /// Must be high enough to distinguish white border (~220-240) from
  /// exposed cardstock damage (~250-255).
  static const double whiteningBrightnessThreshold = 245.0;

  /// Saturation threshold for detecting white cardstock pixels (0-255).
  /// White cardstock has very low saturation (< 10).
  static const double whiteningSaturationThreshold = 10.0;

  /// Percentage of whitened pixels that triggers a fail.
  static const double whiteningFailThreshold = 3.0;

  /// Percentage of whitened pixels for perfect score.
  static const double whiteningPerfectThreshold = 0.5;

  /// Weight for whitening in the combined quality score.
  static const double whiteningWeight = 0.6;

  /// Weight for straightness in the combined quality score.
  static const double straightnessWeight = 0.4;

  /// Number of outer rows/columns to analyze for whitening.
  /// We only check the very edge of the card, not the entire ROI.
  static const int outerEdgeRows = 3;

  /// Coefficient of variation threshold for perfect straightness.
  static const double straightnessCVPerfect = 0.10;

  /// Coefficient of variation threshold for poor straightness.
  /// Raised from 0.20 to 0.35 to accommodate uneven lighting in raw photos.
  static const double straightnessCVPoor = 0.35;

  /// Luminance coefficient for Red channel (ITU-R BT.709).
  static const double luminanceR = 0.2126;

  /// Luminance coefficient for Green channel (ITU-R BT.709).
  static const double luminanceG = 0.7152;

  /// Luminance coefficient for Blue channel (ITU-R BT.709).
  static const double luminanceB = 0.0722;

  /// Analyzes a single edge ROI for whitening and straightness.
  ///
  /// [edgeImage] is the cropped edge region.
  /// [position] identifies which edge ("top", "bottom", "left", "right").
  ///
  /// Returns an [EdgeWhiteningResult] with the analysis.
  static EdgeWhiteningResult analyzeEdge(
    img.Image edgeImage, {
    required String position,
  }) {
    // Check if this edge is predominantly white (white-bordered card)
    // If so, skip whitening detection and give a clean score
    final isWhiteBorder = _isWhiteBorderEdge(edgeImage);
    if (isWhiteBorder) {
      // For white-bordered cards, we can't reliably measure straightness
      // from raw photos due to uneven lighting. Use a reasonable default.
      return EdgeWhiteningResult(
        position: position,
        whiteningScore: 0.0,
        straightnessScore: 0.8,
        qualityScore: (1.0 - 0.0) * whiteningWeight + 0.8 * straightnessWeight,
        whiteningPercentage: 0.0,
        passes: true,
      );
    }

    // Analyze whitening (only on outermost pixels)
    final whiteningResult = _analyzeWhitening(edgeImage, position: position);

    // Analyze straightness using brightness consistency
    final straightnessResult = _analyzeStraightness(
      edgeImage,
      position: position,
    );

    // If no whitening damage detected, apply a minimum straightness floor.
    // For unprocessed photos, brightness-based straightness is unreliable,
    // but 0% whitening indicates the edge is physically intact.
    final effectiveStraightness = whiteningResult.$2 < whiteningPerfectThreshold
        ? max(straightnessResult, 0.5)
        : straightnessResult;

    // Combined quality score (lower whiteningScore = better, so invert it)
    final qualityScore = (1.0 - whiteningResult.$1) * whiteningWeight +
        effectiveStraightness * straightnessWeight;

    // Determine pass/fail based on whitening only
    final passes = whiteningResult.$2 < whiteningFailThreshold;

    return EdgeWhiteningResult(
      position: position,
      whiteningScore: whiteningResult.$1,
      straightnessScore: effectiveStraightness,
      qualityScore: qualityScore,
      whiteningPercentage: whiteningResult.$2,
      passes: passes,
    );
  }

  /// Checks if an edge ROI is predominantly white (white-bordered card).
  /// If >70% of pixels have brightness >200, it's a white border.
  static bool _isWhiteBorderEdge(img.Image edgeImage) {
    int brightCount = 0;
    final total = edgeImage.width * edgeImage.height;
    final sampleStep = max(1, total ~/ 2000); // Sample ~2000 pixels

    int idx = 0;
    for (int y = 0; y < edgeImage.height; y++) {
      for (int x = 0; x < edgeImage.width; x++) {
        idx++;
        if (idx % sampleStep != 0) continue;

        final pixel = edgeImage.getPixel(x, y);
        final brightness = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        if (brightness > 200) brightCount++;
      }
    }

    final sampledCount = total ~/ sampleStep;
    return sampledCount > 0 && (brightCount / sampledCount) > 0.7;
  }

  /// Analyzes whitening along the outer edge.
  /// Only checks the outermost rows/columns where the physical edge is.
  /// Returns (whiteningScore, whiteningPercentage).
  static (double, double) _analyzeWhitening(
    img.Image edgeImage, {
    required String position,
  }) {
    int whitenedPixels = 0;
    int totalPixels = 0;

    // Only analyze the outermost pixels where the physical edge is
    for (int y = 0; y < edgeImage.height; y++) {
      for (int x = 0; x < edgeImage.width; x++) {
        // Check if this pixel is in the outer edge region
        if (!_isOuterEdge(x, y, edgeImage.width, edgeImage.height, position)) {
          continue;
        }

        totalPixels++;
        final pixel = edgeImage.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        // ITU-R BT.709 luminance
        final brightness = luminanceR * r + luminanceG * g + luminanceB * b;

        // Saturation (HSV simplified)
        final maxVal = [r, g, b].reduce((a, b) => a > b ? a : b);
        final minVal = [r, g, b].reduce((a, b) => a < b ? a : b);
        final saturation = maxVal > 0 ? ((maxVal - minVal) / maxVal) * 255 : 0;

        // Detect whitening: very high brightness + very low saturation
        if (brightness > whiteningBrightnessThreshold &&
            saturation < whiteningSaturationThreshold) {
          whitenedPixels++;
        }
      }
    }

    final whiteningPercentage = totalPixels > 0
        ? (whitenedPixels / totalPixels) * 100
        : 0.0;

    double whiteningScore;
    if (whiteningPercentage <= whiteningPerfectThreshold) {
      whiteningScore = 0.0;
    } else if (whiteningPercentage >= whiteningFailThreshold) {
      whiteningScore = 1.0;
    } else {
      whiteningScore = (whiteningPercentage - whiteningPerfectThreshold) /
          (whiteningFailThreshold - whiteningPerfectThreshold);
    }

    return (whiteningScore, whiteningPercentage);
  }

  /// Checks if a pixel is in the outer edge region.
  ///
  /// For top edge: first N rows
  /// For bottom edge: last N rows
  /// For left edge: first N columns
  /// For right edge: last N columns
  static bool _isOuterEdge(
    int x,
    int y,
    int width,
    int height,
    String position,
  ) {
    switch (position) {
      case 'top':
        return y < outerEdgeRows;
      case 'bottom':
        return y >= height - outerEdgeRows;
      case 'left':
        return x < outerEdgeRows;
      case 'right':
        return x >= width - outerEdgeRows;
      default:
        return false;
    }
  }

  /// Analyzes edge straightness by measuring brightness consistency.
  /// Normalizes brightness values before computing CV to handle uneven lighting.
  static double _analyzeStraightness(
    img.Image edgeImage, {
    required String position,
  }) {
    // Clone to avoid mutation from grayscale
    final gray = img.grayscale(img.Image.from(edgeImage));
    final isHorizontal = position == 'top' || position == 'bottom';

    // Extract brightness values along the outer edge (middle portion only)
    final edgeBrightness = <double>[];
    
    // Skip first/last 10% to avoid corner artifacts
    final skipPercent = 0.1;

    if (isHorizontal) {
      final y = position == 'top' ? 0 : gray.height - 1;
      final startX = (gray.width * skipPercent).round();
      final endX = gray.width - (gray.width * skipPercent).round();
      for (int x = startX; x < endX; x++) {
        edgeBrightness.add(gray.getPixel(x, y).r.toDouble());
      }
    } else {
      final x = position == 'left' ? 0 : gray.width - 1;
      final startY = (gray.height * skipPercent).round();
      final endY = gray.height - (gray.height * skipPercent).round();
      for (int y = startY; y < endY; y++) {
        edgeBrightness.add(gray.getPixel(x, y).r.toDouble());
      }
    }

    if (edgeBrightness.isEmpty || edgeBrightness.length < 10) return 0.5;

    // Normalize: clip to 5th-95th percentile range to remove lighting gradients
    final sorted = List<double>.from(edgeBrightness)..sort();
    final p5 = sorted[(sorted.length * 0.05).round()];
    final p95 = sorted[(sorted.length * 0.95).round()];
    final range = p95 - p5;
    if (range < 1) return 1.0; // Already uniform
    
    final normalized = edgeBrightness.map((v) => 
        ((v - p5) / range * 255).clamp(0.0, 255.0)).toList();

    final cv = _coefficientOfVariation(normalized);

    if (cv < straightnessCVPerfect) return 1.0;
    if (cv > straightnessCVPoor) return 0.0;
    return 1.0 - (cv - straightnessCVPerfect) /
        (straightnessCVPoor - straightnessCVPerfect);
  }

  /// Calculates coefficient of variation (std dev / mean).
  static double _coefficientOfVariation(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0.0;

    final sumSquaredDev = values
        .map((v) => pow(v - mean, 2))
        .reduce((a, b) => a + b);
    final stdDev = sqrt(sumSquaredDev / values.length);

    return stdDev / mean;
  }

  /// Analyzes all four edge ROIs and produces a combined grade.
  static EdgeGradingResult analyzeAllEdges(Map<String, img.Image> edgeImages) {
    final results = <EdgeWhiteningResult>[];

    for (final entry in edgeImages.entries) {
      results.add(analyzeEdge(entry.value, position: entry.key));
    }

    final averageQuality = results
            .map((r) => r.qualityScore)
            .reduce((a, b) => a + b) /
        results.length;

    final grade = 1.0 + averageQuality * 9.0;
    final passedCount = results.where((r) => r.passes).length;

    return EdgeGradingResult(
      edges: results,
      grade: grade,
      averageQuality: averageQuality,
      passedCount: passedCount,
    );
  }
}
