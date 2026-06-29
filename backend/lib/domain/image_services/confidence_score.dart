/// @file
/// @brief

import 'visual_features.dart';

enum ConfidenceType { fast, specialized }

/// @brief ConfidenceScore
class ConfidenceScore {
  static const double _globalProportion = 0.40;
  static const double _complementaryProportion = 0.20;
  static double calculateConfidence(
      VisualFeatures a, VisualFeatures b, ConfidenceType type) {
    if (a.isEmpty || b.isEmpty) {
      return 0.0;
    }

    switch (type) {
      case ConfidenceType.fast:
        return similarity(
          a,
          b,
        );
      case ConfidenceType.specialized:
        return specializedSimilarity(a, b);
    }
  }

  static double similarity(
    VisualFeatures a,
    VisualFeatures b,
  ) {
    final scores = <double>[];

    if (a.averageHashHex != null && b.averageHashHex != null) {
      scores.add(
        _hashSimilarity(
          a.averageHashHex,
          b.averageHashHex,
        ),
      );
    }

    if (a.differenceHashHex != null && b.differenceHashHex != null) {
      scores.add(
        _hashSimilarity(
          a.differenceHashHex,
          b.differenceHashHex,
        ),
      );
    }

    if (scores.isEmpty) {
      return 0.0;
    }

    return scores.reduce((a, b) => a + b) / scores.length;
  }

  static double specializedSimilarity(
    VisualFeatures a,
    VisualFeatures b,
  ) {
    final global = similarity(a, b);

    final centerAHash = _hashSimilarity(
      a.centerAverageHashHex,
      b.centerAverageHashHex,
    );

    final centerDHash = _hashSimilarity(
      a.centerDifferenceHashHex,
      b.centerDifferenceHashHex,
    );

    final edge = _hashSimilarity(
      a.edgeHashHex,
      b.edgeHashHex,
    );

    return global * _globalProportion +
        centerAHash * _complementaryProportion +
        centerDHash * _complementaryProportion +
        edge * _complementaryProportion;
  }

  /// Compares two hex-encoded perceptual hashes and returns a similarity
  /// score in `[0, 100]`. The denominator scales with the hash size, so this
  /// works transparently for the 192-bit multichannel hashes produced by
  /// [VisualFeatureExtractor] (48 hex chars) as well as any legacy 64-bit
  /// hash. Hashes of different lengths are not bit-comparable and return 0.
  static double _hashSimilarity(
    String? a,
    String? b,
  ) {
    if (a == null || b == null || a.length != b.length) {
      return 0.0;
    }

    final distance = _hammingDistance(a, b);
    final bits = a.length * 4;

    return 100.0 * (1.0 - distance / bits);
  }

  static int _hammingDistance(
    String hexA,
    String hexB,
  ) {
    final a = BigInt.parse(hexA, radix: 16);
    final b = BigInt.parse(hexB, radix: 16);

    BigInt diff = a ^ b;

    int count = 0;

    while (diff != BigInt.zero) {
      count++;

      diff &= (diff - BigInt.one);
    }

    return count;
  }
}
