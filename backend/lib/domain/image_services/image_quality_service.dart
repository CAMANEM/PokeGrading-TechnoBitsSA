/// @file
/// @brief

import 'dart:convert';
import 'package:image/image.dart' as img;

import '../../core/logging/app_logger.dart';

/// @brief ImageQualityResult
class ImageQualityResult {
  final double score;
  final double sharpnessScore;
  final double brightnessScore;
  final List<String> rejectionReasons;

  const ImageQualityResult({
    required this.score,
    required this.sharpnessScore,
    required this.brightnessScore,
    required this.rejectionReasons,
  });

  bool get accepted => rejectionReasons.isEmpty;
}

/// @brief ImageQualityService
class ImageQualityService {
  static const int acceptedThreshold = 60;

  static img.Image _decodeImageData(String imageData) {
    final base64Part = imageData.split(',').last;

    final bytes = base64Decode(base64Part);

    final image = img.decodeImage(bytes);

    if (image == null) {
      AppLogger.warning(
        'PokéGrading.Domain.ImageQuality',
        'Failed to decode image for quality analysis',
      );
      throw Exception('Invalid image');
    }

    return image;
  }

  static double _calculateSharpnessScore(img.Image image) {
    final gray = img.grayscale(image);

    final laplacian = img.convolution(
      gray,
      filter: [
        0,
        -1,
        0,
        -1,
        4,
        -1,
        0,
        -1,
        0,
      ],
    );

    double sum = 0;
    double sumSq = 0;

    for (final pixel in laplacian) {
      final value = pixel.r.toDouble();

      sum += value;
      sumSq += value * value;
    }

    final n = laplacian.width * laplacian.height;

    final mean = sum / n;

    final variance = (sumSq / n) - (mean * mean);

    if (variance >= 150) {
      return 1.0;
    }

    return (variance / 150).clamp(0, 1);
  }

  static double _calculateBrightnessScore(img.Image image) {
    double total = 0;
    const minAcceptance = 80;
    const maxAcceptance = 180;

    for (final pixel in image) {
      total += 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
    }

    double brightness = total / (image.width * image.height);

    if (brightness >= minAcceptance || brightness <= maxAcceptance) {
      return 1.0;
    }

    if (brightness < minAcceptance) {
      return (brightness / minAcceptance).clamp(0, 1);
    }

    return (1 - (brightness - maxAcceptance) / (255 - maxAcceptance))
        .clamp(0, 1);
  }

  static ImageQualityResult calculateScore(String imageData) {
    final image = _decodeImageData(imageData);

    final sharpness = _calculateSharpnessScore(image); // 0-1
    final brightness = _calculateBrightnessScore(image); // 0-1

    final overall = (sharpness + brightness) / 2;

    final sharpness100 = sharpness * 100;
    final brightness100 = brightness * 100;
    final overall100 = overall * 100;

    final reasons = <String>[];

    if (sharpness100 < acceptedThreshold) {
      reasons.add(
        'Imagen borrosa (Nitidez: ${sharpness100.toStringAsFixed(1)}/100)',
      );
    }

    if (brightness100 < acceptedThreshold) {
      reasons.add(
        'Imagen oscura (Brillo: ${brightness100.toStringAsFixed(1)}/100)',
      );
    }

    return ImageQualityResult(
      score: overall100,
      sharpnessScore: sharpness100,
      brightnessScore: brightness100,
      rejectionReasons: reasons,
    );
  }
}
