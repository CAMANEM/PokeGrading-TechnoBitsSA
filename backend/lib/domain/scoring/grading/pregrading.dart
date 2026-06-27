import 'dart:math';

import '../../image_services/preprocessing/roi_segmenter.dart';
import 'package:image/image.dart' as img;

class Grading {
  static const threshold = 40;
  static int findLeftBorder(img.Image image) {
    for (int x = 0; x < image.width; x++) {
      int edgePixels = 0;
      for (int y = 0; y < image.height; y++) {
        final pixel = image.getPixel(x, y);
        if (pixel.r > threshold) {
          edgePixels++;
        }
      }

      if (edgePixels > image.height * 0.6) {
        return x;
      }
    }

    return 0;
  }

  static int findRightBorder(img.Image image) {
    for (int x = image.width; x >= 0; x--) {
      int edgePixels = 0;
      for (int y = 0; y < image.height; y++) {
        final pixel = image.getPixel(x, y);
        if (pixel.r > threshold) {
          edgePixels++;
        }
      }

      if (edgePixels > image.height * 0.6) {
        return x;
      }
    }

    return 0;
  }

  static int findTopBorder(img.Image image) {
    for (int y = 0; y < image.height; y++) {
      int edgePixels = 0;
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel.r > threshold) {
          edgePixels++;
        }
      }

      if (edgePixels > image.width * 0.6) {
        return y;
      }
    }

    return 0;
  }

  static int findBottomBorder(img.Image image) {
    for (int y = image.height; y >= 0; y--) {
      int edgePixels = 0;
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel.r > threshold) {
          edgePixels++;
        }
      }

      if (edgePixels > image.width * 0.6) {
        return y;
      }
    }

    return 0;
  }

  static double centerGrade(img.Image centerImage) {
    final sobel = img.sobel(centerImage);
    final gray = img.grayscale(sobel);

    final leftMargin = findLeftBorder(gray);
    final rightMargin = gray.width - findRightBorder(gray) - 1;
    final topMargin = findTopBorder(gray);
    final bottomMargin = findBottomBorder(gray);

    double horizontal =
        min(leftMargin, rightMargin) / max(leftMargin, rightMargin);
    double vertical =
        min(topMargin, bottomMargin) / max(topMargin, bottomMargin);

    final score = (horizontal + vertical) / 2.0;
    return 1.0 + score * 9.0;
  }

  static double subgrades(RoiResult roi) {
    return centerGrade(roi.centering);
  }
}
