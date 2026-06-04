import 'visual_features.dart';

class ConfidenceScore {
  final VisualFeatureExtractor _extractor;

  const ConfidenceScore() : _extractor = const VisualFeatureExtractor();

  double similarity(
    String imageDataA,
    String imageDataB,
  ) {
    final featuresA = _extractor.extract(imageDataA);

    final featuresB = _extractor.extract(imageDataB);

    if (featuresA.isEmpty || featuresB.isEmpty) {
      return 0.0;
    }

    return _extractor.similarity(
      featuresA,
      featuresB,
    );
  }

  double similarityAgainstFeatures(
    VisualFeatures features,
    String imageData,
  ) {
    return _extractor.similarityWithStored(
      features,
      imageData,
    );
  }

  double similarityBetweenFeatures(
    VisualFeatures a,
    VisualFeatures b,
  ) {
    return _extractor.similarity(
      a,
      b,
    );
  }

  double specializedSimilarityBetweenFeatures(
    VisualFeatures a,
    VisualFeatures b,
  ) {
    return _extractor.specializedSimilarity(
      a,
      b,
    );
  }
}
