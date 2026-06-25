/// @file
/// @brief Barrel export for card image preprocessing module.
///
/// This module provides perspective detection and correction for Pokémon card
/// images. It detects the card contour in the image and applies a perspective
/// transformation to align the card to a standard rectangle.

export 'preprocessing_models.dart';
export 'card_contour_detector.dart';
export 'perspective_transform.dart';
export 'preprocessing_service.dart';
