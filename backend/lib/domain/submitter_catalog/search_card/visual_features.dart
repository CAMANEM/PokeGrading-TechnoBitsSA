/// @file
/// @brief

import 'dart:convert';
import 'package:image/image.dart' as img;

/// @brief ImageHashType
enum ImageHashType {
  averageHash,
  differenceHash,
}

/// @brief ScoringStrategy
enum ScoringStrategy {
  linear,
  quadratic,
}

/// @brief VisualFeatures
class VisualFeatures {
  final String? averageHashHex;
  final String? differenceHashHex;

  final String? centerAverageHashHex;
  final String? centerDifferenceHashHex;

  final String? edgeHashHex;

  const VisualFeatures({
    this.averageHashHex,
    this.differenceHashHex,
    this.centerAverageHashHex,
    this.centerDifferenceHashHex,
    this.edgeHashHex,
  });

  bool get isEmpty => averageHashHex == null && differenceHashHex == null;
}

/// @brief VisualFeatureExtractor
class VisualFeatureExtractor {
  const VisualFeatureExtractor();

  VisualFeatures extract(String imageData) {
    final image = _decodeImage(imageData);

    if (image == null) {
      return const VisualFeatures();
    }

    return extractFromImage(image);
  }

  VisualFeatures extractFromImage(img.Image image) {
    final center = _centerCrop(image);

    return VisualFeatures(
      averageHashHex: _computeAverageHash(image),
      differenceHashHex: _computeDifferenceHash(image),
      centerAverageHashHex: _computeAverageHash(center),
      centerDifferenceHashHex: _computeDifferenceHash(center),
      edgeHashHex: _computeEdgeHash(image),
    );
  }

  img.Image _centerCrop(img.Image image) {
    return img.copyCrop(
      image,
      x: image.width ~/ 4,
      y: image.height ~/ 4,
      width: image.width ~/ 2,
      height: image.height ~/ 2,
    );
  }

  String _computeAverageHash(img.Image image) {
    final resized = img.copyResize(image, width: 8, height: 8);

    final gray = img.grayscale(resized);

    int total = 0;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        total += gray.getPixel(x, y).r.toInt();
      }
    }

    final average = total / 64.0;

    BigInt hash = BigInt.zero;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        hash <<= 1;

        if (gray.getPixel(x, y).r >= average) {
          hash |= BigInt.one;
        }
      }
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }

  String _computeDifferenceHash(img.Image image) {
    final resized = img.copyResize(image, width: 9, height: 8);

    final gray = img.grayscale(resized);

    BigInt hash = BigInt.zero;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        hash <<= 1;

        final left = gray.getPixel(x, y).r.toInt();

        final right = gray.getPixel(x + 1, y).r.toInt();

        if (left > right) {
          hash |= BigInt.one;
        }
      }
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }

  String _computeEdgeHash(img.Image image) {
    final edges = img.sobel(image);

    return _computeAverageHash(edges);
  }

  int _hammingDistance(
    String hexA,
    String hexB,
  ) {
    final a = BigInt.parse(hexA, radix: 16);
    final b = BigInt.parse(hexB, radix: 16);

    BigInt diff = a ^ b;

    int count = 0;

    while (diff != BigInt.zero) {
      count++;

      diff &= (diff - BigInt.one);
    }

    return count;
  }

  double _hashSimilarity(
    String? a,
    String? b,
  ) {
    if (a == null || b == null) {
      return 0.0;
    }

    final distance = _hammingDistance(a, b);

    return 100.0 * (1.0 - distance / 64.0);
  }

  double similarity(
    VisualFeatures a,
    VisualFeatures b, {
    ScoringStrategy strategy = ScoringStrategy.quadratic,
  }) {
    int totalBits = 0;
    int totalDistance = 0;

    if (a.averageHashHex != null && b.averageHashHex != null) {
      totalDistance += _hammingDistance(
        a.averageHashHex!,
        b.averageHashHex!,
      );

      totalBits += 64;
    }

    if (a.differenceHashHex != null && b.differenceHashHex != null) {
      totalDistance += _hammingDistance(
        a.differenceHashHex!,
        b.differenceHashHex!,
      );

      totalBits += 64;
    }

    if (totalBits == 0) {
      return 0.0;
    }

    final ratio = totalDistance / totalBits;

    switch (strategy) {
      case ScoringStrategy.linear:
        return 100.0 - 100.0 * ratio;

      case ScoringStrategy.quadratic:
        return 100.0 * (1.0 - ratio * ratio);
    }
  }

  double specializedSimilarity(
    VisualFeatures a,
    VisualFeatures b,
  ) {
    final global = similarity(a, b);

    final centerAHash = _hashSimilarity(
      a.centerAverageHashHex,
      b.centerAverageHashHex,
    );

    final centerDHash = _hashSimilarity(
      a.centerDifferenceHashHex,
      b.centerDifferenceHashHex,
    );

    final edge = _hashSimilarity(
      a.edgeHashHex,
      b.edgeHashHex,
    );

    return global * 0.40 +
        centerAHash * 0.20 +
        centerDHash * 0.20 +
        edge * 0.20;
  }

  double similarityWithStored(
    VisualFeatures stored,
    String queryImageData,
  ) {
    final queryFeatures = extract(queryImageData);

    if (queryFeatures.isEmpty || stored.isEmpty) {
      return 0.0;
    }

    return similarity(
      queryFeatures,
      stored,
    );
  }

  img.Image? _decodeImage(
    String imageData,
  ) {
    try {
      final base64Part =
          imageData.contains(',') ? imageData.split(',').last : imageData;

      final bytes = base64Decode(base64Part);

      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }
}
