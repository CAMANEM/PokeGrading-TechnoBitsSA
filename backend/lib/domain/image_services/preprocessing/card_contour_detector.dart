/// @file
/// @brief Card contour detection using pure Dart image processing.
///
/// Detects the rectangular contour of a Pokémon card in an image.
/// Uses multiple strategies with automatic fallback to handle diverse
/// capture conditions (dark background, bright background, low contrast,
/// colorful artwork, etc.).

import 'dart:collection';
import 'dart:math';
import 'package:image/image.dart' as img;

import 'preprocessing_models.dart';

/// Detects the rectangular contour of a card in an image.
class CardContourDetector {
  static const double minAreaRatio = 0.05;
  static const double maxAreaRatio = 1.0;
  static const double maxAspectRatioDeviation = 0.4;
  static const double minConfidence = 0.3;

  static const int _maxDimensionForDetection = 2000;

  static ContourDetectionResult detect(img.Image image) {
    final (workingImage, scaleX, scaleY) = _prepareImage(image);
    final totalArea = workingImage.width * workingImage.height;

    final gray = img.grayscale(img.Image.from(workingImage));
    final blurred = img.gaussianBlur(gray, radius: 3);

    // Strategy 1: Background-adaptive threshold (card darker than background)
    final bgBrightness = _estimateBackgroundBrightness(blurred);
    for (final margin in [15, 25, 40, 60, 80, 100]) {
      final threshold = bgBrightness.toInt() - margin;
      final binary = _thresholdBelow(blurred, threshold);
      var result = _tryFindCard(binary, totalArea,
          workingImage.width, workingImage.height);
      if (result != null) return _scaleResult(result, scaleX, scaleY);
    }

    // Strategy 1b: Reverse direction (card brighter than background)
    for (final margin in [15, 25, 40, 60, 80, 100]) {
      final threshold = bgBrightness.toInt() + margin;
      final binary = _thresholdAbove(blurred, threshold);
      var result = _tryFindCard(binary, totalArea,
          workingImage.width, workingImage.height);
      if (result != null) return _scaleResult(result, scaleX, scaleY);
    }

    // Strategy 1c: Otsu automatic threshold (both directions)
    final otsuThreshold = _otsuThreshold(blurred);
    var otsuBinary = _thresholdBelow(blurred, otsuThreshold);
    var result = _tryFindCard(
        otsuBinary, totalArea, workingImage.width, workingImage.height);
    if (result != null) return _scaleResult(result, scaleX, scaleY);

    otsuBinary = _thresholdAbove(blurred, otsuThreshold);
    result = _tryFindCard(
        otsuBinary, totalArea, workingImage.width, workingImage.height);
    if (result != null) return _scaleResult(result, scaleX, scaleY);

    // Strategy 2: Sobel edge detection with dilation linking
    final edges = img.sobel(img.Image.from(blurred));
    for (final thresh in [5, 10, 20, 30, 40]) {
      final binary = _thresholdAbove(edges, thresh);
      final dilated = _dilate(binary, thresh <= 10 ? 5 : 3);
      result = _tryFindCard(
          dilated, totalArea, workingImage.width, workingImage.height);
      if (result != null) return _scaleResult(result, scaleX, scaleY);
    }

    // Strategy 3: HSV saturation thresholding
    // Colorful card artwork stands out against neutral backgrounds.
    // Dilation expands the artwork region to fill the card border area.
    for (final sat in [40, 25, 15]) {
      final satBinary = _thresholdSaturation(workingImage, sat);
      final dilated = _dilateSeparable(satBinary, 30);
      result = _tryFindCard(
          dilated, totalArea, workingImage.width, workingImage.height);
      if (result != null) return _scaleResult(result, scaleX, scaleY);
    }

    return ContourDetectionResult.failure(
        'No valid rectangular contour found after trying all strategies');
  }

  /// Downsamples the image if it exceeds [_maxDimensionForDetection] pixels
  /// on the longest side for faster processing. Returns a record with the
  /// working image and scale factors to map corners back to the original.
  static (img.Image, double, double) _prepareImage(img.Image image) {
    final maxDim = max(image.width, image.height);
    if (maxDim <= _maxDimensionForDetection) {
      return (image, 1.0, 1.0);
    }
    final factor = _maxDimensionForDetection / maxDim;
    final newWidth = (image.width * factor).round();
    final newHeight = (image.height * factor).round();
    final resized = img.copyResize(image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.nearest);
    return (resized, image.width / newWidth, image.height / newHeight);
  }

  /// Scales a detection result's corners back to original image coordinates.
  static ContourDetectionResult _scaleResult(
      ContourDetectionResult result, double scaleX, double scaleY) {
    if (scaleX == 1.0 && scaleY == 1.0) return result;

    final scaledCorners = result.corners!
        .map((p) => Point2D(
            x: (p.x * scaleX).round(), y: (p.y * scaleY).round()))
        .toList();

    return ContourDetectionResult.success(
      corners: scaledCorners,
      confidence: result.confidence,
      contourAreaRatio: result.contourAreaRatio,
    );
  }

