/// @file
/// @brief Region of Interest (ROI) segmentation for card images.
///
/// Extracts individual grading regions from a normalized card image:
/// - **Centering**: Central region for border symmetry measurement.
/// - **Corners**: 4 individual corner crops (TL, TR, BL, BR).
/// - **Edges**: 4 individual edge strips (top, bottom, left, right).
/// - **Surface**: Central artwork area for scratch/stain analysis.
///
/// All coordinates are proportional to the card dimensions, making
/// the segmentation adaptable to any card size.

import 'package:image/image.dart' as img;

/// Contains all extracted ROI images from a card.
///
/// Corners and edges are stored as individual images for independent
/// analysis of each region.
class RoiResult {
  /// Central region (artwork + inner borders) for centering measurement.
  final img.Image centering;

  /// Top-left corner crop.
  final img.Image cornerTopLeft;

  /// Top-right corner crop.
  final img.Image cornerTopRight;

  /// Bottom-left corner crop.
  final img.Image cornerBottomLeft;

  /// Bottom-right corner crop.
  final img.Image cornerBottomRight;

  /// Top edge strip (full width).
  final img.Image edgeTop;

  /// Bottom edge strip (full width).
  final img.Image edgeBottom;

  /// Left edge strip (between top and bottom edges).
  final img.Image edgeLeft;

  /// Right edge strip (between top and bottom edges).
  final img.Image edgeRight;

  /// Central artwork area (excludes corners and edges).
  final img.Image surface;

  const RoiResult({
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

/// Extracts grading ROIs from a standardized card image.
///
/// Expects a card image already corrected to standard dimensions
/// (750×1050 after perspective warp and color normalization).
/// All region boundaries are defined as proportions of the card size.
class RoiSegmenter {
  // --- Region proportions (fraction of card dimension) ---

  /// Centering region: 10% margin on each side (X), 8% on top/bottom (Y).
  static const double centeringMarginX = 0.10;
  static const double centeringMarginY = 0.08;

  /// Corner size: 15% of the card's shorter dimension.
  static const double cornerFraction = 0.15;

  /// Edge strip width: 10% of the corresponding card dimension.
  static const double edgeFractionX = 0.10;
  static const double edgeFractionY = 0.10;

  /// Surface region: 15% margin on sides, 12% on top/bottom.
  static const double surfaceMarginX = 0.15;
  static const double surfaceMarginY = 0.12;

  /// Extracts all ROIs from a card image.
  ///
  /// [cardImage] is the normalized card image (typically 750×1050).
  ///
  /// Returns a [RoiResult] with each region as an independent image.
  static RoiResult extract(img.Image cardImage) {
    return RoiResult(
      centering: _extractCentering(cardImage),
      cornerTopLeft: _extractCorner(cardImage, _CornerPosition.topLeft),
      cornerTopRight: _extractCorner(cardImage, _CornerPosition.topRight),
      cornerBottomLeft: _extractCorner(cardImage, _CornerPosition.bottomLeft),
      cornerBottomRight: _extractCorner(cardImage, _CornerPosition.bottomRight),
      edgeTop: _extractEdge(cardImage, _EdgePosition.top),
      edgeBottom: _extractEdge(cardImage, _EdgePosition.bottom),
      edgeLeft: _extractEdge(cardImage, _EdgePosition.left),
      edgeRight: _extractEdge(cardImage, _EdgePosition.right),
      surface: _extractSurface(cardImage),
    );
  }

  /// Extracts the centering region (central 80%×84% of the card).
  static img.Image _extractCentering(img.Image card) {
    final x = (card.width * centeringMarginX).round();
    final y = (card.height * centeringMarginY).round();
    final w = card.width - x * 2;
    final h = card.height - y * 2;

    return img.copyCrop(card, x: x, y: y, width: w, height: h);
  }

  /// Extracts a single corner crop.
  static img.Image _extractCorner(img.Image card, _CornerPosition pos) {
    final size = (card.width * cornerFraction).round();

    int x;
    int y;
    switch (pos) {
      case _CornerPosition.topLeft:
        x = 0;
        y = 0;
      case _CornerPosition.topRight:
        x = card.width - size;
        y = 0;
      case _CornerPosition.bottomLeft:
        x = 0;
        y = card.height - size;
      case _CornerPosition.bottomRight:
        x = card.width - size;
        y = card.height - size;
    }

    return img.copyCrop(card, x: x, y: y, width: size, height: size);
  }

  /// Extracts a single edge strip.
  static img.Image _extractEdge(img.Image card, _EdgePosition pos) {
    final topH = (card.height * edgeFractionY).round();
    final sideW = (card.width * edgeFractionX).round();

    switch (pos) {
      case _EdgePosition.top:
        return img.copyCrop(card, x: 0, y: 0, width: card.width, height: topH);
      case _EdgePosition.bottom:
        return img.copyCrop(
          card,
          x: 0,
          y: card.height - topH,
          width: card.width,
          height: topH,
        );
      case _EdgePosition.left:
        return img.copyCrop(
          card,
          x: 0,
          y: topH,
          width: sideW,
          height: card.height - topH * 2,
        );
      case _EdgePosition.right:
        return img.copyCrop(
          card,
          x: card.width - sideW,
          y: topH,
          width: sideW,
          height: card.height - topH * 2,
        );
    }
  }

  /// Extracts the surface region (central 70%×76% of the card).
  static img.Image _extractSurface(img.Image card) {
    final x = (card.width * surfaceMarginX).round();
    final y = (card.height * surfaceMarginY).round();
    final w = card.width - x * 2;
    final h = card.height - y * 2;

    return img.copyCrop(card, x: x, y: y, width: w, height: h);
  }
}

enum _CornerPosition { topLeft, topRight, bottomLeft, bottomRight }

enum _EdgePosition { top, bottom, left, right }
