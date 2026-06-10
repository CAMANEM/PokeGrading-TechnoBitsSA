/// @file
/// @brief

import 'dart:convert';
import 'package:image/image.dart' as img;

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
  static VisualFeatures extract(String imageData) {
    final image = _decodeImage(imageData);

    if (image == null) {
      return const VisualFeatures();
    }

    return extractFromImage(image);
  }

  static VisualFeatures extractFromImage(img.Image image) {
    final center = _centerCrop(image);

    return VisualFeatures(
      averageHashHex: _computeAverageHash(image),
      differenceHashHex: _computeDifferenceHash(image),
      centerAverageHashHex: _computeAverageHash(center),
      centerDifferenceHashHex: _computeDifferenceHash(center),
      edgeHashHex: _computeEdgeHash(image),
    );
  }

  static img.Image _centerCrop(img.Image image) {
    return img.copyCrop(
      image,
      x: image.width ~/ 4,
      y: image.height ~/ 4,
      width: image.width ~/ 2,
      height: image.height ~/ 2,
    );
  }

  static String _computeAverageHash(img.Image image) {
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

  static String _computeDifferenceHash(img.Image image) {
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

  static String _computeEdgeHash(img.Image image) {
    final edges = img.sobel(image);

    return _computeAverageHash(edges);
  }

  static img.Image? _decodeImage(
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
