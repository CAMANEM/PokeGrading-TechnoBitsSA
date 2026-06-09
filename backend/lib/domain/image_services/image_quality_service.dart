/// @file
/// @brief

import 'dart:convert';
import 'package:image/image.dart' as img;

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
  static img.Image decodeImageData(String imageData) {
    final base64Part = imageData.split(',').last;

    final bytes = base64Decode(base64Part);

    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Invalid image');
    }

    return image;
  }

  static double calculateSharpnessScore(img.Image image) {
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

    return (((sumSq / n) - (mean * mean)) / 1000).clamp(0, 1);
  }

  static double calculateBrightnessScore(img.Image image) {
    double total = 0;
    const ideal = 140;

    for (final pixel in image) {
      total += 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
    }

    double brightness = total / (image.width * image.height);

    final diff = (brightness - ideal).abs();

    return (1 - diff / ideal).clamp(0, 1);
  }

  static ImageQualityResult calculateScore(String imageData) {
    final image = decodeImageData(imageData);

    final sharpness = calculateSharpnessScore(image); // 0-1
    final brightness = calculateBrightnessScore(image); // 0-1

    final overall = (sharpness + brightness) / 2;

    final sharpness100 = sharpness * 100;
    final brightness100 = brightness * 100;
    final overall100 = overall * 100;

    final reasons = <String>[];

    if (sharpness100 < 60) {
      reasons.add(
        'Image is blurry (Sharpness: ${sharpness100.toStringAsFixed(1)}/100)',
      );
    }

    if (brightness100 < 60) {
      reasons.add(
        'Image is obscure (Brightness: ${brightness100.toStringAsFixed(1)}/100)',
      );
    }

    if (overall100 < 60) {
      reasons.add(
        'Image Quality Score is below acceptance (${overall100.toStringAsFixed(1)}/100)',
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
