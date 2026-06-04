import 'dart:convert';
import 'package:image/image.dart' as img;

enum ImageHashType { averageHash, differenceHash }

class VisualFeatures {
  final String? averageHashHex;
  final String? differenceHashHex;

  const VisualFeatures({this.averageHashHex, this.differenceHashHex});

  bool get isEmpty => averageHashHex == null && differenceHashHex == null;
}

class VisualFeatureExtractor {
  const VisualFeatureExtractor();

  VisualFeatures extract(String imageData) {
    final image = _decodeImage(imageData);
    if (image == null) return const VisualFeatures();
    return extractFromImage(image);
  }

  VisualFeatures extractFromImage(img.Image image) {
    return VisualFeatures(
      averageHashHex: _computeAverageHash(image),
      differenceHashHex: _computeDifferenceHash(image),
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

    int hash = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        hash <<= 1;
        if (gray.getPixel(x, y).r >= average) {
          hash |= 1;
        }
      }
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  String _computeDifferenceHash(img.Image image) {
    final resized = img.copyResize(image, width: 9, height: 8);
    final gray = img.grayscale(resized);

    int hash = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        hash <<= 1;
        final left = gray.getPixel(x, y).r.toInt();
        final right = gray.getPixel(x + 1, y).r.toInt();
        if (left > right) {
          hash |= 1;
        }
      }
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  int _hammingDistance(String hexA, String hexB) {
    final a = int.parse(hexA, radix: 16);
    final b = int.parse(hexB, radix: 16);
    int diff = a ^ b;
    int count = 0;
    while (diff != 0) {
      count++;
      diff &= (diff - 1);
    }
    return count;
  }

  double similarity(VisualFeatures a, VisualFeatures b) {
    int totalBits = 0;
    int totalDistance = 0;

    if (a.averageHashHex != null && b.averageHashHex != null) {
      totalDistance +=
          _hammingDistance(a.averageHashHex!, b.averageHashHex!);
      totalBits += 64;
    }
    if (a.differenceHashHex != null && b.differenceHashHex != null) {
      totalDistance +=
          _hammingDistance(a.differenceHashHex!, b.differenceHashHex!);
      totalBits += 64;
    }

    if (totalBits == 0) return 0.0;
    return 100.0 - 100.0 * (totalDistance / totalBits);
  }

  img.Image? _decodeImage(String imageData) {
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
