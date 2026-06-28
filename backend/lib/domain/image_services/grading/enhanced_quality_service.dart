/// @file
/// @brief Enhanced Image Quality Service with Tenengrad and Entropy metrics.
///
/// Extends the basic IQS with additional metrics for more comprehensive
/// image quality assessment:
/// - Tenengrad: Sobel-based sharpness (complementary to Laplacian)
/// - Entropy: Information content measure
/// - Contrast: RMS contrast measure

import 'dart:math';

import 'package:image/image.dart' as img;

/// Enhanced image quality result with additional metrics.
class EnhancedQualityResult {
  /// Overall quality score (0-100).
  final double score;

  /// Laplacian-based sharpness score (0-1).
  final double laplacianSharpness;

  /// Tenengrad (Sobel) sharpness score (0-1).
  final double tenengradSharpness;

  /// Brightness score (0-1).
  final double brightnessScore;

  /// Entropy score (0-1).
  final double entropyScore;

  /// Contrast score (0-1).
  final double contrastScore;

  /// Whether the image passes quality threshold.
  final bool passes;

  /// Rejection reasons if any.
  final List<String> rejectionReasons;

  const EnhancedQualityResult({
    required this.score,
    required this.laplacianSharpness,
    required this.tenengradSharpness,
    required this.brightnessScore,
    required this.entropyScore,
    required this.contrastScore,
    required this.passes,
    required this.rejectionReasons,
  });

  Map<String, dynamic> toJson() => {
    'score': double.parse(score.toStringAsFixed(2)),
    'laplacian_sharpness': double.parse(laplacianSharpness.toStringAsFixed(4)),
    'tenengrad_sharpness': double.parse(tenengradSharpness.toStringAsFixed(4)),
    'brightness': double.parse(brightnessScore.toStringAsFixed(4)),
    'entropy': double.parse(entropyScore.toStringAsFixed(4)),
    'contrast': double.parse(contrastScore.toStringAsFixed(4)),
    'passes': passes,
    'rejection_reasons': rejectionReasons,
  };
}

/// Enhanced Image Quality Service with additional metrics.
class EnhancedQualityService {
  /// Acceptance threshold (0-100). Images below this are rejected.
  static const int acceptedThreshold = 50;

  /// Luminance coefficient for Red channel (ITU-R BT.709).
  static const double luminanceR = 0.2126;

  /// Luminance coefficient for Green channel (ITU-R BT.709).
  static const double luminanceG = 0.7152;

  /// Luminance coefficient for Blue channel (ITU-R BT.709).
  static const double luminanceB = 0.0722;

  /// Maximum pixel value for 8-bit images.
  static const double maxPixelValue = 255.0;

  /// --- Laplacian Sharpness Constants ---

  /// Variance threshold for perfect sharpness score.
  static const double laplacianPerfectVariance = 150.0;

  /// --- Tenengrad Sharpness Constants ---

  /// Average gradient magnitude squared for perfect sharpness.
  static const double tenengradPerfectMagnitude = 500.0;

  /// --- Brightness Constants ---

  /// Minimum acceptable brightness (ITU-R BT.709 luminance).
  static const double brightnessMinAcceptance = 80.0;

  /// Maximum acceptable brightness.
  static const double brightnessMaxAcceptance = 180.0;

  /// --- Entropy Constants ---

  /// Maximum entropy for perfect score (8-bit image max is 8.0).
  static const double entropyPerfectValue = 7.0;

  /// Minimum entropy for zero score (very low information).
  static const double entropyMinValue = 3.0;

  /// --- Contrast Constants ---

  /// Lower bound of ideal RMS contrast range.
  static const double contrastIdealLower = 0.2;

  /// Upper bound of ideal RMS contrast range.
  static const double contrastIdealUpper = 0.6;

  /// RMS contrast below this is considered low contrast.
  static const double contrastLowThreshold = 0.1;

  /// RMS contrast above this is considered high contrast.
  static const double contrastHighThreshold = 0.8;

  /// --- Score Weight Constants ---

  /// Weight for Laplacian in combined sharpness.
  static const double laplacianSharpnessWeight = 0.6;

  /// Weight for Tenengrad in combined sharpness.
  static const double tenengradSharpnessWeight = 0.4;

  /// Weight for sharpness in overall quality.
  static const double sharpnessOverallWeight = 0.35;

  /// Weight for brightness in overall quality.
  static const double brightnessOverallWeight = 0.25;

  /// Weight for entropy in overall quality.
  static const double entropyOverallWeight = 0.20;

  /// Weight for contrast in overall quality.
  static const double contrastOverallWeight = 0.20;

  /// Scale factor to convert 0-1 score to 0-100.
  static const double scoreScaleFactor = 100.0;

  /// Histogram bins for 8-bit images.
  static const int histogramBins = 256;

