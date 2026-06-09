/// @file
/// @brief

import 'visual_features.dart';

/// @brief ConfidenceScore
class ConfidenceScore {
  static double similarity(
    String imageDataA,
    String imageDataB,
  ) {
    final featuresA = VisualFeatureExtractor.extract(imageDataA);

    final featuresB = VisualFeatureExtractor.extract(imageDataB);

    if (featuresA.isEmpty || featuresB.isEmpty) {
      return 0.0;
    }

    return VisualFeatureExtractor.similarity(
      featuresA,
      featuresB,
    );
  }

  static double similarityAgainstFeatures(
    VisualFeatures features,
    String imageData,
  ) {
    return VisualFeatureExtractor.similarityWithStored(
      features,
      imageData,
    );
  }

  static double similarityBetweenFeatures(
    VisualFeatures a,
    VisualFeatures b,
  ) {
    return VisualFeatureExtractor.similarity(
      a,
      b,
    );
  }

  static double specializedSimilarityBetweenFeatures(
    VisualFeatures a,
    VisualFeatures b,
  ) {
    return VisualFeatureExtractor.specializedSimilarity(
      a,
      b,
    );
  }
}
