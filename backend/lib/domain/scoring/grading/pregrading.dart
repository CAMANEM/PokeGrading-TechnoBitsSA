import 'dart:math';

import '../../image_services/preprocessing/roi_segmenter.dart';
import 'package:image/image.dart' as img;

/// Centering grade calculation using border detection.
///
/// Analyzes the symmetry of card borders by scanning for the transition
/// from uniform white border to varied artwork using local color variance.
class Grading {
  /// Minimum local color variance to consider a column/row as artwork.
  /// White borders have very low variance (uniform color).
  /// Artwork has high variance (many colors/textures).
  static const double artworkVarianceThreshold = 300.0;

  /// Minimum percentage of pixels in a column/row that must show artwork variance
  /// to confirm the artwork has started.
  static const double artworkConsensusThreshold = 0.2;

  /// Maximum number of columns/rows to scan inward from the ROI edge.
  /// This limits how far into the artwork we look for the border.
  static const int maxScanDepth = 150;

  /// Minimum grade value.
  static const double minGrade = 1.0;

  /// Maximum grade value.
  static const double maxGrade = 10.0;

  /// Grade range (max - min).
  static const double gradeRange = maxGrade - minGrade;

  /// Finds the left border position by scanning from left to right.
  ///
  /// Detects where the uniform white border transitions to varied artwork
  /// by checking local color variance. White borders have low variance,
  /// artwork has high variance.
  /// Returns the x-coordinate where the artwork starts.
  static int findLeftBorder(img.Image image) {
    final scanLimit = min(maxScanDepth, image.width ~/ 2);
    for (int x = 0; x < scanLimit; x++) {
      int artworkPixels = 0;
      for (int y = 0; y < image.height; y++) {
        final variance = _localVariance(image, x, y);
        if (variance > artworkVarianceThreshold) {
          artworkPixels++;
        }
      }

      // If enough pixels show artwork variance, this column is artwork
      if (artworkPixels > image.height * artworkConsensusThreshold) {
        return x;
      }
    }

    return 0;
  }

  /// Finds the right border position by scanning from right to left.
  ///
  /// Detects where the uniform white border transitions to varied artwork.
  /// Returns the x-coordinate where the artwork starts (from the right).
  static int findRightBorder(img.Image image) {
    final scanLimit = min(maxScanDepth, image.width ~/ 2);
    for (int x = image.width - 1; x >= image.width - scanLimit; x--) {
      int artworkPixels = 0;
      for (int y = 0; y < image.height; y++) {
        final variance = _localVariance(image, x, y);
        if (variance > artworkVarianceThreshold) {
          artworkPixels++;
        }
      }

      if (artworkPixels > image.height * artworkConsensusThreshold) {
        return x;
      }
    }

    return image.width - 1;
  }

  /// Finds the top border position by scanning from top to bottom.
  ///
  /// Detects where the uniform white border transitions to varied artwork.
  /// Returns the y-coordinate where the artwork starts.
  static int findTopBorder(img.Image image) {
    final scanLimit = min(maxScanDepth, image.height ~/ 2);
    for (int y = 0; y < scanLimit; y++) {
      int artworkPixels = 0;
      for (int x = 0; x < image.width; x++) {
        final variance = _localVariance(image, x, y);
        if (variance > artworkVarianceThreshold) {
          artworkPixels++;
        }
      }

      if (artworkPixels > image.width * artworkConsensusThreshold) {
        return y;
      }
    }

    return 0;
  }

  /// Finds the bottom border position by scanning from bottom to top.
  ///
  /// Detects where the uniform white border transitions to varied artwork.
  /// Returns the y-coordinate where the artwork starts (from the bottom).
  static int findBottomBorder(img.Image image) {
    final scanLimit = min(maxScanDepth, image.height ~/ 2);
    for (int y = image.height - 1; y >= image.height - scanLimit; y--) {
      int artworkPixels = 0;
      for (int x = 0; x < image.width; x++) {
        final variance = _localVariance(image, x, y);
        if (variance > artworkVarianceThreshold) {
          artworkPixels++;
        }
      }

      if (artworkPixels > image.width * artworkConsensusThreshold) {
        return y;
      }
    }

    return image.height - 1;
  }

  /// Calculates local color variance in a 5x5 neighborhood.
  /// White borders have low variance (uniform), artwork has high variance.
  static double _localVariance(img.Image image, int cx, int cy) {
    final brightnesses = <double>[];
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final nx = (cx + dx).clamp(0, image.width - 1);
        final ny = (cy + dy).clamp(0, image.height - 1);
        final pixel = image.getPixel(nx, ny);
        final b = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        brightnesses.add(b);
      }
    }

    final mean = brightnesses.reduce((a, b) => a + b) / brightnesses.length;
    final sumSqDev = brightnesses.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    return sumSqDev / brightnesses.length;
  }

  /// Calculates centering grade based on border symmetry.
  ///
  /// [centerImage] is the centering ROI from the card.
  /// Detects artwork boundaries using brightness thresholding for white borders.
  ///
  /// Returns a grade from 1.0 (very off-center) to 10.0 (perfectly centered).
  static double centerGrade(img.Image centerImage) {
    // Find artwork boundaries (where white border ends and artwork starts)
    final leftBorder = findLeftBorder(centerImage);
    final rightBorder = findRightBorder(centerImage);
    final topBorder = findTopBorder(centerImage);
    final bottomBorder = findBottomBorder(centerImage);

    // Calculate border widths (distance from ROI edge to artwork)
    final leftMargin = leftBorder;
    final rightMargin = centerImage.width - rightBorder - 1;
    final topMargin = topBorder;
    final bottomMargin = centerImage.height - bottomBorder - 1;

    final maxH = max(leftMargin, rightMargin);
    final maxV = max(topMargin, bottomMargin);

    // Horizontal symmetry ratio (0.0 = asymmetric, 1.0 = symmetric)
    double horizontal = maxH > 0 ? min(leftMargin, rightMargin) / maxH : 0.0;

    // Vertical symmetry ratio (0.0 = asymmetric, 1.0 = symmetric)
    double vertical = maxV > 0 ? min(topMargin, bottomMargin) / maxV : 0.0;

    // Average symmetry
    final symmetryScore = (horizontal + vertical) / 2.0;

    // Map to grade scale: 0.0 symmetry = minGrade, 1.0 symmetry = maxGrade
    return (minGrade + symmetryScore * gradeRange).clamp(minGrade, maxGrade);
  }

  /// Calculates sub-grades for all grading categories.
  ///
  /// [roi] contains all extracted regions from the card.
  ///
  /// Returns the centering grade.
  static double subgrades(RoiResult roi) {
    return centerGrade(roi.centering);
  }
}
