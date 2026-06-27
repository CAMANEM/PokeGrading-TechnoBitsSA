/// @file
/// @brief Tests for grading system.

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/image_services/preprocessing/roi_segmenter.dart';
import 'package:pokegrading_backend/domain/image_services/preprocessing/preprocessing_models.dart';
import 'package:pokegrading_backend/domain/image_services/grading/corner_whitening_detector.dart';
import 'package:pokegrading_backend/domain/image_services/grading/edge_whitening_detector.dart';
import 'package:pokegrading_backend/domain/image_services/grading/surface_scratch_detector.dart';
import 'package:pokegrading_backend/domain/image_services/grading/enhanced_quality_service.dart';
import 'package:pokegrading_backend/domain/scoring/grading/grading_orchestrator.dart';
import 'package:pokegrading_backend/domain/scoring/grading/pregrading.dart';

void main() {
  const cardW = CardDimensions.standardWidth;  // 750
  const cardH = CardDimensions.standardHeight; // 1050

  group('CornerWhiteningDetector', () {
    late img.Image cornerImage;

    setUp(() {
      cornerImage = _createTestCorner(100, 100);
    });

    test('analyzeCorner returns valid result', () {
      final result = CornerWhiteningDetector.analyzeCorner(
        cornerImage,
        position: 'top_left',
      );

      expect(result.position, 'top_left');
      expect(result.whiteningScore, greaterThanOrEqualTo(0));
      expect(result.whiteningScore, lessThanOrEqualTo(1));
      expect(result.whiteningPercentage, greaterThanOrEqualTo(0));
      expect(result.passes, isA<bool>());
    });

    test('analyzeCorner detects whitening in damaged corner', () {
      final damagedCorner = _createCornerWithWhitening(100, 100);
      final result = CornerWhiteningDetector.analyzeCorner(
        damagedCorner,
        position: 'top_left',
      );

      expect(result.whiteningPercentage, greaterThan(0));
    });

    test('analyzeAllCorners returns valid result', () {
      final cornerImages = {
        'top_left': cornerImage,
        'top_right': cornerImage,
        'bottom_left': cornerImage,
        'bottom_right': cornerImage,
      };

      final result = CornerWhiteningDetector.analyzeAllCorners(cornerImages);

      expect(result.corners.length, 4);
      expect(result.grade, greaterThanOrEqualTo(1.0));
      expect(result.grade, lessThanOrEqualTo(10.0));
      expect(result.averageWhitening, greaterThanOrEqualTo(0));
      expect(result.averageWhitening, lessThanOrEqualTo(1));
      expect(result.passedCount, greaterThanOrEqualTo(0));
      expect(result.passedCount, lessThanOrEqualTo(4));
    });
  });

  group('EdgeWhiteningDetector', () {
    late img.Image edgeImage;

    setUp(() {
      edgeImage = _createTestEdge(200, 50);
    });

    test('analyzeEdge returns valid result', () {
      final result = EdgeWhiteningDetector.analyzeEdge(
        edgeImage,
        position: 'top',
      );

      expect(result.position, 'top');
      expect(result.whiteningScore, greaterThanOrEqualTo(0));
      expect(result.whiteningScore, lessThanOrEqualTo(1));
      expect(result.straightnessScore, greaterThanOrEqualTo(0));
      expect(result.straightnessScore, lessThanOrEqualTo(1));
      expect(result.qualityScore, greaterThanOrEqualTo(0));
      expect(result.qualityScore, lessThanOrEqualTo(1));
      expect(result.passes, isA<bool>());
    });

    test('analyzeAllEdges returns valid result', () {
      final edgeImages = {
        'top': edgeImage,
        'bottom': edgeImage,
        'left': edgeImage,
        'right': edgeImage,
      };

      final result = EdgeWhiteningDetector.analyzeAllEdges(edgeImages);

      expect(result.edges.length, 4);
      expect(result.grade, greaterThanOrEqualTo(1.0));
      expect(result.grade, lessThanOrEqualTo(10.0));
      expect(result.averageQuality, greaterThanOrEqualTo(0));
      expect(result.averageQuality, lessThanOrEqualTo(1));
      expect(result.passedCount, greaterThanOrEqualTo(0));
      expect(result.passedCount, lessThanOrEqualTo(4));
    });
  });

  group('SurfaceScratchDetector', () {
    late img.Image surfaceImage;

    setUp(() {
      surfaceImage = _createTestSurface(300, 300);
    });

    test('analyzeSurface returns valid result', () {
      final result = SurfaceScratchDetector.analyzeSurface(surfaceImage);

      expect(result.scratchScore, greaterThanOrEqualTo(0));
      expect(result.scratchScore, lessThanOrEqualTo(1));
      expect(result.printLineScore, greaterThanOrEqualTo(0));
      expect(result.printLineScore, lessThanOrEqualTo(1));
      expect(result.uniformityScore, greaterThanOrEqualTo(0));
      expect(result.uniformityScore, lessThanOrEqualTo(1));
      expect(result.grade, greaterThanOrEqualTo(1.0));
      expect(result.grade, lessThanOrEqualTo(10.0));
      expect(result.qualityScore, greaterThanOrEqualTo(0));
      expect(result.qualityScore, lessThanOrEqualTo(1));
      expect(result.scratchCount, greaterThanOrEqualTo(0));
      expect(result.passes, isA<bool>());
    });
  });

  group('EnhancedQualityService', () {
    late img.Image testImage;

    setUp(() {
      testImage = _createTestImage(200, 200);
    });

    test('calculateEnhancedQuality returns valid result', () {
      final result = EnhancedQualityService.calculateEnhancedQuality(testImage);

      expect(result.score, greaterThanOrEqualTo(0));
      expect(result.score, lessThanOrEqualTo(100));
      expect(result.laplacianSharpness, greaterThanOrEqualTo(0));
      expect(result.laplacianSharpness, lessThanOrEqualTo(1));
      expect(result.tenengradSharpness, greaterThanOrEqualTo(0));
      expect(result.tenengradSharpness, lessThanOrEqualTo(1));
      expect(result.brightnessScore, greaterThanOrEqualTo(0));
      expect(result.brightnessScore, lessThanOrEqualTo(1));
      expect(result.entropyScore, greaterThanOrEqualTo(0));
      expect(result.entropyScore, lessThanOrEqualTo(1));
      expect(result.contrastScore, greaterThanOrEqualTo(0));
      expect(result.contrastScore, lessThanOrEqualTo(1));
      expect(result.passes, isA<bool>());
      expect(result.rejectionReasons, isA<List<String>>());
    });

    test('calculateEnhancedQuality rejects blurry image', () {
      final blurryImage = _createBlurryImage(200, 200);
      final result = EnhancedQualityService.calculateEnhancedQuality(blurryImage);

      expect(result.laplacianSharpness, lessThan(0.5));
    });

    test('calculateEnhancedQuality rejects dark image', () {
      final darkImage = _createDarkImage(200, 200);
      final result = EnhancedQualityService.calculateEnhancedQuality(darkImage);

      expect(result.brightnessScore, lessThan(0.5));
    });
  });

  group('GradingOrchestrator', () {
    late RoiResult rois;

    setUp(() {
      final card = _createTestCard(cardW, cardH);
      rois = RoiSegmenter.extract(card);
    });

    test('grade returns valid result', () {
      final result = GradingOrchestrator.grade(rois);

      expect(result.centeringGrade, greaterThanOrEqualTo(1.0));
      expect(result.centeringGrade, lessThanOrEqualTo(10.0));
      expect(result.corners, isA<CornerGradingResult>());
      expect(result.edges, isA<EdgeGradingResult>());
      expect(result.surface, isA<SurfaceGradingResult>());
      expect(result.finalGrade, greaterThanOrEqualTo(1.0));
      expect(result.finalGrade, lessThanOrEqualTo(10.0));
      expect(result.confidence, greaterThanOrEqualTo(0));
      expect(result.confidence, lessThanOrEqualTo(1));
      expect(result.explanation, isA<String>());
      expect(result.explanation.isNotEmpty, true);
    });

    test('grade produces consistent results', () {
      final result1 = GradingOrchestrator.grade(rois);
      final result2 = GradingOrchestrator.grade(rois);

      // Both should produce valid grades in the same range
      expect(result1.finalGrade, greaterThanOrEqualTo(1.0));
      expect(result1.finalGrade, lessThanOrEqualTo(10.0));
      expect(result2.finalGrade, greaterThanOrEqualTo(1.0));
      expect(result2.finalGrade, lessThanOrEqualTo(10.0));
      // Corner/edge/surface results should be identical (deterministic)
      expect(result1.corners.grade, result2.corners.grade);
      expect(result1.edges.grade, result2.edges.grade);
      expect(result1.surface.grade, result2.surface.grade);
    });

    test('toJson returns valid JSON', () {
      final result = GradingOrchestrator.grade(rois);
      final json = result.toJson();

      expect(json.containsKey('centering_grade'), true);
      expect(json.containsKey('corners'), true);
      expect(json.containsKey('edges'), true);
      expect(json.containsKey('surface'), true);
      expect(json.containsKey('final_grade'), true);
      expect(json.containsKey('confidence'), true);
      expect(json.containsKey('explanation'), true);
    });
  });

  group('Grading (centering)', () {
    late img.Image centerImage;

    setUp(() {
      centerImage = _createTestCenteringImage(600, 840);
    });

    test('centerGrade returns valid grade', () {
      final grade = Grading.centerGrade(centerImage);

      expect(grade, greaterThanOrEqualTo(1.0));
      expect(grade, lessThanOrEqualTo(10.0));
    });

    test('centerGrade rewards centered card', () {
      final centered = _createPerfectlyCenteredImage(600, 840);
      final offCenter = _createOffCenteredImage(600, 840);

      final centeredGrade = Grading.centerGrade(centered);
      final offCenterGrade = Grading.centerGrade(offCenter);

      expect(centeredGrade, greaterThan(offCenterGrade));
    });
  });
}

