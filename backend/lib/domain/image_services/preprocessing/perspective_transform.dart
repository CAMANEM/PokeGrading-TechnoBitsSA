/// @file
/// @brief Perspective transformation for card images using pure Dart.
///
/// Applies a perspective warp to align a detected card contour to a standard
/// rectangular output. Uses manual matrix operations and bilinear interpolation.

import 'dart:convert';
import 'package:image/image.dart' as img;

import 'preprocessing_models.dart';

/// Applies perspective correction to align a card to a standard rectangle.
///
/// Takes the original image and the detected corners, computes the
/// perspective transformation matrix, and warps the image to produce
/// a straightened card image.
class PerspectiveTransformer {
  /// Output dimensions for the corrected card image.
  static const int outputWidth = CardDimensions.standardWidth;
  static const int outputHeight = CardDimensions.standardHeight;

  /// Applies perspective correction to the image.
  ///
  /// [image] is the original decoded image.
  /// [corners] are the four detected corners of the card, ordered:
  /// top-left, top-right, bottom-right, bottom-left.
  ///
  /// Returns a [PerspectiveCorrectionResult] with the corrected image
  /// encoded as base64 JPEG.
  static PerspectiveCorrectionResult correct(
    img.Image image,
    List<Point2D> corners,
  ) {
    assert(corners.length == 4, 'Must have exactly 4 corners');

    try {
      // Calculate perspective transformation matrix
      final transformMatrix = _getPerspectiveTransform(
        corners,
        outputWidth,
        outputHeight,
      );

      // Apply perspective warp using bilinear interpolation
      final corrected = _warpPerspective(
        image,
        transformMatrix,
        outputWidth,
        outputHeight,
      );

      // Encode to JPEG
      final jpegBytes = img.encodeJpg(corrected, quality: 95);
      final base64String = base64Encode(jpegBytes);

      // Extract transform matrix as flat list
      final matrixFlat = [
        transformMatrix[0][0],
        transformMatrix[0][1],
        transformMatrix[0][2],
        transformMatrix[1][0],
        transformMatrix[1][1],
        transformMatrix[1][2],
        transformMatrix[2][0],
        transformMatrix[2][1],
        transformMatrix[2][2],
      ];

      return PerspectiveCorrectionResult.success(
        correctedImageData: base64String,
        transformMatrix: matrixFlat,
        originalCorners: corners,
        metadata: PreprocessingMetadata.timed(
          detectionTimeMs: 0,
          correctionTimeMs: 0,
        ),
      );
    } catch (e) {
      return PerspectiveCorrectionResult.failure(
        error: PreprocessingError.processingFailed,
        metadata: PreprocessingMetadata.timed(
          detectionTimeMs: 0,
          correctionTimeMs: 0,
        ),
      );
    }
  }

  /// Calculates the 3x3 perspective transformation matrix.
  ///
  /// Maps source corners to destination rectangle.
  static List<List<double>> _getPerspectiveTransform(
    List<Point2D> src,
    int dstWidth,
    int dstHeight,
  ) {
    // Destination corners (rectangle)
    final dst = [
      [0.0, 0.0],
      [dstWidth.toDouble(), 0.0],
      [dstWidth.toDouble(), dstHeight.toDouble()],
      [0.0, dstHeight.toDouble()],
    ];

    // Solve for perspective transform using DLT (Direct Linear Transform)
    return _computePerspectiveMatrix(src, dst);
  }

  /// Computes the perspective transformation matrix using DLT.
  static List<List<double>> _computePerspectiveMatrix(
    List<Point2D> src,
    List<List<double>> dst,
  ) {
    // Build the 8x8 matrix A and 8x1 vector b for Ah = b
    final a = List.generate(8, (_) => List<double>.filled(8, 0));
    final b = List<double>.filled(8, 0);

    for (var i = 0; i < 4; i++) {
      final sx = src[i].x.toDouble();
      final sy = src[i].y.toDouble();
      final dx = dst[i][0];
      final dy = dst[i][1];

      a[i * 2][0] = sx;
      a[i * 2][1] = sy;
      a[i * 2][2] = 1;
      a[i * 2][6] = -dx * sx;
      a[i * 2][7] = -dx * sy;
      b[i * 2] = dx;

      a[i * 2 + 1][3] = sx;
      a[i * 2 + 1][4] = sy;
      a[i * 2 + 1][5] = 1;
      a[i * 2 + 1][6] = -dy * sx;
      a[i * 2 + 1][7] = -dy * sy;
      b[i * 2 + 1] = dy;
    }

    // Solve using Gaussian elimination
    final h = _solveLinearSystem(a, b);

    // Build 3x3 matrix (h[8] = 1)
    return [
      [h[0], h[1], h[2]],
      [h[3], h[4], h[5]],
      [h[6], h[7], 1.0],
    ];
  }

