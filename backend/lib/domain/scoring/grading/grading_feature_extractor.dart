/// @file
/// @brief Extracts grading features from a card image for calibration.
///
/// Takes a base64-encoded card image, runs the preprocessing pipeline,
/// and extracts raw numeric features used by BaselineCalibrator.
/// This bridges the gap between "image in" and "CardFeatures out".

import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../../image_services/preprocessing/preprocessing.dart';
import '../../image_services/grading/corner_whitening_detector.dart';
import '../../image_services/grading/edge_whitening_detector.dart';
import '../../image_services/grading/surface_scratch_detector.dart';
import 'pregrading.dart';
import 'baseline_calibrator.dart';

/// Extracts grading features from a card image.
///
/// Used during reference card creation to populate grading_features_json
/// for later calibration.
class GradingFeatureExtractor {
  /// Extracts CardFeatures from a base64-encoded card image.
  ///
  /// Runs the full preprocessing + grading pipeline and captures
  /// the raw numeric values needed for calibration.
  ///
  /// Throws if the image cannot be decoded or preprocessed.
  static CardFeatures extract(String imageData) {
    // 1. Preprocess to get ROIs
    final preprocessResult = PreprocessingService.preprocess(imageData);
    if (!preprocessResult.success || preprocessResult.rois == null) {
      throw StateError(
        'Preprocessing failed: ${preprocessResult.errorMessage}',
      );
    }

    // 2. Decode full image for centering
    final base64Part = imageData.contains(',')
        ? imageData.split(',').last
        : imageData;
    final bytes = base64Decode(base64Part);
    final fullImage = img.decodeImage(Uint8List.fromList(bytes));
    if (fullImage == null) {
      throw StateError('Failed to decode image');
    }

    // 3. Extract centering symmetry from full image
    final centeringGrade = Grading.centerGrade(fullImage);
    // Reverse the grade mapping: grade = 1.0 + symmetryScore * 9.0
    // → symmetryScore = (grade - 1.0) / 9.0
    final centeringSymmetry = ((centeringGrade - 1.0) / 9.0).clamp(0.0, 1.0);

    // 4. Extract corner whitening percentages
    final cornerImages = {
      'top_left': img.Image.from(preprocessResult.rois!.cornerTopLeft),
      'top_right': img.Image.from(preprocessResult.rois!.cornerTopRight),
      'bottom_left': img.Image.from(preprocessResult.rois!.cornerBottomLeft),
      'bottom_right': img.Image.from(preprocessResult.rois!.cornerBottomRight),
    };
    final cornerResult = CornerWhiteningDetector.analyzeAllCorners(cornerImages);
    final cornerWhiteningPercentages = cornerResult.corners
        .map((c) => c.whiteningPercentage)
        .toList();

    // 5. Extract edge whitening + straightness CV
    final edgeImages = {
      'top': img.Image.from(preprocessResult.rois!.edgeTop),
      'bottom': img.Image.from(preprocessResult.rois!.edgeBottom),
      'left': img.Image.from(preprocessResult.rois!.edgeLeft),
      'right': img.Image.from(preprocessResult.rois!.edgeRight),
    };
    final edgeResult = EdgeWhiteningDetector.analyzeAllEdges(edgeImages);
    final edgeWhiteningPercentages = edgeResult.edges
        .map((e) => e.whiteningPercentage)
        .toList();
    final edgeStraightnessCVs = edgeResult.edges
        .map((e) => e.straightnessCV)
        .toList();

    // 6. Extract surface features
    final surfaceImage = img.Image.from(preprocessResult.rois!.surface);
    final surfaceResult = SurfaceScratchDetector.analyzeSurface(surfaceImage);

    return CardFeatures(
      centeringSymmetry: centeringSymmetry,
      cornerWhiteningPercentages: cornerWhiteningPercentages,
      edgeWhiteningPercentages: edgeWhiteningPercentages,
      edgeStraightnessCVs: edgeStraightnessCVs,
      surfaceScratchDensity: surfaceResult.scratchDensity,
      surfaceUniformityCV: surfaceResult.uniformityCV,
    );
  }

  /// Extracts features and returns them as a JSON-serializable map.
  ///
  /// Convenience method for direct storage in grading_features_json column.
  static Map<String, dynamic>? extractToMap(String imageData) {
    try {
      final features = extract(imageData);
      return {
        'centering_symmetry': features.centeringSymmetry,
        'corner_whitening_percentages': features.cornerWhiteningPercentages,
        'edge_whitening_percentages': features.edgeWhiteningPercentages,
        'edge_straightness_cvs': features.edgeStraightnessCVs,
        'surface_scratch_density': features.surfaceScratchDensity,
        'surface_uniformity_cv': features.surfaceUniformityCV,
      };
    } catch (e) {
      return null;
    }
  }

  /// Converts a JSON map back to CardFeatures.
  ///
  /// Used when loading grading_features_json from the database.
  static CardFeatures? fromMap(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return CardFeatures(
        centeringSymmetry: (json['centering_symmetry'] as num?)?.toDouble() ?? 0.5,
        cornerWhiteningPercentages: (json['corner_whitening_percentages'] as List?)
            ?.map((e) => (e as num).toDouble()).toList() ?? [0, 0, 0, 0],
        edgeWhiteningPercentages: (json['edge_whitening_percentages'] as List?)
            ?.map((e) => (e as num).toDouble()).toList() ?? [0, 0, 0, 0],
        edgeStraightnessCVs: (json['edge_straightness_cvs'] as List?)
            ?.map((e) => (e as num).toDouble()).toList() ?? [0.1, 0.1, 0.1, 0.1],
        surfaceScratchDensity: (json['surface_scratch_density'] as num?)?.toDouble() ?? 0,
        surfaceUniformityCV: (json['surface_uniformity_cv'] as num?)?.toDouble() ?? 0.3,
      );
    } catch (e) {
      return null;
    }
  }
}
