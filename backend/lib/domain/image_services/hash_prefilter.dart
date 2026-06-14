/// @file
/// @brief Chunk-based hash prefilter aligned with mock catalog indexing.

import 'visual_features.dart';

/// Scores how many 4-hex chunks overlap between query and catalog hashes.
int scoreHashChunkOverlap(VisualFeatures query, VisualFeatures catalog) {
  var score = 0;

  for (final pair in [
    (query.averageHashHex, catalog.averageHashHex),
    (query.differenceHashHex, catalog.differenceHashHex),
    (query.averageHashHex, catalog.backAverageHashHex),
    (query.differenceHashHex, catalog.backDifferenceHashHex),
  ]) {
    score += _scoreChunkPair(pair.$1, pair.$2);
  }

  return score;
}

int _scoreChunkPair(String? a, String? b) {
  if (a == null || b == null || a.length != 16 || b.length != 16) {
    return 0;
  }

  var hits = 0;
  for (var i = 0; i < 4; i++) {
    final start = i * 4;
    if (a.substring(start, start + 4) == b.substring(start, start + 4)) {
      hits++;
    }
  }
  return hits;
}