  /// Calculates enhanced quality metrics for an image.
  ///
  /// [image] is the input image to analyze.
  ///
  /// Returns an [EnhancedQualityResult] with comprehensive metrics.
  static EnhancedQualityResult calculateEnhancedQuality(img.Image image) {
    final gray = img.grayscale(image);

    // Calculate all metrics
    final laplacian = _calculateLaplacianSharpness(gray);
    final tenengrad = _calculateTenengradSharpness(gray);
    final brightness = _calculateBrightnessScore(image);
    final entropy = _calculateEntropyScore(gray);
    final contrast = _calculateContrastScore(gray);

    // Combined sharpness
    final sharpness = laplacian * laplacianSharpnessWeight +
        tenengrad * tenengradSharpnessWeight;

    // Overall score (weighted average)
    final overall = (sharpness * sharpnessOverallWeight +
            brightness * brightnessOverallWeight +
            entropy * entropyOverallWeight +
            contrast * contrastOverallWeight) *
        scoreScaleFactor;

    // Check rejection criteria
    final rejectionReasons = <String>[];
    final sharpness100 = sharpness * scoreScaleFactor;
    final brightness100 = brightness * scoreScaleFactor;

    if (sharpness100 < acceptedThreshold) {
      rejectionReasons.add(
        'Imagen borrosa (Nitidez: ${sharpness100.toStringAsFixed(1)}/100)',
      );
    }

    if (brightness100 < acceptedThreshold) {
      rejectionReasons.add(
        'Imagen oscura (Brillo: ${brightness100.toStringAsFixed(1)}/100)',
      );
    }

    return EnhancedQualityResult(
      score: overall,
      laplacianSharpness: laplacian,
      tenengradSharpness: tenengrad,
      brightnessScore: brightness,
      entropyScore: entropy,
      contrastScore: contrast,
      passes: rejectionReasons.isEmpty,
      rejectionReasons: rejectionReasons,
    );
  }

  /// Calculates Laplacian-based sharpness score.
  static double _calculateLaplacianSharpness(img.Image gray) {
    final laplacian = img.convolution(
      gray,
      filter: [0, -1, 0, -1, 4, -1, 0, -1, 0],
    );

    double sum = 0;
    double sumSq = 0;

    for (final pixel in laplacian) {
      final value = pixel.r.toDouble();
      sum += value;
      sumSq += value * value;
    }

    final n = laplacian.width * laplacian.height;
    final mean = sum / n;
    final variance = (sumSq / n) - (mean * mean);

    if (variance >= laplacianPerfectVariance) return 1.0;
    return (variance / laplacianPerfectVariance).clamp(0, 1);
  }

  /// Calculates Tenengrad (Sobel) sharpness score.
  static double _calculateTenengradSharpness(img.Image gray) {
    // Apply Sobel in X and Y directions
    final sobelX = img.convolution(
      gray,
      filter: [-1, 0, 1, -2, 0, 2, -1, 0, 1],
    );

    final sobelY = img.convolution(
      gray,
      filter: [-1, -2, -1, 0, 0, 0, 1, 2, 1],
    );

    double sumSquaredMagnitude = 0;
    final n = sobelX.width * sobelX.height;

    for (int i = 0; i < n; i++) {
      final gx = sobelX.getPixel(i % sobelX.width, i ~/ sobelX.width).r.toDouble();
      final gy = sobelY.getPixel(i % sobelY.width, i ~/ sobelY.width).r.toDouble();
      sumSquaredMagnitude += gx * gx + gy * gy;
    }

    // Average gradient magnitude squared
    final avgMagnitude = sumSquaredMagnitude / n;

    if (avgMagnitude >= tenengradPerfectMagnitude) return 1.0;
    return (avgMagnitude / tenengradPerfectMagnitude).clamp(0, 1);
  }

  /// Calculates brightness score using ITU-R BT.709 luminance.
  static double _calculateBrightnessScore(img.Image image) {
    double total = 0;

    for (final pixel in image) {
      total += luminanceR * pixel.r + luminanceG * pixel.g + luminanceB * pixel.b;
    }

    final brightness = total / (image.width * image.height);

    if (brightness >= brightnessMinAcceptance && brightness <= brightnessMaxAcceptance) {
      return 1.0;
    }

    if (brightness < brightnessMinAcceptance) {
      return (brightness / brightnessMinAcceptance).clamp(0, 1);
    }

    return (1 - (brightness - brightnessMaxAcceptance) /
        (maxPixelValue - brightnessMaxAcceptance)).clamp(0, 1);
  }

  /// Calculates entropy score (information content).
  static double _calculateEntropyScore(img.Image gray) {
    // Build histogram
    final histogram = List<int>.filled(histogramBins, 0);
    final totalPixels = gray.width * gray.height;

    for (final pixel in gray) {
      final value = pixel.r.toInt();
      histogram[value]++;
    }

    // Calculate entropy: H = -sum(p * log2(p))
    double entropy = 0;
    for (final count in histogram) {
      if (count > 0) {
        final probability = count / totalPixels;
        entropy -= probability * (log(probability) / ln2);
      }
    }

    // Normalize: map entropy range to 0-1
    if (entropy >= entropyPerfectValue) return 1.0;
    if (entropy <= entropyMinValue) return 0.0;
    return ((entropy - entropyMinValue) / (entropyPerfectValue - entropyMinValue))
        .clamp(0, 1);
  }

  /// Calculates RMS contrast score.
  static double _calculateContrastScore(img.Image gray) {
    double sum = 0;
    double sumSq = 0;
    final n = gray.width * gray.height;

    for (final pixel in gray) {
      final value = pixel.r.toDouble();
      sum += value;
      sumSq += value * value;
    }

    final mean = sum / n;
    final variance = (sumSq / n) - (mean * mean);
    final stdDev = sqrt(variance.abs());

    // RMS contrast = stdDev / mean
    final rmsContrast = mean > 0 ? stdDev / mean : 0;

    // Good contrast: within ideal range
    if (rmsContrast >= contrastIdealLower && rmsContrast <= contrastIdealUpper) {
      return 1.0;
    }

    // Low contrast
    if (rmsContrast < contrastLowThreshold) {
      return (rmsContrast / contrastLowThreshold * 0.5).clamp(0.0, 1.0);
    }

    // High contrast
    if (rmsContrast > contrastHighThreshold) {
      return ((1.0 - (rmsContrast - contrastHighThreshold) /
          (maxPixelValue / 255 - contrastHighThreshold)) * 0.5).clamp(0.0, 1.0);
    }

    // Moderate contrast (between low threshold and ideal lower,
    // or between ideal upper and high threshold)
    return 0.75;
  }
}
