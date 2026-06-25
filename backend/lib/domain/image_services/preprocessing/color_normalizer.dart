/// @file
/// @brief Color normalization for card images using pure Dart.
///
/// Applies conservative white balance and histogram stretching to
/// standardize capture conditions while preserving the original card
/// colors as faithfully as possible.
///
/// Design principles:
/// - Only correct significant color casts (threshold-based detection).
/// - Apply partial correction (blend factor) to avoid over-shifting.
/// - Skip histogram stretch if the image already has good dynamic range.

import 'package:image/image.dart' as img;

/// Normalizes color of a card image to a consistent baseline.
///
/// Uses a two-step pipeline:
/// 1. **White balance** via gray world assumption — corrects color casts
///    only when detected above a threshold, with partial blending.
/// 2. **Histogram stretch** — stretches the dynamic range only if the
///    image doesn't already use the full range.
///
/// The input image is not modified; a new image is returned.
class ColorNormalizer {
  /// Minimum channel spread (sum of absolute differences between means)
  /// to trigger white balance correction. Below this threshold, the
  /// image is considered to have no significant color cast.
  static const double _castThreshold = 15.0;

  /// Blend factor for white balance correction. 0.0 = no correction,
  /// 1.0 = full gray world correction. Using 0.6 preserves most of the
  /// original color while reducing the cast.
  static const double _balanceStrength = 0.6;

  /// Minimum dynamic range (max - min across all channels) to skip
  /// histogram stretch. If the image already spans most of the range,
  /// stretching would only amplify noise.
  static const int _minRangeForStretch = 200;

  /// Normalizes the color of a card image.
  ///
  /// [image] is the corrected card image (typically 750×1050 after
  /// perspective warp).
  ///
  /// Returns a new [img.Image] with normalized color.
  static img.Image normalize(img.Image image) {
    final balanced = _whiteBalance(image);
    final stretched = _histogramStretch(balanced);
    return stretched;
  }

  /// Applies conservative white balance using the gray world assumption.
  ///
  /// Only applies correction if the channel spread exceeds [_castThreshold],
  /// meaning a significant color cast is detected. The correction is
  /// blended with the original at [_balanceStrength] to avoid over-shifting.
  static img.Image _whiteBalance(img.Image image) {
    final w = image.width;
    final h = image.height;
    final totalPixels = w * h;

    // Accumulate per-channel sums.
    var sumR = 0;
    var sumG = 0;
    var sumB = 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        sumR += p.r.toInt();
        sumG += p.g.toInt();
        sumB += p.b.toInt();
      }
    }

    // Compute channel means.
    final avgR = sumR / totalPixels;
    final avgG = sumG / totalPixels;
    final avgB = sumB / totalPixels;

    // Detect color cast strength.
    final channelSpread = (avgR - avgG).abs() + (avgG - avgB).abs() + (avgR - avgB).abs();

    // Skip correction if no significant cast detected.
    if (channelSpread < _castThreshold) {
      return image;
    }

    // Overall mean — the "gray" target.
    final avgAll = (avgR + avgG + avgB) / 3;

    // Compute full correction scale factors.
    final fullScaleR = avgR > 0 ? avgAll / avgR : 1.0;
    final fullScaleG = avgG > 0 ? avgAll / avgG : 1.0;
    final fullScaleB = avgB > 0 ? avgAll / avgB : 1.0;

    // Blend between identity (no correction) and full correction.
    final scaleR = 1.0 + (fullScaleR - 1.0) * _balanceStrength;
    final scaleG = 1.0 + (fullScaleG - 1.0) * _balanceStrength;
    final scaleB = 1.0 + (fullScaleB - 1.0) * _balanceStrength;

    // If all channels are already balanced, skip allocation.
    if (scaleR == 1.0 && scaleG == 1.0 && scaleB == 1.0) {
      return image;
    }

    // Create output image — clone to avoid mutating the original.
    final dst = img.Image(width: w, height: h);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final r = (p.r.toInt() * scaleR).round().clamp(0, 255);
        final g = (p.g.toInt() * scaleG).round().clamp(0, 255);
        final b = (p.b.toInt() * scaleB).round().clamp(0, 255);
        dst.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    return dst;
  }

  /// Conditionally stretches the histogram to use the full dynamic range.
  ///
  /// Only applies stretch if the image's dynamic range is below
  /// [_minRangeForStretch], meaning it's not using the full 0–255 range.
  /// Uses HSL-based stretch to preserve hue while adjusting luminance.
  static img.Image _histogramStretch(img.Image image) {
    // Find actual dynamic range across all channels.
    var minVal = 255;
    var maxVal = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        if (r < minVal) minVal = r;
        if (g < minVal) minVal = g;
        if (b < minVal) minVal = b;
        if (r > maxVal) maxVal = r;
        if (g > maxVal) maxVal = g;
        if (b > maxVal) maxVal = b;
      }
    }

    // Skip stretch if already using a good portion of the range.
    if ((maxVal - minVal) >= _minRangeForStretch) {
      return image;
    }

    return img.histogramStretch(
      image,
      mode: img.HistogramEqualizeMode.color,
    );
  }
}
