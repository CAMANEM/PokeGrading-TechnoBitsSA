import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/image_services/hash_prefilter.dart';
import 'package:pokegrading_backend/domain/image_services/visual_features.dart';

void main() {
  group('scoreHashChunkOverlap', () {
    test('scores higher when more chunks match', () {
      const query = VisualFeatures(
        averageHashHex: 'abcd1234ef567890',
        differenceHashHex: '0000000000000000',
      );

      const closeCatalog = VisualFeatures(
        averageHashHex: 'abcd1234aaaaaaaa',
      );

      const farCatalog = VisualFeatures(
        averageHashHex: 'ffffffffffffffff',
      );

      final closeScore = scoreHashChunkOverlap(query, closeCatalog);
      final farScore = scoreHashChunkOverlap(query, farCatalog);

      expect(closeScore, greaterThan(farScore));
      expect(closeScore, greaterThan(0));
    });

    test('matches back hashes on catalog', () {
      const query = VisualFeatures(
        averageHashHex: 'abcd1234ef567890',
      );

      const catalog = VisualFeatures(
        averageHashHex: 'ffffffffffffffff',
        backAverageHashHex: 'abcd1234ef567890',
      );

      expect(scoreHashChunkOverlap(query, catalog), greaterThan(0));
    });
  });
}