// --- Test image helpers ---

img.Image _createTestCard(int width, int height) {
  final card = img.Image(width: width, height: height);

  // White background
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      card.setPixel(x, y, img.ColorRgb8(255, 255, 255));
    }
  }

  // Blue artwork area
  final cx = (width * 0.10).round();
  final cy = (height * 0.08).round();
  for (var y = cy; y < height - cy; y++) {
    for (var x = cx; x < width - cx; x++) {
      card.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  return card;
}

img.Image _createTestCorner(int width, int height) {
  final corner = img.Image(width: width, height: height);

  // Normal corner (mostly artwork color)
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      corner.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  return corner;
}

img.Image _createCornerWithWhitening(int width, int height) {
  final corner = img.Image(width: width, height: height);

  // Artwork color
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      corner.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  // Add whitening in the corner tip (top-left) - use brightness 250
  // to simulate exposed cardstock (threshold is 245)
  for (var y = 0; y < (height * 0.3).round(); y++) {
    for (var x = 0; x < (width * 0.3).round(); x++) {
      corner.setPixel(x, y, img.ColorRgb8(250, 250, 250));
    }
  }

  return corner;
}

img.Image _createTestEdge(int width, int height) {
  final edge = img.Image(width: width, height: height);

  // Normal edge
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      edge.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  return edge;
}

img.Image _createTestSurface(int width, int height) {
  final surface = img.Image(width: width, height: height);

  // Uniform surface
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      surface.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  return surface;
}

img.Image _createTestImage(int width, int height) {
  final image = img.Image(width: width, height: height);

  // Normal image with good contrast
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final r = (x / width * 255).round();
      final g = (y / height * 255).round();
      final b = 128;
      image.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }

  return image;
}

