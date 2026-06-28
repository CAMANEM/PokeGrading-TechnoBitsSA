/// @file
/// @brief Corner whitening detection service.
///
/// Detects whitening defects on card corners by analyzing the extreme
/// tip of the corner. White borders are NORMAL on Pokemon cards, so
/// we only check the very corner tip for exposed cardstock damage.

import 'dart:math';

import 'package:image/image.dart' as img;

/// Result of corner whitening analysis for a single corner.
class CornerWhiteningResult {
  /// Corner position identifier (e.g., "top_left", "top_right").
  final String position;

  /// Whitening score: 0.0 (perfect) to 1.0 (severe whitening).
  final double whiteningScore;

  /// Percentage of pixels detected as whitened in the corner tip.
  final double whiteningPercentage;

  /// Whether this corner passes quality threshold.
  final bool passes;

  const CornerWhiteningResult({
    required this.position,
    required this.whiteningScore,
    required this.whiteningPercentage,
    required this.passes,
  });

  Map<String, dynamic> toJson() => {
    'position': position,
    'whitening_score': double.parse(whiteningScore.toStringAsFixed(4)),
    'whitening_percentage': double.parse(whiteningPercentage.toStringAsFixed(2)),
    'passes': passes,
  };
}

/// Combined result for all four corners.
class CornerGradingResult {
  /// Individual corner results.
  final List<CornerWhiteningResult> corners;

  /// Overall corner grade (1.0-10.0 scale).
  final double grade;

  /// Average whitening score across all corners (0.0-1.0).
  final double averageWhitening;

  /// Number of corners that passed.
  final int passedCount;

  const CornerGradingResult({
    required this.corners,
    required this.grade,
    required this.averageWhitening,
    required this.passedCount,
  });

  Map<String, dynamic> toJson() => {
    'corners': corners.map((c) => c.toJson()).toList(),
    'grade': double.parse(grade.toStringAsFixed(2)),
    'average_whitening': double.parse(averageWhitening.toStringAsFixed(4)),
    'passed_count': passedCount,
    'total_corners': corners.length,
  };
}

/// Detects whitening defects on card corners.
///
/// Pokemon cards have white borders as part of their design. This is NORMAL.
/// Whitening damage only occurs at the very tip of the corner where the
/// cardstock core is exposed. We analyze only the extreme corner tip
/// (a small triangular region) to avoid false positives from white borders.
class CornerWhiteningDetector {
  /// Brightness threshold for detecting white cardstock pixels (0-255).
  /// Must be high enough to distinguish white border (~220-240) from
  /// exposed cardstock damage (~250-255).
  static const double whiteningBrightnessThreshold = 245.0;

  /// Saturation threshold for detecting white cardstock pixels (0-255).
  /// White cardstock has very low saturation (< 10).
  static const double whiteningSaturationThreshold = 10.0;

  /// Percentage of the corner ROI to analyze (from the tip inward).
  /// Only the inner 40% of the corner is checked for whitening.
  /// The outer area is white border (normal design).
  static const double cornerTipFraction = 0.4;

  /// Percentage of whitened pixels that triggers a fail.
  /// BGS standard: >2% whitening = detectable under 400x magnification.
  static const double whiteningFailThreshold = 2.0;

  /// Percentage of whitened pixels for perfect score.
  static const double whiteningPerfectThreshold = 0.5;

  /// Luminance coefficient for Red channel (ITU-R BT.709).
  static const double luminanceR = 0.2126;

  /// Luminance coefficient for Green channel (ITU-R BT.709).
  static const double luminanceG = 0.7152;

  /// Luminance coefficient for Blue channel (ITU-R BT.709).
  static const double luminanceB = 0.0722;

  /// Maximum grade value.
  static const double maxGrade = 10.0;

  /// Minimum grade value.
  static const double minGrade = 1.0;

  /// Grade range (max - min).
  static const double gradeRange = maxGrade - minGrade;

