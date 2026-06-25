/// @file
/// @brief Barrel export for card image preprocessing module.
///
/// This module provides perspective detection, correction, and color
/// normalization for Pokémon card images. It detects the card contour,
/// applies a perspective transformation, and normalizes color to
/// standardize capture conditions.

export 'preprocessing_models.dart';
export 'card_contour_detector.dart';
export 'color_normalizer.dart';
export 'perspective_transform.dart';
export 'preprocessing_service.dart';