img.Image _createBlurryImage(int width, int height) {
  final image = img.Image(width: width, height: height);

  // Uniform color (no edges = blurry)
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, img.ColorRgb8(128, 128, 128));
    }
  }

  return image;
}

img.Image _createDarkImage(int width, int height) {
  final image = img.Image(width: width, height: height);

  // Very dark image
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, img.ColorRgb8(20, 20, 20));
    }
  }

  return image;
}

img.Image _createTestCenteringImage(int width, int height) {
  final image = img.Image(width: width, height: height);

  // White background
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, img.ColorRgb8(255, 255, 255));
    }
  }

  // Centered artwork
  final cx = (width * 0.10).round();
  final cy = (height * 0.10).round();
  for (var y = cy; y < height - cy; y++) {
    for (var x = cx; x < width - cx; x++) {
      image.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  return image;
}

img.Image _createPerfectlyCenteredImage(int width, int height) {
  final image = img.Image(width: width, height: height);

  // White background
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, img.ColorRgb8(255, 255, 255));
    }
  }

  // Perfectly centered artwork
  final margin = (width * 0.10).round();
  for (var y = margin; y < height - margin; y++) {
    for (var x = margin; x < width - margin; x++) {
      image.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  return image;
}

img.Image _createOffCenteredImage(int width, int height) {
  final image = img.Image(width: width, height: height);

  // White background
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, img.ColorRgb8(255, 255, 255));
    }
  }

  // Off-center artwork (shifted right)
  final leftMargin = (width * 0.05).round();
  final rightMargin = (width * 0.25).round();
  final topMargin = (height * 0.10).round();
  final bottomMargin = (height * 0.10).round();

  for (var y = topMargin; y < height - bottomMargin; y++) {
    for (var x = leftMargin; x < width - rightMargin; x++) {
      image.setPixel(x, y, img.ColorRgb8(50, 100, 200));
    }
  }

  return image;
}
