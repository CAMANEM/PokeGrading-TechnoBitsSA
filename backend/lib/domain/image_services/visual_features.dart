/// @file
/// @brief Perceptual hash extraction for catalog image search.

import 'dart:convert';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Visual feature bundle for front image hashes and optional back image hashes.
class VisualFeatures {
  final String? averageHashHex;
  final String? differenceHashHex;
  final String? centerAverageHashHex;
  final String? centerDifferenceHashHex;
  final String? edgeHashHex;
  final String? backAverageHashHex;
  final String? backDifferenceHashHex;
  final String? backCenterAverageHashHex;
  final String? backCenterDifferenceHashHex;
  final String? backEdgeHashHex;

  const VisualFeatures({
    this.averageHashHex,
    this.differenceHashHex,
    this.centerAverageHashHex,
    this.centerDifferenceHashHex,
    this.edgeHashHex,
    this.backAverageHashHex,
    this.backDifferenceHashHex,
    this.backCenterAverageHashHex,
    this.backCenterDifferenceHashHex,
    this.backEdgeHashHex,
  });

  bool get isEmpty => averageHashHex == null && differenceHashHex == null;

  bool get hasBack =>
      backAverageHashHex != null || backDifferenceHashHex != null;

  /// Front-side hashes only (query image or catalog front).
  VisualFeatures frontView() => VisualFeatures(
        averageHashHex: averageHashHex,
        differenceHashHex: differenceHashHex,
        centerAverageHashHex: centerAverageHashHex,
        centerDifferenceHashHex: centerDifferenceHashHex,
        edgeHashHex: edgeHashHex,
      );

  /// Back-side hashes mapped to front field names for scoring.
  VisualFeatures backView() => VisualFeatures(
        averageHashHex: backAverageHashHex,
        differenceHashHex: backDifferenceHashHex,
        centerAverageHashHex: backCenterAverageHashHex,
        centerDifferenceHashHex: backCenterDifferenceHashHex,
        edgeHashHex: backEdgeHashHex,
      );

  /// Merges back-image hashes from [back] into this front feature set.
  VisualFeatures withBackFrom(VisualFeatures back) => VisualFeatures(
        averageHashHex: averageHashHex,
        differenceHashHex: differenceHashHex,
        centerAverageHashHex: centerAverageHashHex,
        centerDifferenceHashHex: centerDifferenceHashHex,
        edgeHashHex: edgeHashHex,
        backAverageHashHex: back.averageHashHex,
        backDifferenceHashHex: back.differenceHashHex,
        backCenterAverageHashHex: back.centerAverageHashHex,
        backCenterDifferenceHashHex: back.centerDifferenceHashHex,
        backEdgeHashHex: back.edgeHashHex,
      );
}

/// Extracts perceptual hashes from Base64 image payloads.
class VisualFeatureExtractor {
  static VisualFeatures extract(String imageData) {
    final image = _decodeImage(imageData);

    if (image == null) {
      return const VisualFeatures();
    }

    return extractFromImage(image);
  }

  static VisualFeatures extractFromImage(img.Image image) {
    final prepared = _prepareForHashing(image);
    final center = _centerCrop(prepared);

    return VisualFeatures(
      averageHashHex: _computeAverageHash(prepared),
      differenceHashHex: _computeDifferenceHash(prepared),
      centerAverageHashHex: _computeAverageHash(center),
      centerDifferenceHashHex: _computeDifferenceHash(center),
      edgeHashHex: _computeEdgeHash(prepared),
    );
  }

  static img.Image _prepareForHashing(img.Image image) {
    final gray = img.grayscale(image);
    final normalized = _normalizeContrast(gray);
    return _padToSquare(normalized);
  }

  static img.Image _normalizeContrast(img.Image gray) {
    var min = 255;
    var max = 0;

    for (final pixel in gray) {
      final value = pixel.r.toInt();
      if (value < min) min = value;
      if (value > max) max = value;
    }

    if (max <= min) return gray;

    final scale = 255.0 / (max - min);
    final out = img.Image(width: gray.width, height: gray.height);

    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        final value = gray.getPixel(x, y).r.toInt();
        final stretched = ((value - min) * scale).round().clamp(0, 255);
        out.setPixelRgb(x, y, stretched, stretched, stretched);
      }
    }

    return out;
  }

  static img.Image _padToSquare(img.Image image) {
    final side = math.max(image.width, image.height);
    final out = img.Image(width: side, height: side);
    img.fill(out, color: img.ColorRgb8(0, 0, 0));

    final x = (side - image.width) ~/ 2;
    final y = (side - image.height) ~/ 2;
    img.compositeImage(out, image, dstX: x, dstY: y);

    return out;
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

    var total = 0;

    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        total += gray.getPixel(x, y).r.toInt();
      }
    }

    final average = total / 64.0;
    var hash = BigInt.zero;

    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
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
    var hash = BigInt.zero;

    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
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
    final gray = img.grayscale(image);
    final edges = img.sobel(gray);
    return _computeAverageHash(edges);
  }

  static img.Image? _decodeImage(String imageData) {
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
