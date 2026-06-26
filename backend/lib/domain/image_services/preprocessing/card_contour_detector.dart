/// @file
/// @brief Card contour detection using pure Dart image processing.
///
/// Detects the rectangular contour of a Pokémon card in an image.
/// Uses background-adaptive thresholding, convex hull, and extreme-point
/// extraction to find the card boundaries.

import 'dart:math';
import 'package:image/image.dart' as img;

import 'preprocessing_models.dart';

/// Detects the rectangular contour of a card in an image.
class CardContourDetector {
  static const double minAreaRatio = 0.05;
  static const double maxAreaRatio = 1.0;
  static const double maxAspectRatioDeviation = 0.4;
  static const double minConfidence = 0.3;

  static ContourDetectionResult detect(img.Image image) {
    final totalArea = image.width * image.height;

    final gray = img.grayscale(img.Image.from(image));
    final blurred = img.gaussianBlur(gray, radius: 3);

    // Strategy 1: Background-adaptive threshold
    // Sample border pixels to estimate background brightness,
    // then threshold below that to find the card.
    final bgBrightness = _estimateBackgroundBrightness(blurred);

    for (final margin in [15, 25, 40, 60, 80, 100]) {
      final threshold = bgBrightness.toInt() - margin;
      final binary = _thresholdBelow(blurred, threshold);
      final result = _tryFindCard(binary, totalArea, image.width, image.height);
      if (result != null) return result;
    }

    // Strategy 2: Sobel edge detection
    final edges = img.sobel(blurred);
    for (final thresh in [15, 25, 35, 50]) {
      final binary = _thresholdAbove(edges, thresh);
      final result = _tryFindCard(binary, totalArea, image.width, image.height);
      if (result != null) return result;
    }

    return ContourDetectionResult.failure('No valid rectangular contour found');
  }

  static int _estimateBackgroundBrightness(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final samples = <int>[];

    // Sample pixels along the border and corners
    for (var i = 0; i < w; i++) {
      samples.add(gray.getPixel(i, 0).r.toInt());
      samples.add(gray.getPixel(i, h - 1).r.toInt());
    }
    for (var i = 0; i < h; i++) {
      samples.add(gray.getPixel(0, i).r.toInt());
      samples.add(gray.getPixel(w - 1, i).r.toInt());
    }

    samples.sort();
    return samples[samples.length ~/ 2];
  }

