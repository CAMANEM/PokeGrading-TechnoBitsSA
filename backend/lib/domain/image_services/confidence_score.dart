/// @file
/// @brief Hamming-based confidence scoring for perceptual hash comparison.

import 'dart:math' as math;

import 'visual_features.dart';

enum ConfidenceType { fast, specialized }

/// Compares query and catalog visual features using perceptual hash similarity.
class ConfidenceScore {
  static double calculateConfidence(
    VisualFeatures query,
    VisualFeatures catalog,
    ConfidenceType type,
  ) {
    if (query.isEmpty || catalog.isEmpty) {
      return 0.0;
    }

    final frontScore = _scoreView(query, catalog.frontView(), type);
    if (!catalog.hasBack) {
      return frontScore;
    }

    final backScore = _scoreView(query, catalog.backView(), type);
    return math.max(frontScore, backScore);
  }

  static double _scoreView(
    VisualFeatures query,
    VisualFeatures catalogView,
    ConfidenceType type,
  ) {
    if (catalogView.isEmpty) return 0.0;

    switch (type) {
      case ConfidenceType.fast:
        return similarity(query, catalogView);
      case ConfidenceType.specialized:
        return specializedSimilarity(query, catalogView);
    }
  }

  static double similarity(VisualFeatures a, VisualFeatures b) {
    final scores = <double>[];

    final aHash = _optionalHashSimilarity(a.averageHashHex, b.averageHashHex);
    if (aHash != null) scores.add(aHash);

    final dHash =
        _optionalHashSimilarity(a.differenceHashHex, b.differenceHashHex);
    if (dHash != null) scores.add(dHash);

    if (scores.isEmpty) return 0.0;

    return scores.reduce((x, y) => x + y) / scores.length;
  }

  static double specializedSimilarity(VisualFeatures a, VisualFeatures b) {
    var weightedSum = 0.0;
    var weightTotal = 0.0;

    void add(double weight, double? score) {
      if (score == null) return;
      weightedSum += weight * score;
      weightTotal += weight;
    }

    final global = similarity(a, b);
    if (global > 0) {
      add(0.40, global);
    }

    add(
      0.20,
      _optionalHashSimilarity(a.centerAverageHashHex, b.centerAverageHashHex),
    );
    add(
      0.20,
      _optionalHashSimilarity(
        a.centerDifferenceHashHex,
        b.centerDifferenceHashHex,
      ),
    );
    add(0.20, _optionalHashSimilarity(a.edgeHashHex, b.edgeHashHex));

    if (weightTotal == 0) return 0.0;
    return weightedSum / weightTotal;
  }

  /// Hamming similarity summary for observability (0–100 per component).
  static Map<String, double> hammingBreakdown(
    VisualFeatures query,
    VisualFeatures catalog,
  ) {
    return {
      'ahash': _hashSimilarity(query.averageHashHex, catalog.averageHashHex),
      'dhash': _hashSimilarity(query.differenceHashHex, catalog.differenceHashHex),
      'center_ahash': _hashSimilarity(
        query.centerAverageHashHex,
        catalog.centerAverageHashHex,
      ),
      'center_dhash': _hashSimilarity(
        query.centerDifferenceHashHex,
        catalog.centerDifferenceHashHex,
      ),
      'edge': _hashSimilarity(query.edgeHashHex, catalog.edgeHashHex),
      'back_ahash': _hashSimilarity(
        query.averageHashHex,
        catalog.backAverageHashHex,
      ),
      'back_dhash': _hashSimilarity(
        query.differenceHashHex,
        catalog.backDifferenceHashHex,
      ),
    };
  }

  static double? _optionalHashSimilarity(String? a, String? b) {
    if (a == null || b == null) return null;
    return _hashSimilarity(a, b);
  }

  static double _hashSimilarity(String? a, String? b) {
    if (a == null || b == null) return 0.0;

    final distance = hammingDistance(a, b);
    return 100.0 * (1.0 - distance / 64.0);
  }

  static int hammingDistance(String hexA, String hexB) {
    final a = BigInt.parse(hexA, radix: 16);
    final b = BigInt.parse(hexB, radix: 16);
    var diff = a ^ b;
    var count = 0;

    while (diff != BigInt.zero) {
      count++;
      diff &= (diff - BigInt.one);
    }

    return count;
  }
}