  /// Analyzes a single corner ROI for whitening defects.
  ///
  /// Only the extreme tip of the corner is analyzed. The white border
  /// of the card is normal and should not be counted as whitening.
  ///
  /// [cornerImage] is the cropped corner region.
  /// [position] identifies which corner (e.g., "top_left").
  ///
  /// Returns a [CornerWhiteningResult] with the analysis.
  static CornerWhiteningResult analyzeCorner(
    img.Image cornerImage, {
    required String position,
  }) {
    // Check if this corner is predominantly white (white-bordered card)
    // If so, skip whitening detection and give a clean score
    if (_isWhiteBorderCorner(cornerImage)) {
      return CornerWhiteningResult(
        position: position,
        whiteningScore: 0.0,
        whiteningPercentage: 0.0,
        passes: true,
      );
    }

    // Extract the corner tip region (triangular area at the tip)
    final tipRegion = _extractCornerTip(cornerImage, position);

    int whitenedPixels = 0;
    final totalPixels = tipRegion.length;

    for (final pixel in tipRegion) {
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
      // This indicates exposed white cardstock (damage), not white border
      if (brightness > whiteningBrightnessThreshold &&
          saturation < whiteningSaturationThreshold) {
        whitenedPixels++;
      }
    }

    final whiteningPercentage = totalPixels > 0
        ? (whitenedPixels / totalPixels) * 100
        : 0.0;

    // Calculate score: 0.0 = perfect, 1.0 = severe
    double whiteningScore;
    if (whiteningPercentage <= whiteningPerfectThreshold) {
      whiteningScore = 0.0;
    } else if (whiteningPercentage >= whiteningFailThreshold) {
      whiteningScore = 1.0;
    } else {
      whiteningScore = (whiteningPercentage - whiteningPerfectThreshold) /
          (whiteningFailThreshold - whiteningPerfectThreshold);
    }

    final passes = whiteningPercentage < whiteningFailThreshold;

    return CornerWhiteningResult(
      position: position,
      whiteningScore: whiteningScore,
      whiteningPercentage: whiteningPercentage,
      passes: passes,
    );
  }

  /// Checks if a corner ROI is predominantly white (white-bordered card).
  /// If >70% of pixels have brightness >200, it's a white border.
  static bool _isWhiteBorderCorner(img.Image cornerImage) {
    int brightCount = 0;
    final total = cornerImage.width * cornerImage.height;
    final sampleStep = max(1, total ~/ 1000); // Sample ~1000 pixels

    int idx = 0;
    for (int y = 0; y < cornerImage.height; y++) {
      for (int x = 0; x < cornerImage.width; x++) {
        idx++;
        if (idx % sampleStep != 0) continue;

        final pixel = cornerImage.getPixel(x, y);
        final brightness = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        if (brightness > 200) brightCount++;
      }
    }

    final sampledCount = total ~/ sampleStep;
    return sampledCount > 0 && (brightCount / sampledCount) > 0.7;
  }

  /// Extracts the corner tip pixels based on corner position.
  ///
  /// Returns a list of pixels in the triangular tip region.
  static List<img.Pixel> _extractCornerTip(
    img.Image corner,
    String position,
  ) {
    final pixels = <img.Pixel>[];
    final size = corner.width;
    final tipSize = (size * cornerTipFraction).round();

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        // Check if this pixel is within the corner tip triangle
        if (_isInCornerTip(x, y, size, tipSize, position)) {
          pixels.add(corner.getPixel(x, y));
        }
      }
    }

    return pixels;
  }

  /// Checks if a pixel is within the corner tip triangle.
  ///
  /// The tip is a right triangle at the extreme corner of the ROI.
  static bool _isInCornerTip(
    int x,
    int y,
    int size,
    int tipSize,
    String position,
  ) {
    switch (position) {
      case 'top_left':
        // Tip is at (0,0), triangle extends to (tipSize, tipSize)
        return x + y <= tipSize;
      case 'top_right':
        // Tip is at (size-1, 0), triangle extends left and down
        return (size - 1 - x) + y <= tipSize;
      case 'bottom_left':
        // Tip is at (0, size-1), triangle extends right and up
        return x + (size - 1 - y) <= tipSize;
      case 'bottom_right':
        // Tip is at (size-1, size-1), triangle extends left and up
        return (size - 1 - x) + (size - 1 - y) <= tipSize;
      default:
        return false;
    }
  }

  /// Analyzes all four corner ROIs and produces a combined grade.
  ///
  /// [cornerImages] should contain four entries with keys:
  /// "top_left", "top_right", "bottom_left", "bottom_right".
  ///
  /// Returns a [CornerGradingResult] with individual and combined scores.
  static CornerGradingResult analyzeAllCorners(Map<String, img.Image> cornerImages) {
    final results = <CornerWhiteningResult>[];

    for (final entry in cornerImages.entries) {
      results.add(analyzeCorner(entry.value, position: entry.key));
    }

    // Calculate average whitening score
    final averageWhitening = results
            .map((r) => r.whiteningScore)
            .reduce((a, b) => a + b) /
        results.length;

    // Calculate grade: 0.0 whitening = maxGrade, 1.0 whitening = minGrade
    final grade = minGrade + (1.0 - averageWhitening) * gradeRange;

    final passedCount = results.where((r) => r.passes).length;

    return CornerGradingResult(
      corners: results,
      grade: grade,
      averageWhitening: averageWhitening,
      passedCount: passedCount,
    );
  }
}
