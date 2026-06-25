/// @file
/// @brief Tests for ROI segmentation module.

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/image_services/preprocessing/roi_segmenter.dart';
import 'package:pokegrading_backend/domain/image_services/preprocessing/preprocessing_models.dart';

void main() {
  const cardW = CardDimensions.standardWidth;  // 750
  const cardH = CardDimensions.standardHeight; // 1050

  group('RoiSegmenter', () {
    late img.Image card;

    setUp(() {
      card = _createTestCard(cardW, cardH);
    });

    test('extract returns all 10 ROIs', () {
      final result = RoiSegmenter.extract(card);

      expect(result.centering, isA<img.Image>());
      expect(result.cornerTopLeft, isA<img.Image>());
      expect(result.cornerTopRight, isA<img.Image>());
      expect(result.cornerBottomLeft, isA<img.Image>());
      expect(result.cornerBottomRight, isA<img.Image>());
      expect(result.edgeTop, isA<img.Image>());
      expect(result.edgeBottom, isA<img.Image>());
      expect(result.edgeLeft, isA<img.Image>());
      expect(result.edgeRight, isA<img.Image>());
      expect(result.surface, isA<img.Image>());
    });

    test('centering has correct dimensions', () {
      final result = RoiSegmenter.extract(card);

      final expectedW = cardW - (cardW * RoiSegmenter.centeringMarginX * 2).round();
      final expectedH = cardH - (cardH * RoiSegmenter.centeringMarginY * 2).round();

      expect(result.centering.width, closeTo(expectedW, 1));
      expect(result.centering.height, closeTo(expectedH, 1));
    });

    test('surface has correct dimensions', () {
      final result = RoiSegmenter.extract(card);

      final expectedW = cardW - (cardW * RoiSegmenter.surfaceMarginX * 2).round();
      final expectedH = cardH - (cardH * RoiSegmenter.surfaceMarginY * 2).round();

      expect(result.surface.width, closeTo(expectedW, 1));
      expect(result.surface.height, closeTo(expectedH, 1));
    });

    test('corner crops are square', () {
      final result = RoiSegmenter.extract(card);
      final size = (cardW * RoiSegmenter.cornerFraction).round();

      expect(result.cornerTopLeft.width, size);
      expect(result.cornerTopLeft.height, size);
      expect(result.cornerTopRight.width, size);
      expect(result.cornerBottomLeft.width, size);
      expect(result.cornerBottomRight.width, size);
    });

    test('edge strips have correct dimensions', () {
      final result = RoiSegmenter.extract(card);

      final edgeH = (cardH * RoiSegmenter.edgeFractionY).round();
      final edgeW = (cardW * RoiSegmenter.edgeFractionX).round();
      final middleH = cardH - edgeH * 2;

      // Top/bottom: full width, edgeH tall.
      expect(result.edgeTop.width, cardW);
      expect(result.edgeTop.height, edgeH);
      expect(result.edgeBottom.width, cardW);
      expect(result.edgeBottom.height, edgeH);

      // Left/right: edgeW wide, middle section tall.
      expect(result.edgeLeft.width, edgeW);
      expect(result.edgeLeft.height, middleH);
      expect(result.edgeRight.width, edgeW);
      expect(result.edgeRight.height, middleH);
    });

    test('does not mutate the original image', () {
      final originalPixel = card.getPixel(0, 0);

      RoiSegmenter.extract(card);

      final afterPixel = card.getPixel(0, 0);
      expect(afterPixel.r.toInt(), originalPixel.r.toInt());
      expect(afterPixel.g.toInt(), originalPixel.g.toInt());
      expect(afterPixel.b.toInt(), originalPixel.b.toInt());
    });

    test('works with non-standard card dimensions', () {
      final smallCard = _createTestCard(375, 525);
      final result = RoiSegmenter.extract(smallCard);

      expect(result.centering.width, greaterThan(0));
      expect(result.cornerTopLeft.width, greaterThan(0));
      expect(result.edgeTop.width, greaterThan(0));
      expect(result.surface.width, greaterThan(0));
    });
  });
}

img.Image _createTestCard(int width, int height) {
  final card = img.Image(width: width, height: height);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      card.setPixel(x, y, img.ColorRgb8(255, 255, 255));
    }
  }

  final cx = (width * 0.15).round();
  final cy = (height * 0.12).round();
  for (var y = cy; y < height - cy; y++) {
    for (var x = cx; x < width - cx; x++) {
      card.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  final cs = (width * 0.15).round();
  _fillRect(card, 0, 0, cs, cs, 255, 0, 0);
  _fillRect(card, width - cs, 0, cs, cs, 0, 255, 0);
  _fillRect(card, 0, height - cs, cs, cs, 0, 0, 255);
  _fillRect(card, width - cs, height - cs, cs, cs, 255, 255, 0);

  return card;
}

void _fillRect(img.Image canvas, int x0, int y0, int w, int h, int r, int g, int b) {
  for (var y = y0; y < y0 + h && y < canvas.height; y++) {
    for (var x = x0; x < x0 + w && x < canvas.width; x++) {
      canvas.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }
}
