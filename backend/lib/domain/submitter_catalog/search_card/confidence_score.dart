import 'dart:convert';
import 'package:image/image.dart' as img;

class ConfidenceScore {
  double similarity(
    String imageDataA,
    String imageDataB,
  ) {
    final imageA = _decodeImage(imageDataA);
    final imageB = _decodeImage(imageDataB);

    if (imageA == null || imageB == null) {
      return 0.0;
    }

    final hashA = _averageHash(imageA);
    final hashB = _averageHash(imageB);

    final distance = _hammingDistance(hashA, hashB);

    return 100.0 - 100 * (distance / 64.0);
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

  BigInt _averageHash(img.Image image) {
    final resized = img.copyResize(
      image,
      width: 8,
      height: 8,
    );

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

    return hash;
  }

  int _hammingDistance(
    BigInt hashA,
    BigInt hashB,
  ) {
    BigInt diff = hashA ^ hashB;

    int count = 0;

    while (diff != BigInt.zero) {
      count++;
      diff &= (diff - BigInt.one);
    }

    return count;
  }
}
