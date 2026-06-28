import 'dart:math';

import '../../image_services/preprocessing/roi_segmenter.dart';
import 'dimension_analyzer.dart';
import 'package:image/image.dart' as img;
import '../scoring_models.dart';
import '../opencv_grading_service.dart';
import 'grading_rules.dart';

class Grading {
  /// Grades a submitter card against a reference card using OpenCV.
  ///
  /// Takes [submitterRois] extracted from the submitter image and
  /// [referenceRois] extracted from the reference image. Both must
  /// be preprocessed to the same standard dimensions (750x1050).
  ///
  /// Returns a [GradingResult] with subgrades, final grade, confidence,
  /// and any manual review flags.
  static GradingResult grade(
    RoiResult submitterRois,
    RoiResult referenceRois, {
    String baselineUsed = 'global_v1',
    String algorithmVersion = '1.0.0',
  }) {
    // Validate ROIs before grading
    if (!GradingRules.validateRois(submitterRois) ||
        !GradingRules.validateRois(referenceRois)) {
      return GradingResult(
        centerGrade: 0,
        cornersGrade: 0,
        edgesGrade: 0,
        surfaceGrade: 0,
        finalGrade: 0,
        confidenceScore: 0,
        uncertaintyBand: 0,
        baselineUsed: baselineUsed,
        requiresManualReview: true,
        reviewReason: 'ROIs invalidos o corruptos',
      );
    }

    final centerScore = OpenCVGradingService.scoreCentering(
      submitterRois.centering,
      referenceRois.centering,
    );

    final cornersScore = OpenCVGradingService.scoreCorners(
      [
        submitterRois.cornerTopLeft,
        submitterRois.cornerTopRight,
        submitterRois.cornerBottomLeft,
        submitterRois.cornerBottomRight,
      ],
      [
        referenceRois.cornerTopLeft,
        referenceRois.cornerTopRight,
        referenceRois.cornerBottomLeft,
        referenceRois.cornerBottomRight,
      ],
    );

    final edgesScore = OpenCVGradingService.scoreEdges(
      [
        submitterRois.edgeTop,
        submitterRois.edgeBottom,
        submitterRois.edgeLeft,
        submitterRois.edgeRight,
      ],
      [
        referenceRois.edgeTop,
        referenceRois.edgeBottom,
        referenceRois.edgeLeft,
        referenceRois.edgeRight,
      ],
    );

    final surfaceScore = OpenCVGradingService.scoreSurface(
      submitterRois.surface,
      referenceRois.surface,
    );

    return GradingRules.apply(
      centerGrade: centerScore,
      cornersGrade: cornersScore,
      edgesGrade: edgesScore,
      surfaceGrade: surfaceScore,
      baselineUsed: baselineUsed,
      algorithmVersion: algorithmVersion,
    );
  }

  // ── Legacy methods (kept for backward compatibility) ────────

  static double centerGrade(img.Image centerImage) {
    final sobel = img.sobel(centerImage);
    final gray = img.grayscale(sobel);

    final leftMargin = DimensionAnalyzer.findLeftBorder(gray);
    final rightMargin =
        gray.width - DimensionAnalyzer.findRightBorder(gray) - 1;
    final topMargin = DimensionAnalyzer.findTopBorder(gray);
    final bottomMargin = gray.height - DimensionAnalyzer.findBottomBorder(gray) - 1;

    final maxH = max(leftMargin, rightMargin);
    final maxV = max(topMargin, bottomMargin);

    double horizontal = maxH > 0 ? min(leftMargin, rightMargin) / maxH : 1.0;
    double vertical = maxV > 0 ? min(topMargin, bottomMargin) / maxV : 1.0;

    final score = (horizontal + vertical) / 2.0;
    return 1 + score * 9;
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

  static double edgeGrade(List<img.Image> edges) {
    double result = 0;
    for (final edge in edges) {
      final exposure = DimensionAnalyzer.whiteExposure(edge);
      final score = (1 - exposure) * 9 + 1;
      result += score / edges.length;
    }
    return result;
  }

  static double surfaceGrade(img.Image surface) {
    int totalPixels = surface.width * surface.height;
    int defects = 0;

    for (final pixel in surface) {
      final brightness = (pixel.r + pixel.g + pixel.b) / 3;
      if (brightness > 240 || brightness < 15) {
        defects++;
      }
    }

    final defectRatio = defects / totalPixels;
    final score = max(1.0, 10.0 - defectRatio * 100);
    return score;
  }

  static GradingResult subgrades(RoiResult roi) {
    final centerScore = centerGrade(roi.centering);
    final cornersScore = cornerGrade([
      roi.cornerTopLeft,
      roi.cornerTopRight,
      roi.cornerBottomLeft,
      roi.cornerBottomRight,
    ]);
    final edgesScore = edgeGrade([
      roi.edgeTop,
      roi.edgeBottom,
      roi.edgeLeft,
      roi.edgeRight,
    ]);
    final surfaceScore = surfaceGrade(roi.surface);

    return GradingRules.apply(
      centerGrade: centerScore,
      cornersGrade: cornersScore,
      edgesGrade: edgesScore,
      surfaceGrade: surfaceScore,
    );
  }
}
