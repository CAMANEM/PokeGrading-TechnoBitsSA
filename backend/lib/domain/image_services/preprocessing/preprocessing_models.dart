/// @file
/// @brief Data models for card image preprocessing pipeline.
///
/// These models represent the results of perspective detection, correction,
/// and validation steps in the preprocessing workflow.

/// Standard dimensions for a Pokémon card in pixels at 300 DPI.
/// Card size: 63.5mm x 88.9mm -> 750 x 1050 pixels.
class CardDimensions {
  static const int standardWidth = 750;
  static const int standardHeight = 1050;

  /// Aspect ratio of a standard Pokémon card (width / height).
  static const double aspectRatio = standardWidth / standardHeight;
}

/// Represents a 2D point with integer coordinates.
class Point2D {
  final int x;
  final int y;

  const Point2D({required this.x, required this.y});

  @override
  String toString() => 'Point2D($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point2D && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Result of card contour detection.
///
/// Contains the detected corners of the card in the original image.
/// Corners are ordered: top-left, top-right, bottom-right, bottom-left.
class ContourDetectionResult {
  /// Whether a valid card contour was detected.
  final bool detected;

  /// The four corners of the detected card, ordered clockwise from top-left.
  /// Null if [detected] is false.
  final List<Point2D>? corners;

  /// Confidence score of the detection (0.0 - 1.0).
  /// Based on contour area, convexity, and aspect ratio.
  final double confidence;

  /// Area of the detected contour as a percentage of total image area.
  final double contourAreaRatio;

  /// Error message if detection failed.
  final String? error;

  const ContourDetectionResult({
    required this.detected,
    this.corners,
    this.confidence = 0.0,
    this.contourAreaRatio = 0.0,
    this.error,
  });

  /// Factory for successful detection.
  factory ContourDetectionResult.success({
    required List<Point2D> corners,
    required double confidence,
    required double contourAreaRatio,
  }) {
    assert(corners.length == 4, 'Card contour must have exactly 4 corners');
    return ContourDetectionResult(
      detected: true,
      corners: corners,
      confidence: confidence,
      contourAreaRatio: contourAreaRatio,
    );
  }

  /// Factory for failed detection.
  factory ContourDetectionResult.failure(String error) {
    return ContourDetectionResult(
      detected: false,
      error: error,
    );
  }
}

/// Result of perspective correction.
///
/// Contains the corrected image and metadata about the transformation.
class PerspectiveCorrectionResult {
  /// Whether the correction was successful.
  final bool success;

  /// Base64-encoded corrected image (JPEG).
  /// Null if [success] is false.
  final String? correctedImageData;

  /// The 3x3 perspective transformation matrix used.
  /// Stored as flat list: [a11, a12, a13, a21, a22, a23, a31, a32, a33].
  final List<double>? transformMatrix;

  /// The detected corners from the original image.
  final List<Point2D>? originalCorners;

  /// Processing metadata.
  final PreprocessingMetadata metadata;

  /// Error type if correction failed.
  final PreprocessingError? error;

  const PerspectiveCorrectionResult({
    required this.success,
    this.correctedImageData,
    this.transformMatrix,
    this.originalCorners,
    required this.metadata,
    this.error,
  });

  /// Factory for successful correction.
  factory PerspectiveCorrectionResult.success({
    required String correctedImageData,
    required List<double> transformMatrix,
    required List<Point2D> originalCorners,
    required PreprocessingMetadata metadata,
  }) {
    return PerspectiveCorrectionResult(
      success: true,
      correctedImageData: correctedImageData,
      transformMatrix: transformMatrix,
      originalCorners: originalCorners,
      metadata: metadata,
    );
  }

  /// Factory for failed correction.
  factory PerspectiveCorrectionResult.failure({
    required PreprocessingError error,
    required PreprocessingMetadata metadata,
  }) {
    return PerspectiveCorrectionResult(
      success: false,
      metadata: metadata,
      error: error,
    );
  }
}

/// Types of preprocessing errors.
enum PreprocessingError {
  /// No card contour could be detected in the image.
  noContourDetected,

  /// Detected contour is too small (< 10% of image area).
  contourTooSmall,

  /// Detected contour is not convex enough.
  contourNotConvex,

  /// Aspect ratio of detected contour deviates too much from standard card.
  invalidAspectRatio,

  /// Perspective distortion is too severe to correct reliably.
  irreparableDistortion,

  /// Image could not be decoded.
  invalidImage,

  /// OpenCV processing failed.
  processingFailed,
}

/// Metadata about the preprocessing operation.
class PreprocessingMetadata {
  /// Time taken for contour detection (milliseconds).
  final int detectionTimeMs;

  /// Time taken for perspective correction (milliseconds).
  final int correctionTimeMs;

  /// Total processing time (milliseconds).
  final int totalTimeMs;

  /// Version of the preprocessing algorithm.
  static const String algorithmVersion = '1.0.0';

  const PreprocessingMetadata({
    required this.detectionTimeMs,
    required this.correctionTimeMs,
    required this.totalTimeMs,
  });

  /// Creates metadata with automatic timing.
  factory PreprocessingMetadata.timed({
    required int detectionTimeMs,
    required int correctionTimeMs,
  }) {
    return PreprocessingMetadata(
      detectionTimeMs: detectionTimeMs,
      correctionTimeMs: correctionTimeMs,
      totalTimeMs: detectionTimeMs + correctionTimeMs,
    );
  }
}