  /// Solves a linear system Ax = b using Gaussian elimination with pivoting.
  static List<double> _solveLinearSystem(
    List<List<double>> a,
    List<double> b,
  ) {
    final n = b.length;
    final aug = List.generate(n, (i) => [...a[i], b[i]]);

    // Forward elimination with partial pivoting
    for (var col = 0; col < n; col++) {
      // Find pivot
      var maxVal = aug[col][col].abs();
      var maxRow = col;
      for (var row = col + 1; row < n; row++) {
        if (aug[row][col].abs() > maxVal) {
          maxVal = aug[row][col].abs();
          maxRow = row;
        }
      }

      // Swap rows
      final temp = aug[col];
      aug[col] = aug[maxRow];
      aug[maxRow] = temp;

      // Check for singular matrix
      if (aug[col][col].abs() < 1e-10) {
        return List<double>.filled(n, 0);
      }

      // Eliminate below
      for (var row = col + 1; row < n; row++) {
        final factor = aug[row][col] / aug[col][col];
        for (var j = col; j <= n; j++) {
          aug[row][j] -= factor * aug[col][j];
        }
      }
    }

    // Back substitution
    final x = List<double>.filled(n, 0);
    for (var i = n - 1; i >= 0; i--) {
      x[i] = aug[i][n];
      for (var j = i + 1; j < n; j++) {
        x[i] -= aug[i][j] * x[j];
      }
      x[i] /= aug[i][i];
    }

    return x;
  }

  /// Applies perspective warp using bilinear interpolation.
  static img.Image _warpPerspective(
    img.Image src,
    List<List<double>> matrix,
    int dstWidth,
    int dstHeight,
  ) {
    final dst = img.Image(width: dstWidth, height: dstHeight);

    // Calculate inverse matrix for mapping destination to source
    final invMatrix = _invertMatrix(matrix);

    for (var y = 0; y < dstHeight; y++) {
      for (var x = 0; x < dstWidth; x++) {
        // Map destination point to source coordinates
        final srcPoint = _transformPoint(invMatrix, x.toDouble(), y.toDouble());

        final srcX = srcPoint[0];
        final srcY = srcPoint[1];

        // Bilinear interpolation
        if (srcX >= 0 &&
            srcX < src.width - 1 &&
            srcY >= 0 &&
            srcY < src.height - 1) {
          final color = _bilinearInterpolate(src, srcX, srcY);
          dst.setPixel(x, y, img.ColorRgb8(color[0], color[1], color[2]));
        }
      }
    }

    return dst;
  }

  /// Inverts a 3x3 matrix.
  static List<List<double>> _invertMatrix(List<List<double>> m) {
    final det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);

    if (det.abs() < 1e-10) {
      return [
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1],
      ];
    }

    final invDet = 1.0 / det;

    return [
      [
        (m[1][1] * m[2][2] - m[1][2] * m[2][1]) * invDet,
        (m[0][2] * m[2][1] - m[0][1] * m[2][2]) * invDet,
        (m[0][1] * m[1][2] - m[0][2] * m[1][1]) * invDet,
      ],
      [
        (m[1][2] * m[2][0] - m[1][0] * m[2][2]) * invDet,
        (m[0][0] * m[2][2] - m[0][2] * m[2][0]) * invDet,
        (m[0][2] * m[1][0] - m[0][0] * m[1][2]) * invDet,
      ],
      [
        (m[1][0] * m[2][1] - m[1][1] * m[2][0]) * invDet,
        (m[0][1] * m[2][0] - m[0][0] * m[2][1]) * invDet,
        (m[0][0] * m[1][1] - m[0][1] * m[1][0]) * invDet,
      ],
    ];
  }

  /// Transforms a 2D point using a 3x3 matrix.
  static List<double> _transformPoint(
    List<List<double>> matrix,
    double x,
    double y,
  ) {
    final w = matrix[2][0] * x + matrix[2][1] * y + matrix[2][2];
    final outX = (matrix[0][0] * x + matrix[0][1] * y + matrix[0][2]) / w;
    final outY = (matrix[1][0] * x + matrix[1][1] * y + matrix[1][2]) / w;
    return [outX, outY];
  }

  /// Performs bilinear interpolation at (x, y) in the source image.
  static List<int> _bilinearInterpolate(img.Image src, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final wx = x - x0;
    final wy = y - y0;

    final c00 = src.getPixel(x0, y0);
    final c10 = src.getPixel(x1, y0);
    final c01 = src.getPixel(x0, y1);
    final c11 = src.getPixel(x1, y1);

    final r = (c00.r * (1 - wx) * (1 - wy) +
            c10.r * wx * (1 - wy) +
            c01.r * (1 - wx) * wy +
            c11.r * wx * wy)
        .toInt()
        .clamp(0, 255);

    final g = (c00.g * (1 - wx) * (1 - wy) +
            c10.g * wx * (1 - wy) +
            c01.g * (1 - wx) * wy +
            c11.g * wx * wy)
        .toInt()
        .clamp(0, 255);

    final b = (c00.b * (1 - wx) * (1 - wy) +
            c10.b * wx * (1 - wy) +
            c01.b * (1 - wx) * wy +
            c11.b * wx * wy)
        .toInt()
        .clamp(0, 255);

    return [r, g, b];
  }

  /// Validates that the transform matrix is reasonable.
  static bool isValidTransform(List<double> matrix) {
    if (matrix.length != 9) return false;

    for (final value in matrix) {
      if (value.isNaN || value.isInfinite) return false;
    }

    final deviation = _matrixDeviationFromIdentity(matrix);
    return deviation < 5.0;
  }

  /// Calculates how much a matrix deviates from the identity matrix.
  static double _matrixDeviationFromIdentity(List<double> matrix) {
    const identity = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
    var sum = 0.0;
    for (var i = 0; i < 9; i++) {
      sum += (matrix[i] - identity[i]).abs();
    }
    return sum;
  }

}
