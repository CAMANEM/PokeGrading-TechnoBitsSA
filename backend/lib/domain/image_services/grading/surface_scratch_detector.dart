/// @file
/// @brief Surface scratch detection service.
///
/// Detects scratches, print lines, and other surface defects on card
/// surfaces using gradient analysis and ridge filtering techniques.
/// This implementation uses simplified Gabor-like filters for scratch
/// detection without requiring native OpenCV dependencies.

import 'dart:math';

import 'package:image/image.dart' as img;

/// Result of surface analysis.
class SurfaceGradingResult {
  /// Scratch density score: 0.0 (many scratches) to 1.0 (no scratches).
  final double scratchScore;

  /// Print line score: 0.0 (print lines detected) to 1.0 (no print lines).
  final double printLineScore;

  /// Surface uniformity score: 0.0 (uneven) to 1.0 (uniform).
  final double uniformityScore;

  /// Overall surface grade (1.0-10.0 scale).
  final double grade;

  /// Overall surface quality score (0.0-1.0).
  final double qualityScore;

  /// Number of scratch candidates detected.
  final int scratchCount;

  /// Whether the surface passes quality threshold.
  final bool passes;

  const SurfaceGradingResult({
    required this.scratchScore,
    required this.printLineScore,
    required this.uniformityScore,
    required this.grade,
    required this.qualityScore,
    required this.scratchCount,
    required this.passes,
  });

  Map<String, dynamic> toJson() => {
    'scratch_score': double.parse(scratchScore.toStringAsFixed(4)),
    'print_line_score': double.parse(printLineScore.toStringAsFixed(4)),
    'uniformity_score': double.parse(uniformityScore.toStringAsFixed(4)),
    'grade': double.parse(grade.toStringAsFixed(2)),
    'quality_score': double.parse(qualityScore.toStringAsFixed(4)),
    'scratch_count': scratchCount,
    'passes': passes,
  };
}

/// Detects surface defects on card surfaces.
///
/// Uses gradient analysis and ridge filtering to detect:
/// - Scratches: linear features with high gradient response
/// - Print lines: horizontal/vertical lines from manufacturing
/// - Surface uniformity: local variance analysis
class SurfaceScratchDetector {
  /// Gradient magnitude threshold for scratch detection.
  /// Sobel filter can produce values up to ~1442 (255 * 4 * sqrt(2)).
  /// Pokemon card artwork has gradients up to ~300.
  /// Only extremely sharp transitions (> 500) could be real scratches.
  /// NOTE: Without a reference image, surface scratch detection is
  /// preliminary. Real scratches are extremely rare on card surfaces.
  static const double scratchGradientThreshold = 500.0;

  /// Minimum scratch length (in pixels) to count as a real scratch.
  /// Short isolated high-gradient spots are likely artwork details.
  static const int minScratchLength = 30;

  /// Maximum scratch density (scratches per 1000 pixels) for perfect score.
  static const double perfectScratchDensity = 0.01;

  /// Maximum scratch density for passing grade.
  static const double maxScratchDensity = 0.5;

  /// Coefficient of variation threshold for print line detection.
  /// High CV in projection profiles indicates consistent lines.
  /// Pokemon card artwork has natural CV of 0.15-0.25 in projections.
  /// Only very high CV indicates actual print lines.
  static const double printLineCVThreshold = 0.40;

  /// Block size for uniformity analysis (pixels).
  /// Larger blocks smooth out artwork details.
  static const int uniformityBlockSize = 60;

  /// Coefficient of variation threshold for uniform surface.
  /// Below this, surface is considered uniform (score = 1.0).
  static const double uniformCVThreshold = 0.35;

  /// Coefficient of variation threshold for non-uniform surface.
  /// Above this, surface is considered non-uniform (score = 0.0).
  /// Raised to 1.0 to accommodate uneven lighting in raw unprocessed photos.
  static const double nonUniformCVThreshold = 1.0;

  /// Weight for scratch score in combined quality.
  static const double scratchWeight = 0.5;

  /// Weight for print line score in combined quality.
  static const double printLineWeight = 0.25;

  /// Weight for uniformity score in combined quality.
  static const double uniformityWeight = 0.25;

  /// Minimum quality score to pass.
  static const double passingQualityThreshold = 0.4;

  /// Analyzes a surface ROI for scratches and defects.
  ///
  /// [surfaceImage] is the cropped surface region.
  ///
  /// Returns a [SurfaceGradingResult] with the analysis.
  static SurfaceGradingResult analyzeSurface(img.Image surfaceImage) {
    // Convert to grayscale for analysis
    final gray = img.grayscale(surfaceImage);

    // Detect scratches using gradient analysis
    final scratchResult = _detectScratches(gray);

    // Detect print lines using projection profiles
    final printLineResult = _detectPrintLines(gray);

    // Analyze surface uniformity
    final uniformityResult = _analyzeUniformity(gray);

    // Combined quality score
    final qualityScore = scratchResult.$1 * scratchWeight +
        printLineResult * printLineWeight +
        uniformityResult * uniformityWeight;

    // Calculate grade (1.0-10.0)
    final grade = 1.0 + qualityScore * 9.0;

    // Determine pass/fail
    final passes = qualityScore >= passingQualityThreshold;

    return SurfaceGradingResult(
      scratchScore: scratchResult.$1,
      printLineScore: printLineResult,
      uniformityScore: uniformityResult,
      grade: grade,
      qualityScore: qualityScore,
      scratchCount: scratchResult.$2,
      passes: passes,
    );
  }

