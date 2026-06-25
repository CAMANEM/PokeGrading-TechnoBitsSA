/// @file
/// @brief Tests for preprocessing data models.

import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/image_services/preprocessing/preprocessing_models.dart';

void main() {
  group('Point2D', () {
    test('creates with correct coordinates', () {
      const point = Point2D(x: 10, y: 20);
      expect(point.x, 10);
      expect(point.y, 20);
    });

    test('equality works correctly', () {
      const point1 = Point2D(x: 10, y: 20);
      const point2 = Point2D(x: 10, y: 20);
      const point3 = Point2D(x: 15, y: 25);

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });

    test('toString returns readable format', () {
      const point = Point2D(x: 10, y: 20);
      expect(point.toString(), 'Point2D(10, 20)');
    });
  });

  group('ContourDetectionResult', () {
    test('success factory creates valid result', () {
      final corners = [
        const Point2D(x: 0, y: 0),
        const Point2D(x: 100, y: 0),
        const Point2D(x: 100, y: 150),
        const Point2D(x: 0, y: 150),
      ];

      final result = ContourDetectionResult.success(
        corners: corners,
        confidence: 0.95,
        contourAreaRatio: 0.75,
      );

      expect(result.detected, true);
      expect(result.corners, corners);
      expect(result.confidence, 0.95);
      expect(result.contourAreaRatio, 0.75);
      expect(result.error, isNull);
    });

    test('failure factory creates invalid result', () {
      final result = ContourDetectionResult.failure('No contour found');

      expect(result.detected, false);
      expect(result.corners, isNull);
      expect(result.error, 'No contour found');
    });
  });

  group('PerspectiveCorrectionResult', () {
    test('success factory creates valid result', () {
      final result = PerspectiveCorrectionResult.success(
        correctedImageData: 'base64data',
        transformMatrix: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
        originalCorners: [
          const Point2D(x: 0, y: 0),
          const Point2D(x: 100, y: 0),
          const Point2D(x: 100, y: 150),
          const Point2D(x: 0, y: 150),
        ],
        metadata: PreprocessingMetadata.timed(
          detectionTimeMs: 50,
          correctionTimeMs: 30,
        ),
      );

      expect(result.success, true);
      expect(result.correctedImageData, 'base64data');
      expect(result.transformMatrix, hasLength(9));
      expect(result.metadata.totalTimeMs, 80);
    });

    test('failure factory creates invalid result', () {
      final result = PerspectiveCorrectionResult.failure(
        error: PreprocessingError.noContourDetected,
        metadata: PreprocessingMetadata.timed(
          detectionTimeMs: 50,
          correctionTimeMs: 0,
        ),
      );

      expect(result.success, false);
      expect(result.correctedImageData, isNull);
      expect(result.error, PreprocessingError.noContourDetected);
    });
  });

  group('PreprocessingMetadata', () {
    test('timed factory calculates total time', () {
      final metadata = PreprocessingMetadata.timed(
        detectionTimeMs: 100,
        correctionTimeMs: 50,
      );

      expect(metadata.detectionTimeMs, 100);
      expect(metadata.correctionTimeMs, 50);
      expect(metadata.totalTimeMs, 150);
    });

    test('algorithm version is defined', () {
      expect(PreprocessingMetadata.algorithmVersion, isNotEmpty);
    });
  });

  group('CardDimensions', () {
    test('aspect ratio is correct for Pokemon cards', () {
      final expectedRatio = CardDimensions.standardWidth /
          CardDimensions.standardHeight;
      expect(CardDimensions.aspectRatio, closeTo(expectedRatio, 0.001));
    });
  });
}
