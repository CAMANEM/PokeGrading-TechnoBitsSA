/// @file
/// @brief Barrel export for card image preprocessing module.
///
/// This module provides perspective detection, correction, color
/// normalization, and ROI segmentation for Pokémon card images.
/// It detects the card contour, applies a perspective transformation,
/// normalizes color, and extracts grading regions of interest.

export 'preprocessing_models.dart';
export 'card_contour_detector.dart';
export 'color_normalizer.dart';
export 'perspective_transform.dart';
export 'roi_segmenter.dart';
export 'preprocessing_service.dart';
