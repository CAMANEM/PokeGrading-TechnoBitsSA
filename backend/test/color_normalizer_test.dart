/// @file
/// @brief Tests for color normalization module.

import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/image_services/preprocessing/color_normalizer.dart';

void main() {
  group('ColorNormalizer', () {
    test('does not mutate the original image', () {
      final original = _createTestImage(10, 10, r: 200, g: 100, b: 50);
      final originalPixel = original.getPixel(5, 5);

      ColorNormalizer.normalize(original);

      final afterPixel = original.getPixel(5, 5);
      expect(afterPixel.r.toInt(), originalPixel.r.toInt());
      expect(afterPixel.g.toInt(), originalPixel.g.toInt());
      expect(afterPixel.b.toInt(), originalPixel.b.toInt());
    });

    test('returns image with same dimensions', () {
      final src = _createTestImage(20, 30, r: 150, g: 150, b: 150);
      final result = ColorNormalizer.normalize(src);

      expect(result.width, 20);
      expect(result.height, 30);
    });

    test('white balance equalizes channel means for color cast image', () {
      // Create image with strong warm cast (high R, low B).
      final src = _createTestImage(10, 10, r: 200, g: 150, b: 80);
      final result = ColorNormalizer.normalize(src);

      // After normalization, compute channel means.
      var sumR = 0, sumG = 0, sumB = 0;
      for (var y = 0; y < result.height; y++) {
        for (var x = 0; x < result.width; x++) {
          final p = result.getPixel(x, y);
          sumR += p.r.toInt();
          sumG += p.g.toInt();
          sumB += p.b.toInt();
        }
      }
      final total = result.width * result.height;
      final avgR = sumR / total;
      final avgG = sumG / total;
      final avgB = sumB / total;

      // Channel means should be closer together than the original.
      final originalSpread = (200 - 80).toDouble();
      final resultSpread = (avgR - avgB).abs();
      expect(resultSpread, lessThan(originalSpread));
    });

    test('preserves neutral images (no color cast)', () {
      // Create a neutral gray image — all channels equal.
      final src = _createTestImage(10, 10, r: 128, g: 128, b: 128);
      final result = ColorNormalizer.normalize(src);

      // A neutral image should remain approximately neutral.
      final p = result.getPixel(5, 5);
      // After histogram stretch, values should still be close to each other.
      final spread = (p.r.toInt() - p.g.toInt()).abs() +
          (p.g.toInt() - p.b.toInt()).abs();
      expect(spread, lessThan(10));
    });

    test('handles all-black image without division by zero', () {
      final src = _createTestImage(5, 5, r: 0, g: 0, b: 0);
      final result = ColorNormalizer.normalize(src);

      // Should not throw; output should be valid.
      expect(result.width, 5);
      expect(result.height, 5);
    });

    test('handles all-white image', () {
      final src = _createTestImage(5, 5, r: 255, g: 255, b: 255);
      final result = ColorNormalizer.normalize(src);

      expect(result.width, 5);
      expect(result.height, 5);
      final p = result.getPixel(2, 2);
      expect(p.r.toInt(), 255);
      expect(p.g.toInt(), 255);
      expect(p.b.toInt(), 255);
    });

    test('handles mixed-color image (varied pixels)', () {
      final src = img.Image(width: 20, height: 20);
      final rng = Random(42);
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 20; x++) {
          src.setPixel(
            x,
            y,
            img.ColorRgb8(
              rng.nextInt(256),
              rng.nextInt(256),
              rng.nextInt(256),
            ),
          );
        }
      }

      // Should not throw.
      final result = ColorNormalizer.normalize(src);
      expect(result.width, 20);
      expect(result.height, 20);
    });
  });
}

/// Creates a test image where every pixel has the same RGB values.
img.Image _createTestImage(
  int width,
  int height, {
  required int r,
  required int g,
  required int b,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }
  return image;
}
