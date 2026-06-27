import 'dart:math';

import '../../image_services/preprocessing/roi_segmenter.dart';
import 'dimension_analyzer.dart';
import 'package:image/image.dart' as img;
import '../scoring_models.dart';

class Grading {
  static double centerGrade(img.Image centerImage) {
    final sobel = img.sobel(centerImage);
    final gray = img.grayscale(sobel);

    final leftMargin = DimensionAnalyzer.findLeftBorder(gray);
    final rightMargin =
        gray.width - DimensionAnalyzer.findRightBorder(gray) - 1;
    final topMargin = DimensionAnalyzer.findTopBorder(gray);
    final bottomMargin = DimensionAnalyzer.findBottomBorder(gray);

    double horizontal =
        min(leftMargin, rightMargin) / max(leftMargin, rightMargin);
    double vertical =
        min(topMargin, bottomMargin) / max(topMargin, bottomMargin);

    final score = (horizontal + vertical) / 2.0;
    return 1 + score * 9 / 100;
  }

  static double cornerGrade(List<img.Image> corners) {
    double result = 0;
    for (final corner in corners) {
      final score = (100 - DimensionAnalyzer.whiteExposure(corner));
      final normalized = 1 + score * 9 / 100;
      result += normalized / corners.length;
    }

    return result;
  }

  static GradingResult subgrades(RoiResult roi) {
    final subgrades = <double>[];

    subgrades.add(centerGrade(roi.centering));
    subgrades.add(cornerGrade([
      roi.cornerTopLeft,
      roi.cornerTopRight,
      roi.cornerBottomLeft,
      roi.cornerBottomRight
    ]));

    double avg = 0;
    for (int i = 0; i < subgrades.length; i++) {
      avg += subgrades[i] / subgrades.length;
    }
    return GradingResult(
        centerGrade: subgrades[0],
        cornersGrade: subgrades[1],
        edgesGrade: 0,
        surfaceGrade: 0,
        finalGrade: avg);
  }
}
