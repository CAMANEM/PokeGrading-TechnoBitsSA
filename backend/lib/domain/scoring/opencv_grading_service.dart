import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:dartcv4/dartcv.dart' as cv;

/// OpenCV-based grading service for comparing submitter ROIs against reference.
///
/// Each scoring method returns a grade on a 1.0–10.0 scale where:
/// - 10.0 = identical to reference (perfect)
/// - 1.0  = severely degraded / deviated
class OpenCVGradingService {
  /// Converts a Dart [img.Image] to a cv [cv.Mat] (BGR, 8UC3).
  static cv.Mat imageToMat(img.Image image) {
    final w = image.width;
    final h = image.height;

    final bytes = Uint8List(w * h * 3);
    int idx = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = image.getPixel(x, y);
        bytes[idx++] = pixel.b.toInt();
        bytes[idx++] = pixel.g.toInt();
        bytes[idx++] = pixel.r.toInt();
      }
    }

    final mat = cv.Mat.create(rows: h, cols: w, type: cv.MatType.CV_8UC3);
    mat.data.setAll(0, bytes);
    return mat;
  }

  /// Converts a Dart [img.Image] to grayscale cv [cv.Mat] (8UC1).
  static cv.Mat imageToMatGray(img.Image image) {
    final w = image.width;
    final h = image.height;

    final bytes = Uint8List(w * h);
    int idx = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = image.getPixel(x, y);
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
        bytes[idx++] = gray.toInt().clamp(0, 255);
      }
    }

    final mat = cv.Mat.create(rows: h, cols: w, type: cv.MatType.CV_8UC1);
    mat.data.setAll(0, bytes);
    return mat;
  }

  /// Scores centering by comparing border symmetry of submitter vs reference.
  ///
  /// Uses Canny edge detection to find card borders, then measures
  /// left/right and top/bottom margin ratios. Deviation from reference
  /// reduces the score.
  static double scoreCentering(
    img.Image submitterCentering,
    img.Image referenceCentering,
  ) {
    final subMat = imageToMatGray(submitterCentering);
    final refMat = imageToMatGray(referenceCentering);

    try {
      final subMargins = _measureBorders(subMat);
      final refMargins = _measureBorders(refMat);

      if (subMargins == null || refMargins == null) return 5.0;

      final hDiff = (subMargins.hRatio - refMargins.hRatio).abs();
      final vDiff = (subMargins.vRatio - refMargins.vRatio).abs();
      final avgDiff = (hDiff + vDiff) / 2.0;

      return _diffToScore(avgDiff, maxAcceptable: 0.15);
    } finally {
      subMat.dispose();
      refMat.dispose();
    }
  }

  /// Scores corners by comparing sharpness and whiteness vs reference.
  ///
  /// Uses Laplacian variance (sharpness) and edge density (Canny)
  /// for each corner, then averages across all 4 corners.
  static double scoreCorners(
    List<img.Image> submitterCorners,
    List<img.Image> referenceCorners,
  ) {
    assert(submitterCorners.length == 4 && referenceCorners.length == 4);

    double totalScore = 0;
    for (int i = 0; i < 4; i++) {
      final subMat = imageToMatGray(submitterCorners[i]);
      final refMat = imageToMatGray(referenceCorners[i]);

      try {
        final subSharp = _laplacianVariance(subMat);
        final refSharp = _laplacianVariance(refMat);

        final sharpDiff = (subSharp - refSharp).abs();
        final refNormalised = refSharp == 0 ? 1.0 : refSharp;
        final relativeDiff = sharpDiff / refNormalised;

        totalScore += _diffToScore(relativeDiff, maxAcceptable: 0.40);
      } finally {
        subMat.dispose();
        refMat.dispose();
      }
    }

    return totalScore / 4.0;
  }

  /// Scores edges by comparing edge uniformity and gap detection vs reference.
  ///
  /// Uses Canny edge detection to count edge pixels and detect gaps.
  /// Fewer edge pixels or more gaps relative to reference reduces score.
  static double scoreEdges(
    List<img.Image> submitterEdges,
    List<img.Image> referenceEdges,
  ) {
    assert(submitterEdges.length == 4 && referenceEdges.length == 4);

    double totalScore = 0;
    for (int i = 0; i < 4; i++) {
      final subMat = imageToMatGray(submitterEdges[i]);
      final refMat = imageToMatGray(referenceEdges[i]);

      try {
        final subEdge = cv.canny(subMat, 50, 150);
        final refEdge = cv.canny(refMat, 50, 150);

        final subCount = cv.countNonZero(subEdge);
        final refCount = cv.countNonZero(refEdge);

        subEdge.dispose();
        refEdge.dispose();

        if (refCount == 0) {
          totalScore += 5.0;
          continue;
        }

        final ratio = subCount / refCount;
        final deviation = (1.0 - ratio).abs();
        totalScore += _diffToScore(deviation, maxAcceptable: 0.30);
      } finally {
        subMat.dispose();
        refMat.dispose();
      }
    }

    return totalScore / 4.0;
  }

  /// Scores surface quality by PSNR comparison vs reference.
  ///
  /// Uses Peak Signal-to-Noise Ratio to detect scratches, stains,
  /// or other surface anomalies. Lower PSNR reduces score.
  static double scoreSurface(
    img.Image submitterSurface,
    img.Image referenceSurface,
  ) {
    final subGray = _resizeToMatch(
      imageToMatGray(submitterSurface),
      referenceSurface.width,
      referenceSurface.height,
    );
    final refGray = imageToMatGray(referenceSurface);

    try {
      final psnr = cv.PSNR(subGray, refGray);

      if (psnr.isInfinite || psnr.isNaN) return 5.0;

      if (psnr >= 40) return 10.0;
      if (psnr <= 10) return 1.0;

      return 1.0 + (psnr - 10) * 9.0 / 30.0;
    } finally {
      subGray.dispose();
      refGray.dispose();
    }
  }

  // ── Internal helpers ────────────────────────────────────────

  static cv.Mat _resizeToMatch(cv.Mat mat, int targetW, int targetH) {
    if (mat.width == targetW && mat.height == targetH) return mat;
    final resized = cv.resize(mat, (targetW, targetH));
    mat.dispose();
    return resized;
  }

  static _BorderRatios? _measureBorders(cv.Mat gray) {
    final edge = cv.canny(gray, 50, 150);
    try {
      final h = edge.height;
      final w = edge.width;

      int left = 0;
      for (int x = 0; x < w; x++) {
        int count = 0;
        for (int y = 0; y < h; y++) {
          if (edge.atNum(y, x) > 0) count++;
        }
        if (count > h * 0.3) {
          left = x;
          break;
        }
      }

      int right = w - 1;
      for (int x = w - 1; x >= 0; x--) {
        int count = 0;
        for (int y = 0; y < h; y++) {
          if (edge.atNum(y, x) > 0) count++;
        }
        if (count > h * 0.3) {
          right = x;
          break;
        }
      }

      int top = 0;
      for (int y = 0; y < h; y++) {
        int count = 0;
        for (int x = 0; x < w; x++) {
          if (edge.atNum(y, x) > 0) count++;
        }
        if (count > w * 0.3) {
          top = y;
          break;
        }
      }

      int bottom = h - 1;
      for (int y = h - 1; y >= 0; y--) {
        int count = 0;
        for (int x = 0; x < w; x++) {
          if (edge.atNum(y, x) > 0) count++;
        }
        if (count > w * 0.3) {
          bottom = y;
          break;
        }
      }

      final leftMargin = left;
      final rightMargin = w - right - 1;
      final topMargin = top;
      final bottomMargin = h - bottom - 1;

      final maxLR = max(leftMargin, rightMargin);
      final maxTB = max(topMargin, bottomMargin);

      if (maxLR == 0 || maxTB == 0) return null;

      return _BorderRatios(
        hRatio: min(leftMargin, rightMargin) / maxLR,
        vRatio: min(topMargin, bottomMargin) / maxTB,
      );
    } finally {
      edge.dispose();
    }
  }

  static double _laplacianVariance(cv.Mat gray) {
    final laplacian = cv.laplacian(gray, cv.MatType.CV_64F);
    try {
      final variance = laplacian.variance();
      return (variance.val1 + variance.val2 + variance.val3) / 3.0;
    } finally {
      laplacian.dispose();
    }
  }

  /// Maps a [deviation] (0.0 = identical, 1.0 = maximally different)
  /// to a score in [1.0, 10.0]. [maxAcceptable] is the deviation that
  /// maps to exactly 5.0 (midpoint).
  static double _diffToScore(double deviation, {required double maxAcceptable}) {
    final normalised = (deviation / maxAcceptable).clamp(0.0, 2.0);
    final score = 10.0 - normalised * 4.5;
    return score.clamp(1.0, 10.0);
  }
}

class _BorderRatios {
  final double hRatio;
  final double vRatio;
  const _BorderRatios({required this.hRatio, required this.vRatio});
}
