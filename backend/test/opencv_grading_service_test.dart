import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/scoring/opencv_grading_service.dart';
import 'package:pokegrading_backend/domain/scoring/grading/grading_rules.dart';

void main() {
  group('OpenCVGradingService', () {
    group('scoreCentering', () {
      test('identical images return high score', () {
        final card = _createTestCard(300, 400);
        final score = OpenCVGradingService.scoreCentering(card, card);
        expect(score, greaterThanOrEqualTo(8.0));
      });

      test('offset image scores lower than identical', () {
        final ref = _createTestCard(300, 400);
        final sub = _createOffsetCard(300, 400, offsetX: 15, offsetY: 10);
        final scoreIdentical = OpenCVGradingService.scoreCentering(ref, ref);
        final scoreOffset = OpenCVGradingService.scoreCentering(sub, ref);
        expect(scoreOffset, lessThan(scoreIdentical));
      });

      test('returns value between 1.0 and 10.0', () {
        final a = _createTestCard(300, 400);
        final b = _createOffsetCard(300, 400, offsetX: 30, offsetY: 20);
        final score = OpenCVGradingService.scoreCentering(a, b);
        expect(score, inInclusiveRange(1.0, 10.0));
      });
    });

    group('scoreCorners', () {
      test('identical corners return high score', () {
        final corners = List.generate(4, (_) => _createTestImage(80, 80));
        final score = OpenCVGradingService.scoreCorners(corners, corners);
        expect(score, greaterThanOrEqualTo(8.0));
      });

      test('returns value between 1.0 and 10.0', () {
        final ref = List.generate(4, (_) => _createTestImage(80, 80));
        final sub = List.generate(4, (_) => _createBlurredImage(80, 80));
        final score = OpenCVGradingService.scoreCorners(sub, ref);
        expect(score, inInclusiveRange(1.0, 10.0));
      });
    });

    group('scoreEdges', () {
      test('identical edges return high score', () {
        final edges = List.generate(4, (_) => _createTestImage(100, 50));
        final score = OpenCVGradingService.scoreEdges(edges, edges);
        expect(score, greaterThanOrEqualTo(8.0));
      });

      test('returns value between 1.0 and 10.0', () {
        final ref = List.generate(4, (_) => _createTestImage(100, 50));
        final sub = List.generate(4, (_) => _createEmptyImage(100, 50));
        final score = OpenCVGradingService.scoreEdges(sub, ref);
        expect(score, inInclusiveRange(1.0, 10.0));
      });
    });

    group('scoreSurface', () {
      test('identical surfaces return 10.0', () {
        final surface = _createTestImage(200, 200);
        final score = OpenCVGradingService.scoreSurface(surface, surface);
        expect(score, 10.0);
      });

      test('noisy surface scores lower', () {
        final ref = _createTestImage(200, 200);
        final noisy = _createNoisyImage(200, 200);
        final score = OpenCVGradingService.scoreSurface(noisy, ref);
        expect(score, lessThan(10.0));
        expect(score, inInclusiveRange(1.0, 10.0));
      });

      test('handles different sizes by resizing', () {
        final small = _createTestImage(50, 50);
        final large = _createTestImage(200, 200);
        final score = OpenCVGradingService.scoreSurface(small, large);
        expect(score, inInclusiveRange(1.0, 10.0));
      });
    });
  });

  group('GradingRules', () {
    test('identical subgrades produce high final grade', () {
      final result = GradingRules.apply(
        centerGrade: 9.0,
        cornersGrade: 9.0,
        edgesGrade: 9.0,
        surfaceGrade: 9.0,
      );
      expect(result.finalGrade, 9.0);
      expect(result.requiresManualReview, isFalse);
      expect(result.uncertaintyBand, 0.0);
    });

    test('final grade is clamped to min subgrade + 0.5', () {
      final result = GradingRules.apply(
        centerGrade: 9.0,
        cornersGrade: 9.0,
        edgesGrade: 9.0,
        surfaceGrade: 5.0,
      );
      expect(result.finalGrade, lessThanOrEqualTo(5.0 + 0.5));
    });

    test('high uncertainty triggers manual review', () {
      final result = GradingRules.apply(
        centerGrade: 10.0,
        cornersGrade: 10.0,
        edgesGrade: 1.0,
        surfaceGrade: 10.0,
      );
      expect(result.requiresManualReview, isTrue);
      expect(result.uncertaintyBand, greaterThan(GradingRules.uncertaintyThreshold));
    });

    test('low subgrade triggers manual review', () {
      final result = GradingRules.apply(
        centerGrade: 1.5,
        cornersGrade: 8.0,
        edgesGrade: 8.0,
        surfaceGrade: 8.0,
      );
      expect(result.requiresManualReview, isTrue);
      expect(result.reviewReason, contains('minimo'));
    });

    test('coherence deviation triggers manual review', () {
      final result = GradingRules.apply(
        centerGrade: 9.0,
        cornersGrade: 9.0,
        edgesGrade: 2.0,
        surfaceGrade: 9.0,
      );
      expect(result.requiresManualReview, isTrue);
      expect(result.reviewReason, contains('Incoherencia'));
    });

    test('confidence score is inverse of uncertainty', () {
      final result = GradingRules.apply(
        centerGrade: 8.0,
        cornersGrade: 8.0,
        edgesGrade: 8.0,
        surfaceGrade: 8.0,
      );
      expect(result.confidenceScore, closeTo(1.0, 0.01));
    });
  });
}

img.Image _createTestImage(int w, int h) {
  final image = img.Image(width: w, height: h);
  final rng = Random(42);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixel(
        x,
        y,
        img.ColorRgb8(
          rng.nextInt(200) + 28,
          rng.nextInt(200) + 28,
          rng.nextInt(200) + 28,
        ),
      );
    }
  }
  return image;
}

img.Image _createTestCard(int w, int h) {
  final card = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      card.setPixel(x, y, img.ColorRgb8(255, 255, 255));
    }
  }
  final margin = (w * 0.1).round();
  for (var y = margin; y < h - margin; y++) {
    for (var x = margin; x < w - margin; x++) {
      card.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }
  return card;
}

img.Image _createOffsetCard(int w, int h, {int offsetX = 0, int offsetY = 0}) {
  final card = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      card.setPixel(x, y, img.ColorRgb8(255, 255, 255));
    }
  }
  final margin = (w * 0.1).round();
  final startX = margin + offsetX;
  final startY = margin + offsetY;
  final endX = w - margin + offsetX;
  final endY = h - margin + offsetY;
  for (var y = startY.clamp(0, h); y < endY.clamp(0, h); y++) {
    for (var x = startX.clamp(0, w); x < endX.clamp(0, w); x++) {
      card.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }
  return card;
}

img.Image _createBlurredImage(int w, int h) {
  return img.gaussianBlur(_createTestImage(w, h), radius: 5);
}

img.Image _createEmptyImage(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixel(x, y, img.ColorRgb8(128, 128, 128));
    }
  }
  return image;
}

img.Image _createNoisyImage(int w, int h) {
  final image = _createTestImage(w, h);
  final rng = Random(99);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final noise = rng.nextInt(100) - 50;
      image.setPixel(
        x,
        y,
        img.ColorRgb8(
          (p.r.toInt() + noise).clamp(0, 255),
          (p.g.toInt() + noise).clamp(0, 255),
          (p.b.toInt() + noise).clamp(0, 255),
        ),
      );
    }
  }
  return image;
}
