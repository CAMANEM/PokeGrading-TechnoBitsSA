/// @file
/// @brief Tests for color-aware multichannel perceptual hashing.

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/image_services/confidence_score.dart';
import 'package:pokegrading_backend/domain/image_services/visual_features.dart';

/// Resolves a test image checking the most likely locations relative to the
/// current working directory (`dart test` may be invoked from `backend/` or
/// from the repo root).
img.Image _loadImage(String name) {
  const candidates = ['img', '../img', '../../img', 'backend/img'];

  for (final dir in candidates) {
    final file = File('$dir/$name');
    if (file.existsSync()) {
      final decoded = img.decodeImage(file.readAsBytesSync());
      if (decoded == null) {
        throw StateError('Failed to decode test image: ${file.path}');
      }
      return decoded;
    }
  }

  throw StateError(
    'Test image not found: $name (searched: ${candidates.join(', ')})',
  );
}

void main() {
  group('VisualFeatureExtractor (multichannel 192-bit hashes)', () {
    final cardA = _loadImage('1.jpeg');
    final cardB = _loadImage('2.jpeg');

    test('all produced hashes are 48 hex chars (192 bits)', () {
      final features = VisualFeatureExtractor.extractFromImage(cardA);

      const expected = VisualFeatureExtractor.multiChannelHashHexLength;
      expect(expected, 48);

      expect(features.averageHashHex, isNotNull);
      expect(features.differenceHashHex, isNotNull);
      expect(features.centerAverageHashHex, isNotNull);
      expect(features.centerDifferenceHashHex, isNotNull);
      expect(features.edgeHashHex, isNotNull);

      expect(features.averageHashHex!.length, expected);
      expect(features.differenceHashHex!.length, expected);
      expect(features.centerAverageHashHex!.length, expected);
      expect(features.centerDifferenceHashHex!.length, expected);
      expect(features.edgeHashHex!.length, expected);
    });

    test('self-similarity is 100.0 for both fast and specialized modes', () {
      final features = VisualFeatureExtractor.extractFromImage(cardA);

      final fast = ConfidenceScore.calculateConfidence(
        features,
        features,
        ConfidenceType.fast,
      );
      final specialized = ConfidenceScore.calculateConfidence(
        features,
        features,
        ConfidenceType.specialized,
      );

      expect(fast, 100.0);
      expect(specialized, 100.0);
    });

    test('distinct cards score strictly below self (color collision guard)',
        () {
      final featuresA = VisualFeatureExtractor.extractFromImage(cardA);
      final featuresB = VisualFeatureExtractor.extractFromImage(cardB);

      final cross = ConfidenceScore.calculateConfidence(
        featuresA,
        featuresB,
        ConfidenceType.specialized,
      );

      expect(cross, lessThan(100.0));
    });
  });
}
