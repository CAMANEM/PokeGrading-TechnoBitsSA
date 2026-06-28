/// @file
/// @brief Facade for card image preprocessing pipeline.
///
/// This is the main entry point for perspective detection and correction.
/// It orchestrates the contour detection and perspective transformation
/// steps, returning a unified result for the evaluation pipeline.

import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../../../core/logging/app_logger.dart';
import 'preprocessing_models.dart';
import 'card_contour_detector.dart';
import 'color_normalizer.dart';
import 'perspective_transform.dart';
import 'roi_segmenter.dart';

/// Result of the complete preprocessing pipeline.
///
/// Contains the corrected image (if successful), extracted ROIs,
/// and metadata about the processing steps.
class PreprocessingResult {
  /// Whether preprocessing was successful.
  final bool success;

  /// Base64-encoded corrected image (JPEG).
  /// Null if preprocessing failed.
  final String? correctedImageData;

  /// Extracted ROI regions (centering, corners, edges, surface).
  /// Null if ROI extraction failed or was not performed.
  final RoiResult? rois;

  /// Base64-encoded ROI images for JSON serialization.
  final RoiData? roiData;

  /// Error information if preprocessing failed.
  final PreprocessingError? error;

  /// Human-readable error message.
  final String? errorMessage;

  /// Processing metadata.
  final PreprocessingMetadata metadata;

  /// Detected corners from the original image.
  final List<Point2D>? detectedCorners;

  const PreprocessingResult({
    required this.success,
    this.correctedImageData,
    this.rois,
    this.roiData,
    this.error,
    this.errorMessage,
    required this.metadata,
    this.detectedCorners,
  });

  /// Creates a successful result.
  factory PreprocessingResult.success({
    required String correctedImageData,
    required PreprocessingMetadata metadata,
    required List<Point2D> detectedCorners,
    RoiResult? rois,
    RoiData? roiData,
  }) {
    return PreprocessingResult(
      success: true,
      correctedImageData: correctedImageData,
      metadata: metadata,
      detectedCorners: detectedCorners,
      rois: rois,
      roiData: roiData,
    );
  }

  /// Creates a failed result.
  factory PreprocessingResult.failure({
    required PreprocessingError error,
    required String errorMessage,
    required PreprocessingMetadata metadata,
  }) {
    return PreprocessingResult(
      success: false,
      error: error,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }
}

/// Base64-encoded ROI images for JSON serialization.
class RoiData {
  final String centering;
  final String cornerTopLeft;
  final String cornerTopRight;
  final String cornerBottomLeft;
  final String cornerBottomRight;
  final String edgeTop;
  final String edgeBottom;
  final String edgeLeft;
  final String edgeRight;
  final String surface;

  const RoiData({
    required this.centering,
    required this.cornerTopLeft,
    required this.cornerTopRight,
    required this.cornerBottomLeft,
    required this.cornerBottomRight,
    required this.edgeTop,
    required this.edgeBottom,
    required this.edgeLeft,
    required this.edgeRight,
    required this.surface,
  });
}

/// Main service for card image preprocessing.
///
/// Usage:
/// ```dart
/// final result = PreprocessingService.preprocess(imageData);
/// if (result.success) {
///   // Use result.correctedImageData for further processing
/// } else {
///   // Handle error: result.error, result.errorMessage
/// }
/// ```
class PreprocessingService {
  static const _loggerName = 'PokéGrading.Preprocessing';

