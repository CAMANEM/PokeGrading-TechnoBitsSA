/// @file
/// @brief Color normalization for card images using pure Dart.
///
/// Applies automatic white balance (gray world assumption) and histogram
/// stretching to standardize capture conditions. Operates on the corrected
/// card image (after perspective warp) to produce consistent color output.

import 'package:image/image.dart' as img;

/// Normalizes color of a card image to a consistent baseline.
///
/// Uses a two-step pipeline:
/// 1. **White balance** via gray world assumption — equalizes the average
///    of each color channel to remove color casts from lighting.
/// 2. **Histogram stretch** — stretches the dynamic range per-channel
///    in HSL space (preserving hue) to standardize contrast.
///
/// The input image is not modified; a new image is returned.
class ColorNormalizer {
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

  /// Applies white balance using the gray world assumption.
  ///
  /// The gray world algorithm assumes that the average color of the scene
  /// should be neutral gray. It computes per-channel scale factors based on
  /// the deviation of each channel's mean from the overall mean, then
  /// applies those factors to every pixel.
  ///
  /// This corrects color casts caused by:
  /// - Warm/cool lighting (incandescent vs daylight)
  /// - Colored reflections from nearby surfaces
  /// - Camera white balance miscalibration
  static img.Image _whiteBalance(img.Image image) {
    final w = image.width;
    final h = image.height;
    final totalPixels = w * h;

    // Accumulate per-channel sums using integer arithmetic to avoid overflow.
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

    // Overall mean — the "gray" target.
    final avgAll = (avgR + avgG + avgB) / 3;

    // Scale factors: how much each channel needs to shift toward gray.
    // Avoid division by zero for fully black images.
    final scaleR = avgR > 0 ? avgAll / avgR : 1.0;
    final scaleG = avgG > 0 ? avgAll / avgG : 1.0;
    final scaleB = avgB > 0 ? avgAll / avgB : 1.0;

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

  /// Stretches the histogram to use the full dynamic range.
  ///
  /// Operates in HSL color space to preserve hue while stretching the
  /// luminance (L) channel. Clips the extreme 1.5% of intensities on
  /// each end to avoid outliers dominating the stretch.
  static img.Image _histogramStretch(img.Image image) {
    return img.histogramStretch(
      image,
      mode: img.HistogramEqualizeMode.color,
    );
  }
}