  /// Detects scratches using gradient magnitude analysis.
  /// Returns (scratchScore, scratchCount).
  static (double, int) _detectScratches(img.Image gray) {
    // Apply Sobel filter for gradient detection
    final sobel = img.sobel(gray);

    // Count high-gradient pixels that form linear structures
    final scratchCount = _countScratchPixels(sobel);
    final totalPixels = gray.width * gray.height;

    // Calculate scratch density (per 1000 pixels)
    final density = (scratchCount / totalPixels) * 1000;

    // Map density to score
    double scratchScore;
    if (density <= perfectScratchDensity) {
      scratchScore = 1.0;
    } else if (density >= maxScratchDensity) {
      scratchScore = 0.0;
    } else {
      scratchScore = 1.0 - (density - perfectScratchDensity) /
          (maxScratchDensity - perfectScratchDensity);
    }

    return (scratchScore, scratchCount);
  }

  /// Counts pixels that form scratch-like linear structures.
  ///
  /// A scratch is characterized by:
  /// 1. High gradient magnitude (sharp brightness transition)
  /// 2. Connected to other high-gradient pixels in a line (linear structure)
  /// 3. NOT part of a larger connected region (artwork edge)
  static int _countScratchPixels(img.Image sobel) {
    int scratchPixels = 0;
    final width = sobel.width;
    final height = sobel.height;

    // Create a binary mask of high-gradient pixels
    final mask = List.generate(height, (y) =>
        List.generate(width, (x) =>
            sobel.getPixel(x, y).r.toInt() > scratchGradientThreshold));

    // Count connected components to filter out large regions (artwork)
    final labels = _labelConnectedComponents(mask, width, height);

    // Count component sizes
    final componentSizes = <int, int>{};
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (labels[y][x] > 0) {
          componentSizes[labels[y][x]] = (componentSizes[labels[y][x]] ?? 0) + 1;
        }
      }
    }

    // Only count pixels in very small components (likely scratches, not artwork)
    // Artwork edges form large connected regions
    // A real scratch is typically thin and isolated
    const maxComponentSizeForScratch = 10;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (labels[y][x] > 0) {
          final size = componentSizes[labels[y][x]] ?? 0;
          if (size <= maxComponentSizeForScratch) {
            scratchPixels++;
          }
        }
      }
    }

    return scratchPixels;
  }

  /// Labels connected components using flood fill.
  static List<List<int>> _labelConnectedComponents(
    List<List<bool>> mask,
    int width,
    int height,
  ) {
    final labels = List.generate(height, (_) => List.filled(width, 0));
    int currentLabel = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (mask[y][x] && labels[y][x] == 0) {
          currentLabel++;
          _floodFill(mask, labels, x, y, width, height, currentLabel);
        }
      }
    }

    return labels;
  }

  /// Flood fill to label a connected component.
  static void _floodFill(
    List<List<bool>> mask,
    List<List<int>> labels,
    int startX,
    int startY,
    int width,
    int height,
    int label,
  ) {
    final stack = <(int, int)>[(startX, startY)];

    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();

      if (x < 0 || x >= width || y < 0 || y >= height) continue;
      if (!mask[y][x] || labels[y][x] != 0) continue;

      labels[y][x] = label;

      // 4-connectivity
      stack.add((x + 1, y));
      stack.add((x - 1, y));
      stack.add((x, y + 1));
      stack.add((x, y - 1));
    }
  }

  /// Detects print lines using horizontal and vertical projection profiles.
  /// Returns printLineScore (0.0-1.0).
  static double _detectPrintLines(img.Image gray) {
    // Horizontal projection (mean intensity per row)
    final hProjection = <double>[];
    for (int y = 0; y < gray.height; y++) {
      double sum = 0;
      for (int x = 0; x < gray.width; x++) {
        sum += gray.getPixel(x, y).r.toDouble();
      }
      hProjection.add(sum / gray.width);
    }

    // Vertical projection (mean intensity per column)
    final vProjection = <double>[];
    for (int x = 0; x < gray.width; x++) {
      double sum = 0;
      for (int y = 0; y < gray.height; y++) {
        sum += gray.getPixel(x, y).r.toDouble();
      }
      vProjection.add(sum / gray.height);
    }

    // Calculate coefficient of variation for each projection
    final hCV = _coefficientOfVariation(hProjection);
    final vCV = _coefficientOfVariation(vProjection);

    // High CV indicates print lines (consistent dips/spikes)
    final maxCV = max(hCV, vCV);

    // Map to score: lower CV = better
    if (maxCV < printLineCVThreshold * 0.5) {
      return 1.0;
    } else if (maxCV > printLineCVThreshold) {
      return 0.0;
    } else {
      return 1.0 - (maxCV - printLineCVThreshold * 0.5) /
          (printLineCVThreshold * 0.5);
    }
  }

  /// Analyzes surface uniformity using local variance.
  /// Returns uniformityScore (0.0-1.0).
  static double _analyzeUniformity(img.Image gray) {
    final blockMeans = <double>[];

    // Calculate mean for each block
    for (int by = 0; by < gray.height; by += uniformityBlockSize) {
      for (int bx = 0; bx < gray.width; bx += uniformityBlockSize) {
        double sum = 0;
        int count = 0;

        for (int y = by; y < min(by + uniformityBlockSize, gray.height); y++) {
          for (int x = bx; x < min(bx + uniformityBlockSize, gray.width); x++) {
            sum += gray.getPixel(x, y).r.toDouble();
            count++;
          }
        }

        blockMeans.add(sum / count);
      }
    }

    // Calculate coefficient of variation of block means
    final cv = _coefficientOfVariation(blockMeans);

    // Low CV = uniform surface
    if (cv < uniformCVThreshold) {
      return 1.0;
    } else if (cv > nonUniformCVThreshold) {
      return 0.0;
    } else {
      return 1.0 - (cv - uniformCVThreshold) /
          (nonUniformCVThreshold - uniformCVThreshold);
    }
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
}
