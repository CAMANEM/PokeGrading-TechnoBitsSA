import 'package:image/image.dart' as img;

class DimensionAnalyzer {
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

  static double whiteExposure(img.Image roi) {
    int white = 0;

    int total = roi.width * roi.height;

    for (final pixel in roi) {
      if (pixel.r > 230 && pixel.g > 230 && pixel.b > 230) {
        white++;
      }
    }

    return white / total;
  }
}