  static img.Image _thresholdBelow(img.Image image, int threshold) {
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 1,
    );
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final value = image.getPixel(x, y).r.toInt();
        result.setPixelRgba(x, y, value < threshold ? 255 : 0, 0, 0, 255);
      }
    }
    return result;
  }

  static img.Image _thresholdAbove(img.Image image, int threshold) {
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 1,
    );
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final value = image.getPixel(x, y).r.toInt();
        result.setPixelRgba(x, y, value > threshold ? 255 : 0, 0, 0, 255);
      }
    }
    return result;
  }

  static ContourDetectionResult? _tryFindCard(
    img.Image binary,
    int totalArea,
    int width,
    int height,
  ) {
    final edgePoints = _collectEdgePixels(binary, width, height);
    if (edgePoints.length < 20) return null;

    final hull = _convexHull(edgePoints);
    if (hull.length < 4) return null;

    final corners = _extractFourCorners(hull);
    return _evaluateCorners(corners, totalArea, width, height);
  }

  static List<Point2D> _collectEdgePixels(
    img.Image binary,
    int width,
    int height,
  ) {
    final points = <Point2D>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (binary.getPixel(x, y).r.toInt() == 0) continue;
        var isBoundary = false;
        for (var dy = -1; dy <= 1 && !isBoundary; dy++) {
          for (var dx = -1; dx <= 1 && !isBoundary; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
              isBoundary = true;
              continue;
            }
            if (binary.getPixel(nx, ny).r.toInt() == 0) {
              isBoundary = true;
            }
          }
        }
        if (isBoundary) points.add(Point2D(x: x, y: y));
      }
    }
    return points;
  }

  /// Extracts exactly 4 corners from a convex hull by finding the points
  /// that minimize/maximize (x+y) and (x-y) - the extreme points.
  static List<Point2D> _extractFourCorners(List<Point2D> hull) {
    if (hull.length == 4) return _orderCorners(hull);

    var topLeft = hull[0];
    var topRight = hull[0];
    var bottomRight = hull[0];
    var bottomLeft = hull[0];

    var minSum = topLeft.x + topLeft.y;
    var maxSum = bottomRight.x + bottomRight.y;
    var minDiff = bottomLeft.x - bottomLeft.y;
    var maxDiff = topRight.x - topRight.y;

    for (final p in hull) {
      final sum = p.x + p.y;
      final diff = p.x - p.y;

      if (sum < minSum) {
        minSum = sum;
        topLeft = p;
      }
      if (sum > maxSum) {
        maxSum = sum;
        bottomRight = p;
      }
      if (diff < minDiff) {
        minDiff = diff;
        bottomLeft = p;
      }
      if (diff > maxDiff) {
        maxDiff = diff;
        topRight = p;
      }
    }

    return _orderCorners([topLeft, topRight, bottomRight, bottomLeft]);
  }

  static ContourDetectionResult _evaluateCorners(
    List<Point2D> corners,
    int totalArea,
    int imageWidth,
    int imageHeight,
  ) {
    final area = _quadrilateralArea(corners);
    final areaRatio = area / totalArea;

    if (areaRatio < minAreaRatio || areaRatio > maxAreaRatio) {
      return ContourDetectionResult.failure(
        'Contour area ratio ${areaRatio.toStringAsFixed(2)} outside range '
        '[$minAreaRatio, $maxAreaRatio]',
      );
    }

    final aspectRatio = _calculateAspectRatio(corners);
    final expectedRatio = CardDimensions.aspectRatio;
    final ratioDeviation = (aspectRatio - expectedRatio).abs() / expectedRatio;

    if (ratioDeviation > maxAspectRatioDeviation) {
      return ContourDetectionResult.failure(
        'Aspect ratio ${aspectRatio.toStringAsFixed(3)} deviates '
        '${(ratioDeviation * 100).toStringAsFixed(1)}% from expected '
        '${expectedRatio.toStringAsFixed(3)}',
      );
    }

    final confidence = _calculateConfidence(
      areaRatio: areaRatio,
      ratioDeviation: ratioDeviation,
    );

    if (confidence < minConfidence) {
      return ContourDetectionResult.failure(
        'Confidence ${confidence.toStringAsFixed(2)} below threshold $minConfidence',
      );
    }

    return ContourDetectionResult.success(
      corners: corners,
      confidence: confidence,
      contourAreaRatio: areaRatio,
    );
  }

  static List<Point2D> _convexHull(List<Point2D> points) {
    if (points.length <= 3) return List.from(points);

    var pivot = points[0];
    for (final p in points) {
      if (p.y < pivot.y || (p.y == pivot.y && p.x < pivot.x)) {
        pivot = p;
      }
    }

    final sorted = List<Point2D>.from(points);
    sorted.sort((a, b) {
      final angleA = atan2(a.y - pivot.y, a.x - pivot.x);
      final angleB = atan2(b.y - pivot.y, b.x - pivot.x);
      if (angleA != angleB) return angleA.compareTo(angleB);
      final distA = _distanceSquared(pivot, a);
      final distB = _distanceSquared(pivot, b);
      return distA.compareTo(distB);
    });

    final hull = <Point2D>[];
    for (final p in sorted) {
      while (hull.length >= 2 &&
          _crossProduct(hull[hull.length - 2], hull[hull.length - 1], p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    return hull;
  }

  static double _crossProduct(Point2D a, Point2D b, Point2D c) {
    return ((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)).toDouble();
  }

  static double _distanceSquared(Point2D a, Point2D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return (dx * dx + dy * dy).toDouble();
  }

  static double _polygonArea(List<Point2D> points) {
    var area = 0.0;
    final n = points.length;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += points[i].x * points[j].y;
      area -= points[j].x * points[i].y;
    }
    return (area.abs() / 2.0);
  }

  static double _quadrilateralArea(List<Point2D> corners) {
    return _polygonArea(corners);
  }

  static List<Point2D> _orderCorners(List<Point2D> corners) {
    assert(corners.length == 4, 'Must have exactly 4 corners');

    final sumList = corners.map((p) => p.x + p.y).toList();
    final diffList = corners.map((p) => p.x - p.y).toList();

    var topLeftIdx = 0;
    var topRightIdx = 0;
    var bottomRightIdx = 0;
    var bottomLeftIdx = 0;

    var minSum = sumList[0];
    var maxSum = sumList[0];
    var minDiff = diffList[0];
    var maxDiff = diffList[0];

    for (var i = 1; i < 4; i++) {
      if (sumList[i] < minSum) {
        minSum = sumList[i];
        topLeftIdx = i;
      }
      if (sumList[i] > maxSum) {
        maxSum = sumList[i];
        bottomRightIdx = i;
      }
      if (diffList[i] < minDiff) {
        minDiff = diffList[i];
        bottomLeftIdx = i;
      }
      if (diffList[i] > maxDiff) {
        maxDiff = diffList[i];
        topRightIdx = i;
      }
    }

    return [
      corners[topLeftIdx],
      corners[topRightIdx],
      corners[bottomRightIdx],
      corners[bottomLeftIdx],
    ];
  }

  static double _calculateAspectRatio(List<Point2D> corners) {
    final side01 = _distance(corners[0], corners[1]);
    final side12 = _distance(corners[1], corners[2]);
    final side23 = _distance(corners[2], corners[3]);
    final side30 = _distance(corners[3], corners[0]);

    final avgHorizontal = (side01 + side23) / 2;
    final avgVertical = (side12 + side30) / 2;

    if (avgVertical == 0) return 0;
    final ratio = avgHorizontal / avgVertical;

    return ratio <= 1.0 ? ratio : 1.0 / ratio;
  }

  static double _distance(Point2D a, Point2D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  static double _calculateConfidence({
    required double areaRatio,
    required double ratioDeviation,
  }) {
    final areaScore = 1.0 - (areaRatio - 0.6).abs() * 2;
    final clampedAreaScore = areaScore.clamp(0.0, 1.0);

    final ratioScore = 1.0 - ratioDeviation;
    final clampedRatioScore = ratioScore.clamp(0.0, 1.0);

    return (clampedAreaScore * 0.5 + clampedRatioScore * 0.5).clamp(0.0, 1.0);
  }
}
