/// @file
/// @brief Color-aware perceptual hashing for Pokémon card images.
///
/// Hashes are computed independently per RGB channel and concatenated into
/// a single 192-bit (48 hex char) value. This preserves chromatic information
/// that pure grayscale hashing discards, so visually distinct cards (e.g.
/// Psyduck vs Fuecoco) no longer collide under similar luminance patterns.

import 'dart:convert';
import 'package:image/image.dart' as img;

/// Bundle of perceptual hashes describing a single card image.
///
/// Every populated hash uses the 48 hex char multichannel format described
/// in [VisualFeatureExtractor].
class VisualFeatures {
  final String? averageHashHex;
  final String? differenceHashHex;
  final String? centerAverageHashHex;
  final String? centerDifferenceHashHex;
  final String? edgeHashHex;

  const VisualFeatures({
    this.averageHashHex,
    this.differenceHashHex,
    this.centerAverageHashHex,
    this.centerDifferenceHashHex,
    this.edgeHashHex,
  });

  bool get isEmpty => averageHashHex == null && differenceHashHex == null;
}

/// Extracts color-aware perceptual hashes from card images.
///
/// Format:
/// - Each of the R, G, B channels yields its own 64-bit hash (16 hex chars).
/// - The three channel hashes are concatenated in R|G|B order into a single
///   192-bit value rendered as [multiChannelHashHexLength] hex chars.
/// - This applies to average hash (aHash), difference hash (dHash) and the
///   edge hash, which is computed on a Sobel-filtered image whose channels
///   are equal, but is kept in the same 48-char shape for uniform storage and
///   length-aware similarity comparisons.
class VisualFeatureExtractor {
  /// Number of hex characters produced by a single-channel 64-bit hash.
  static const int channelHashHexLength = 16;

  /// Channels combined per multichannel hash (R, G, B).
  static const int channelCount = 3;

  /// Number of hex characters produced by a multichannel hash
  /// (`channelCount * channelHashHexLength` = 48).
  static const int multiChannelHashHexLength =
      channelCount * channelHashHexLength;

  /// Per-channel pixel accessors used to drive multichannel hashing.
  ///
  /// Order is significant: it defines how the resulting bits are packed
  /// (R first, then G, then B) so any two hashes are bit-comparable.
  static final List<num Function(img.Pixel)> _channels = [
    (p) => p.r,
    (p) => p.g,
    (p) => p.b,
  ];

  /// Decodes the image and extracts all hashes. Returns an empty
  /// [VisualFeatures] when the payload cannot be decoded.
  static VisualFeatures extract(String imageData) {
    final image = _decodeImage(imageData);

    if (image == null) {
      return const VisualFeatures();
    }

    return extractFromImage(image);
  }

  /// Extracts all hashes from an already-decoded image. Convenience entry
  /// point used by tests and callers that already hold a decoded image.
  static VisualFeatures extractFromImage(img.Image image) {
    final center = _centerCrop(image);

    return VisualFeatures(
      averageHashHex: _computeAverageHash(image),
      differenceHashHex: _computeDifferenceHash(image),
      centerAverageHashHex: _computeAverageHash(center),
      centerDifferenceHashHex: _computeDifferenceHash(center),
      edgeHashHex: _computeEdgeHash(image),
    );
  }

  /// Crops the central 50% of the image (used to focus aHash/dHash on the
  /// card artwork and reduce border/background noise).
  static img.Image _centerCrop(img.Image image) {
    return img.copyCrop(
      image,
      x: image.width ~/ 4,
      y: image.height ~/ 4,
      width: image.width ~/ 2,
      height: image.height ~/ 2,
    );
  }

  /// Multichannel average hash (aHash). For each RGB channel, the image is
  /// resized to 8x8, each pixel is set to 1 if its channel value is >= the
  /// channel average and to 0 otherwise. The three 64-bit channel hashes are
  /// concatenated R|G|B into a single 192-bit value.
  static String _computeAverageHash(img.Image image) {
    final resized = img.copyResize(image, width: 8, height: 8);

    final channelHashes = _channels
        .map((channel) => _averageHashForChannel(resized, channel))
        .toList(growable: false);

    return _concatChannelHashes(channelHashes);
  }

  /// Multichannel difference hash (dHash). For each RGB channel, the image
  /// is resized to 9x8 and each bit encodes whether the left pixel's channel
  /// value is greater than its right neighbor's. The three 64-bit channel
  /// hashes are concatenated R|G|B into a single 192-bit value.
  static String _computeDifferenceHash(img.Image image) {
    final resized = img.copyResize(image, width: 9, height: 8);

    final channelHashes = _channels
        .map((channel) => _differenceHashForChannel(resized, channel))
        .toList(growable: false);

    return _concatChannelHashes(channelHashes);
  }

  /// Edge hash: aHash over a Sobel-filtered image. The Sobel output is
  /// grayscale (R=G=B), so the multichannel form yields three identical
  /// 64-bit segments. We keep the 48-char shape so all hashes share the same
  /// length and similarity arithmetic.
  static String _computeEdgeHash(img.Image image) {
    final edges = img.sobel(image);

    return _computeAverageHash(edges);
  }

  /// Computes the 64-bit aHash of a single channel on an 8x8 image.
  static BigInt _averageHashForChannel(
    img.Image resized,
    num Function(img.Pixel) channel,
  ) {
    int total = 0;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        total += channel(resized.getPixel(x, y)).toInt();
      }
    }

    final average = total / 64.0;

    BigInt hash = BigInt.zero;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        hash <<= 1;

        if (channel(resized.getPixel(x, y)) >= average) {
          hash |= BigInt.one;
        }
      }
    }

    return hash;
  }

  /// Computes the 64-bit dHash of a single channel on a 9x8 image.
  static BigInt _differenceHashForChannel(
    img.Image resized,
    num Function(img.Pixel) channel,
  ) {
    BigInt hash = BigInt.zero;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        hash <<= 1;

        final left = channel(resized.getPixel(x, y)).toInt();
        final right = channel(resized.getPixel(x + 1, y)).toInt();

        if (left > right) {
          hash |= BigInt.one;
        }
      }
    }

    return hash;
  }

  /// Concatenates per-channel hashes into a single hex string of fixed
  /// length `channelHashes.length * channelHashHexLength`. The first channel
  /// occupies the most significant bits.
  static String _concatChannelHashes(List<BigInt> channelHashes) {
    BigInt combined = BigInt.zero;

    for (final h in channelHashes) {
      combined = (combined << 64) | h;
    }

    return combined.toRadixString(16).padLeft(
          channelHashes.length * channelHashHexLength,
          '0',
        );
  }

  /// Decodes a raw or data-URL Base64 string into an image. Returns null on
  /// any decoding failure (caller treats this as "no features available").
  static img.Image? _decodeImage(
    String imageData,
  ) {
    try {
      final base64Part =
          imageData.contains(',') ? imageData.split(',').last : imageData;

      final bytes = base64Decode(base64Part);

      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }
}
