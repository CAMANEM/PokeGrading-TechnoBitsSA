import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/image_services/confidence_score.dart';
import 'package:pokegrading_backend/domain/image_services/visual_features.dart';

void main() {
  group('ConfidenceScore', () {
    test('identical front hashes yield ~100% fast similarity', () {
      const query = VisualFeatures(
        averageHashHex: 'ffffffff00000000',
        differenceHashHex: 'aaaaaaaa55555555',
      );
      const catalog = VisualFeatures(
        averageHashHex: 'ffffffff00000000',
        differenceHashHex: 'aaaaaaaa55555555',
      );

      final score = ConfidenceScore.calculateConfidence(
        query,
        catalog,
        ConfidenceType.fast,
      );

      expect(score, greaterThan(99.0));
    });

    test('back image match beats weak front match', () {
      const query = VisualFeatures(
        averageHashHex: '1111111111111111',
        differenceHashHex: '2222222222222222',
      );
      const catalog = VisualFeatures(
        averageHashHex: 'ffffffffffffffff',
        differenceHashHex: 'ffffffffffffffff',
        backAverageHashHex: '1111111111111111',
        backDifferenceHashHex: '2222222222222222',
      );

      final score = ConfidenceScore.calculateConfidence(
        query,
        catalog,
        ConfidenceType.fast,
      );

      expect(score, greaterThan(99.0));
    });

    test('specialized ignores missing edge on catalog side', () {
      const query = VisualFeatures(
        averageHashHex: 'ffffffff00000000',
        differenceHashHex: 'aaaaaaaa55555555',
        centerAverageHashHex: 'ffffffff00000000',
        centerDifferenceHashHex: 'aaaaaaaa55555555',
        edgeHashHex: '1234567890abcdef',
      );
      const catalog = VisualFeatures(
        averageHashHex: 'ffffffff00000000',
        differenceHashHex: 'aaaaaaaa55555555',
        centerAverageHashHex: 'ffffffff00000000',
        centerDifferenceHashHex: 'aaaaaaaa55555555',
      );

      final score = ConfidenceScore.calculateConfidence(
        query,
        catalog,
        ConfidenceType.specialized,
      );

      expect(score, greaterThan(95.0));
    });

    test('hammingDistance is zero for identical hashes', () {
      expect(
        ConfidenceScore.hammingDistance('ffffffffffffffff', 'ffffffffffffffff'),
        0,
      );
    });
  });
}