  static int _estimateBackgroundBrightness(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final samples = <int>[];

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

  /// Computes Otsu's optimal threshold for a grayscale image.
  /// Maximizes inter-class variance between foreground and background pixels.
  static int _otsuThreshold(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        histogram[image.getPixel(x, y).r.toInt()]++;
      }
    }

    final total = image.width * image.height;
    var sum = 0.0;
    for (var i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    var sumB = 0.0;
    var wB = 0;
    var maxVariance = 0.0;
    var threshold = 0;

    for (var i = 0; i < 256; i++) {
      wB += histogram[i];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;

      sumB += i * histogram[i];
      final meanB = sumB / wB;
      final meanF = (sum - sumB) / wF;
      final variance = wB * wF * (meanB - meanF) * (meanB - meanF);

      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = i;
      }
    }

    return threshold;
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

  /// Thresholds on HSV saturation to find colorful regions (card artwork).
  /// Card artwork typically has high saturation, backgrounds are neutral.
  static img.Image _thresholdSaturation(img.Image image, int threshold) {
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 1,
    );
    final t = threshold / 255.0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final mx = max(r, max(g, b));
        final mn = min(r, min(g, b));
        final sat = mx > 0 ? (mx - mn) / mx : 0.0;
        result.setPixelRgba(x, y, sat > t ? 255 : 0, 0, 0, 255);
      }
    }
    return result;
  }

  /// Fast separable dilation (horizontal then vertical pass).
  /// O(width×height×radius) instead of O(width×height×radius²).
  /// Expands white regions by [radius] pixels in each direction.
  /// Used in saturation strategy to grow from artwork to card edges.
  static img.Image _dilateSeparable(img.Image binary, int radius) {
    final w = binary.width;
    final h = binary.height;

    // Horizontal pass
    final horiz = img.Image(width: w, height: h, numChannels: 1);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var maxVal = 0;
        final x0 = (x - radius).clamp(0, w - 1);
        final x1 = (x + radius).clamp(0, w - 1);
        for (var nx = x0; nx <= x1; nx++) {
          final val = binary.getPixel(nx, y).r.toInt();
          if (val > maxVal) maxVal = val;
        }
        horiz.setPixelRgba(x, y, maxVal, 0, 0, 255);
      }
    }

    // Vertical pass
    final result = img.Image(width: w, height: h, numChannels: 1);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var maxVal = 0;
        final y0 = (y - radius).clamp(0, h - 1);
        final y1 = (y + radius).clamp(0, h - 1);
        for (var ny = y0; ny <= y1; ny++) {
          final val = horiz.getPixel(x, ny).r.toInt();
          if (val > maxVal) maxVal = val;
        }
        result.setPixelRgba(x, y, maxVal, 0, 0, 255);
      }
    }
    return result;
  }

  /// 3×3 max filter — links nearby white pixels in a binary image.
  /// Used after Sobel thresholding to connect fragmented edge segments.
  static img.Image _dilate(img.Image binary, int kernelSize) {
    final result = img.Image(
      width: binary.width,
      height: binary.height,
      numChannels: 1,
    );
    final halfK = kernelSize ~/ 2;

    for (var y = 0; y < binary.height; y++) {
      for (var x = 0; x < binary.width; x++) {
        var maxVal = 0;
        for (var ky = -halfK; ky <= halfK; ky++) {
          for (var kx = -halfK; kx <= halfK; kx++) {
            final nx = x + kx;
            final ny = y + ky;
            if (nx >= 0 &&
                nx < binary.width &&
                ny >= 0 &&
                ny < binary.height) {
              final val = binary.getPixel(nx, ny).r.toInt();
              if (val > maxVal) maxVal = val;
            }
          }
        }
        result.setPixelRgba(x, y, maxVal, 0, 0, 255);
      }
    }
    return result;
  }

  /// Finds the best connected component representing the card.
  ///
  /// Strategy:
  /// 1. Prefer the largest interior component (not touching the image edge).
  ///    In a typical photo the card is surrounded by background, so the
  ///    card won't touch the edge.
  /// 2. If no good interior component exists, fall back to the largest
  ///    edge-touching component (card fills the entire frame).
  /// 3. Returns an empty image when nothing usable is found, so
  ///    [_tryFindCard] correctly returns null.
  static img.Image _keepBestComponent(img.Image binary) {
    final width = binary.width;
    final height = binary.height;
    final working = img.Image.from(binary);
    const marker = 128;

    var interiorSize = 0;
    var interiorSeedX = -1;
    var interiorSeedY = -1;
    var edgeSize = 0;
    var edgeSeedX = -1;
    var edgeSeedY = -1;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (working.getPixel(x, y).r.toInt() != 255) continue;

        var size = 0;
        var touchesEdge = false;
        final queue = Queue<Point2D>();
        queue.add(Point2D(x: x, y: y));
        working.setPixelRgba(x, y, marker, 0, 0, 255);

        while (queue.isNotEmpty) {
          final p = queue.removeFirst();
          size++;
          if (p.x == 0 ||
              p.x == width - 1 ||
              p.y == 0 ||
              p.y == height - 1) {
            touchesEdge = true;
          }
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = p.x + dx;
              final ny = p.y + dy;
              if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
              if (working.getPixel(nx, ny).r.toInt() == 255) {
                working.setPixelRgba(nx, ny, marker, 0, 0, 255);
                queue.add(Point2D(x: nx, y: ny));
              }
            }
          }
        }

        if (!touchesEdge && size > interiorSize) {
          interiorSize = size;
          interiorSeedX = x;
          interiorSeedY = y;
        } else if (touchesEdge && size > edgeSize) {
          edgeSize = size;
          edgeSeedX = x;
          edgeSeedY = y;
        }
      }
    }

    // Require at least 5 % of image area (matches minAreaRatio)
    final minSize = max(20, (width * height * 0.05).round());

    int seedX, seedY;
    if (interiorSize >= minSize) {
      seedX = interiorSeedX;
      seedY = interiorSeedY;
    } else if (edgeSize >= minSize) {
      seedX = edgeSeedX;
      seedY = edgeSeedY;
    } else {
      return img.Image(width: width, height: height, numChannels: 1);
    }

    // Reconstruct from the original binary using the chosen seed.
    final result = img.Image(width: width, height: height, numChannels: 1);
    final fillQueue = Queue<Point2D>();
    fillQueue.add(Point2D(x: seedX, y: seedY));
    result.setPixelRgba(seedX, seedY, 255, 0, 0, 255);

    while (fillQueue.isNotEmpty) {
      final p = fillQueue.removeFirst();
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = p.x + dx;
          final ny = p.y + dy;
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
          if (result.getPixel(nx, ny).r.toInt() != 0) continue;
          if (binary.getPixel(nx, ny).r.toInt() == 255) {
            result.setPixelRgba(nx, ny, 255, 0, 0, 255);
            fillQueue.add(Point2D(x: nx, y: ny));
          }
        }
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
    final largest = _keepBestComponent(binary);
    final edgePoints = _collectEdgePixels(largest, width, height);
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

  /// Extracts 4 corners from a convex hull using quadrant-based
  /// farthest-point-from-centroid selection, which is more robust
  /// than the min/max-of-sums approach when the hull has many edge points.
  static List<Point2D> _extractFourCorners(List<Point2D> hull) {
    if (hull.length == 4) return _orderCorners(hull);

    // Compute centroid
    var cx = 0.0, cy = 0.0;
    for (final p in hull) {
      cx += p.x;
      cy += p.y;
    }
    cx /= hull.length;
    cy /= hull.length;

    // Partition hull points into 4 angular quadrants around the centroid.
    // Image coordinates: x→right, y→down
    //   Q0 (TL): negative dx, negative dy  → angle [-π, -π/2)
    //   Q1 (TR): positive dx, negative dy  → angle [-π/2, 0)
    //   Q2 (BR): positive dx, positive dy  → angle [0, π/2)
    //   Q3 (BL): negative dx, positive dy  → angle [π/2, π]
    final quadrants = List.generate(4, (_) => <Point2D>[]);
    for (final p in hull) {
      final dx = p.x - cx;
      final dy = p.y - cy;
      if (dx == 0 && dy == 0) continue;
      final angle = atan2(dy, dx);
      final qIdx = switch (angle) {
        _ when angle >= -pi && angle < -pi / 2 => 0,
        _ when angle >= -pi / 2 && angle < 0 => 1,
        _ when angle >= 0 && angle < pi / 2 => 2,
        _ => 3,
      };
      quadrants[qIdx].add(p);
    }

    // Pick the farthest point from centroid in each quadrant
    final corners = <Point2D>[];
    for (final q in quadrants) {
      if (q.isEmpty) continue;
      var farthest = q[0];
      var maxDist = _distanceSquared(
          Point2D(x: cx.round(), y: cy.round()), q[0]);
      for (final p in q) {
        final d = _distanceSquared(
            Point2D(x: cx.round(), y: cy.round()), p);
        if (d > maxDist) {
          maxDist = d;
          farthest = p;
        }
      }
      corners.add(farthest);
    }

    // Fallback to legacy extraction if quadrant partition failed
    if (corners.length < 4) {
      return _extractFourCornersLegacy(hull);
    }

    return _orderCorners(corners);
  }

  /// Legacy corner extraction using min/max of (x+y) and (x-y).
  static List<Point2D> _extractFourCornersLegacy(List<Point2D> hull) {
    if (hull.length <= 4) {
      final padded = List<Point2D>.from(hull);
      while (padded.length < 4) {
        padded.add(hull.last);
      }
      return _orderCorners(padded);
    }

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