  /// Preprocesses a card image: detects contour and corrects perspective.
  ///
  /// [imageData] is a base64-encoded image (with or without data URL prefix).
  ///
  /// Returns a [PreprocessingResult] with the corrected image or error info.
  static PreprocessingResult preprocess(String imageData) {
    final stopwatch = Stopwatch()..start();

    try {
      // Decode image
      final image = _decodeImage(imageData);
      if (image == null) {
        stopwatch.stop();
        return PreprocessingResult.failure(
          error: PreprocessingError.invalidImage,
          errorMessage: 'Could not decode image data',
          metadata: PreprocessingMetadata.timed(
            detectionTimeMs: 0,
            correctionTimeMs: 0,
          ),
        );
      }

      // Detect contour
      final detectionStart = Stopwatch()..start();
      final contourResult = CardContourDetector.detect(image);
      detectionStart.stop();

      if (!contourResult.detected || contourResult.corners == null) {
        stopwatch.stop();
        AppLogger.info(
          _loggerName,
          'Card contour not detected',
          context: {'error': contourResult.error},
        );
        return PreprocessingResult.failure(
          error: _mapContourError(contourResult.error),
          errorMessage: contourResult.error ?? 'Contour detection failed',
          metadata: PreprocessingMetadata.timed(
            detectionTimeMs: detectionStart.elapsedMilliseconds,
            correctionTimeMs: 0,
          ),
        );
      }

      // Correct perspective
      final correctionStart = Stopwatch()..start();
      final correctionResult = PerspectiveTransformer.correct(
        image,
        contourResult.corners!,
      );
      correctionStart.stop();

      stopwatch.stop();

      if (!correctionResult.success) {
        AppLogger.info(
          _loggerName,
          'Perspective correction failed',
          context: {'error': correctionResult.error?.name},
        );
        return PreprocessingResult.failure(
          error: correctionResult.error ?? PreprocessingError.processingFailed,
          errorMessage: 'Perspective correction failed',
          metadata: PreprocessingMetadata.timed(
            detectionTimeMs: detectionStart.elapsedMilliseconds,
            correctionTimeMs: correctionStart.elapsedMilliseconds,
          ),
        );
      }

      // NOTE: Forward transform matrix validation removed because the
      // forward matrix maps source (original) to destination (output) and
      // always has large values due to scaling. Contour detection already
      // validates the card shape.

      // Normalize color (white balance + histogram stretch)
      final normalizationStart = Stopwatch()..start();
      final cardImage = img.decodeImage(
        Uint8List.fromList(base64Decode(correctionResult.correctedImageData!)),
      );
      String finalImageData;
      img.Image? normalizedImage;
      if (cardImage != null) {
        // Log decoded dimensions for debugging
        AppLogger.info(
          _loggerName,
          'Decoded corrected image',
          context: {
            'width': cardImage.width,
            'height': cardImage.height,
            'numChannels': cardImage.numChannels,
          },
        );

        // If decoded dimensions differ from standard, resize to standard.
        // This can happen when JPEG encode/decode pads to block boundaries.
        img.Image sizedCardImage = cardImage;
        if (cardImage.width != CardDimensions.standardWidth ||
            cardImage.height != CardDimensions.standardHeight) {
          AppLogger.info(
            _loggerName,
            'Image dimensions differ from standard, resizing before normalization',
            context: {
              'decoded_width': cardImage.width,
              'decoded_height': cardImage.height,
              'target_width': CardDimensions.standardWidth,
              'target_height': CardDimensions.standardHeight,
            },
          );
          sizedCardImage = img.copyResize(
            cardImage,
            width: CardDimensions.standardWidth,
            height: CardDimensions.standardHeight,
            interpolation: img.Interpolation.linear,
          );
        }

        normalizedImage = ColorNormalizer.normalize(sizedCardImage);

        // Ensure normalized image has standard dimensions (defense in depth)
        if (normalizedImage.width != CardDimensions.standardWidth ||
            normalizedImage.height != CardDimensions.standardHeight) {
          AppLogger.info(
            _loggerName,
            'Normalized image has non-standard dimensions, resizing',
            context: {
              'norm_width': normalizedImage.width,
              'norm_height': normalizedImage.height,
            },
          );
          normalizedImage = img.copyResize(
            normalizedImage,
            width: CardDimensions.standardWidth,
            height: CardDimensions.standardHeight,
            interpolation: img.Interpolation.linear,
          );
        }

        final normalizedJpeg = img.encodeJpg(normalizedImage, quality: 95);
        finalImageData = base64Encode(normalizedJpeg);
      } else {
        // Fallback: use un-normalized image if decode fails.
        finalImageData = correctionResult.correctedImageData!;
      }
      normalizationStart.stop();

      // Extract ROIs (centering, corners, edges, surface)
      final segmentationStart = Stopwatch()..start();
      RoiResult? rois;
      RoiData? roiData;
      if (normalizedImage != null) {
        AppLogger.info(
          _loggerName,
          'Extracting ROIs from image',
          context: {
            'width': normalizedImage.width,
            'height': normalizedImage.height,
            'numChannels': normalizedImage.numChannels,
          },
        );
        try {
          rois = RoiSegmenter.extract(normalizedImage);
          roiData = RoiData(
            centering: base64Encode(img.encodeJpg(rois.centering, quality: 95)),
            cornerTopLeft: base64Encode(img.encodeJpg(rois.cornerTopLeft, quality: 95)),
            cornerTopRight: base64Encode(img.encodeJpg(rois.cornerTopRight, quality: 95)),
            cornerBottomLeft: base64Encode(img.encodeJpg(rois.cornerBottomLeft, quality: 95)),
            cornerBottomRight: base64Encode(img.encodeJpg(rois.cornerBottomRight, quality: 95)),
            edgeTop: base64Encode(img.encodeJpg(rois.edgeTop, quality: 95)),
            edgeBottom: base64Encode(img.encodeJpg(rois.edgeBottom, quality: 95)),
            edgeLeft: base64Encode(img.encodeJpg(rois.edgeLeft, quality: 95)),
            edgeRight: base64Encode(img.encodeJpg(rois.edgeRight, quality: 95)),
            surface: base64Encode(img.encodeJpg(rois.surface, quality: 95)),
          );
        } catch (e, stack) {
          AppLogger.error(
            _loggerName,
            'ROI extraction failed',
            error: e,
            stackTrace: stack,
            context: {
              'image_width': normalizedImage.width,
              'image_height': normalizedImage.height,
              'image_numChannels': normalizedImage.numChannels,
            },
          );
        }
      }
      segmentationStart.stop();

      AppLogger.info(
        _loggerName,
        'Card preprocessing successful',
        context: {
          'confidence': contourResult.confidence.toStringAsFixed(3),
          'area_ratio': contourResult.contourAreaRatio.toStringAsFixed(3),
          'detection_ms': detectionStart.elapsedMilliseconds,
          'correction_ms': correctionStart.elapsedMilliseconds,
          'normalization_ms': normalizationStart.elapsedMilliseconds,
          'segmentation_ms': segmentationStart.elapsedMilliseconds,
        },
      );

      return PreprocessingResult.success(
        correctedImageData: finalImageData,
        metadata: PreprocessingMetadata.timed(
          detectionTimeMs: detectionStart.elapsedMilliseconds,
          correctionTimeMs: correctionStart.elapsedMilliseconds,
          normalizationTimeMs: normalizationStart.elapsedMilliseconds,
          segmentationTimeMs: segmentationStart.elapsedMilliseconds,
        ),
        detectedCorners: contourResult.corners!,
        rois: rois,
        roiData: roiData,
      );
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.error(
        _loggerName,
        'Preprocessing pipeline failed unexpectedly',
        error: e,
        stackTrace: stack,
      );
      return PreprocessingResult.failure(
        error: PreprocessingError.processingFailed,
        errorMessage: 'Unexpected error: ${e.toString()}',
        metadata: PreprocessingMetadata.timed(
          detectionTimeMs: 0,
          correctionTimeMs: 0,
        ),
      );
    }
  }

  /// Decodes a base64 image string into an image.
  static img.Image? _decodeImage(String imageData) {
    try {
      final base64Part =
          imageData.contains(',') ? imageData.split(',').last : imageData;
      final bytes = base64Decode(base64Part);
      return img.decodeImage(Uint8List.fromList(bytes));
    } catch (e) {
      return null;
    }
  }

  /// Maps contour detection error messages to PreprocessingError types.
  static PreprocessingError _mapContourError(String? error) {
    if (error == null) return PreprocessingError.noContourDetected;
    if (error.contains('area ratio')) return PreprocessingError.contourTooSmall;
    if (error.contains('not convex')) return PreprocessingError.contourNotConvex;
    if (error.contains('corners')) return PreprocessingError.invalidAspectRatio;
    if (error.contains('No contours')) {
      return PreprocessingError.noContourDetected;
    }
    return PreprocessingError.noContourDetected;
  }
}
