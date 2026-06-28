import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

import 'package:pokegrading_backend/domain/image_services/preprocessing/roi_segmenter.dart';
import 'package:pokegrading_backend/domain/scoring/grading/grading_orchestrator.dart';
import 'package:pokegrading_backend/domain/image_services/grading/enhanced_quality_service.dart';

void main() async {
  print('=== PokéGrading - Test con multiples cartas ===\n');

  final images = {
    'Charizard': '../preprocess_output/Imagen - Charizard.txt',
    'Pikachu Gordo': '../preprocess_output/Imagen - Pikachu Gordo.txt',
    'Pikachu Snowman': '../preprocess_output/Imagen - Pikachu Snowman.txt',
  };

  for (final entry in images.entries) {
    await _processImage(entry.key, entry.value);
  }
}

Future<void> _processImage(String name, String path) async {
  print('═══════════════════════════════════════════════════════════════');
  print('  CARTA: $name');
  print('═══════════════════════════════════════════════════════════════');
  print('');

  final file = File(path);
  if (!file.existsSync()) {
    print('ERROR: $path not found\n');
    return;
  }

  // Read base64 from text file
  final base64Data = file.readAsStringSync().trim();
  final imageBytes = base64Decode(base64Data);
  final image = img.decodeImage(imageBytes);

  if (image == null) {
    print('ERROR: Could not decode image from $path\n');
    return;
  }

  print('  Imagen: ${image.width}x${image.height} px');
  print('');

  // Extract ROIs
  print('  --- Extrayendo ROIs ---');
  final rois = RoiSegmenter.extract(image);
  print('    Centering: ${rois.centering.width}x${rois.centering.height}');
  print('    Surface:   ${rois.surface.width}x${rois.surface.height}');
  print('');

  // Run grading (pass full image for centering detection)
  print('  --- Ejecutando Grading ---');
  final gradingResult = GradingOrchestrator.grade(rois, fullImage: image);

  // Run enhanced quality
  final qualityResult = EnhancedQualityService.calculateEnhancedQuality(image);

  // Print results
  print('');
  print('  ┌─────────────────────────────────────────┐');
  print('  │         RESULTADOS DE GRADING           │');
  print('  └─────────────────────────────────────────┘');
  print('');
  print('    CENTERING:  ${gradingResult.centeringGrade.toStringAsFixed(2)}/10.0');
  print('');
  print('    CORNERS:');
  for (final c in gradingResult.corners.corners) {
    final status = c.passes ? 'PASS' : 'FAIL';
    print('      ${c.position.padRight(15)} whitening: ${c.whiteningPercentage.toStringAsFixed(2)}%  [$status]');
  }
  print('      Grade: ${gradingResult.corners.grade.toStringAsFixed(2)}/10.0');
  print('');
  print('    EDGES:');
  for (final e in gradingResult.edges.edges) {
    final status = e.passes ? 'PASS' : 'FAIL';
    print('      ${e.position.padRight(15)} whitening: ${e.whiteningPercentage.toStringAsFixed(2)}%  straightness: ${e.straightnessScore.toStringAsFixed(2)}  [$status]');
  }
  print('      Grade: ${gradingResult.edges.grade.toStringAsFixed(2)}/10.0');
  print('');
  print('    SURFACE:');
  print('      scratch_score:     ${gradingResult.surface.scratchScore.toStringAsFixed(4)}');
  print('      print_line_score:  ${gradingResult.surface.printLineScore.toStringAsFixed(4)}');
  print('      uniformity_score:  ${gradingResult.surface.uniformityScore.toStringAsFixed(4)}');
  print('      scratch_count:     ${gradingResult.surface.scratchCount}');
  print('      Grade: ${gradingResult.surface.grade.toStringAsFixed(2)}/10.0');
  print('');
  print('  ─────────────────────────────────────────');
  print('  FINAL GRADE:   ${gradingResult.finalGrade.toStringAsFixed(2)}/10.0');
  print('  CONFIDENCE:    ${(gradingResult.confidence * 100).toStringAsFixed(1)}%');
  print('  UNCERTAINTY:   ${gradingResult.gradeLowerBound.toStringAsFixed(2)} - ${gradingResult.gradeUpperBound.toStringAsFixed(2)}');
  print('  LOWEST SUB:    ${gradingResult.lowestSubgrade.toStringAsFixed(2)} ${gradingResult.coherenceRuleApplied ? "(COHERENCE APPLIED)" : ""}');
  print('');
  print('  ─────────────────────────────────────────');
  print('  BASELINE:');
  print('    Version:     ${gradingResult.baseline.version}');
  print('    Calibrated:  ${gradingResult.baseline.isCalibrated ? "YES (set: ${gradingResult.baseline.set}, finish: ${gradingResult.baseline.finish})" : "NO (global fallback)"}');
  print('    Ref Cards:   ${gradingResult.baseline.referenceCardCount}');
  print('');
  print('  EXPLANATION:   ${gradingResult.explanation}');
  print('');
  print('  ─────────────────────────────────────────');
  print('  ENHANCED QUALITY (IQS):');
  print('    Score:              ${qualityResult.score.toStringAsFixed(1)}/100');
  print('    Laplacian Sharpness: ${qualityResult.laplacianSharpness.toStringAsFixed(4)}');
  print('    Tenengrad Sharpness: ${qualityResult.tenengradSharpness.toStringAsFixed(4)}');
  print('    Brightness:         ${qualityResult.brightnessScore.toStringAsFixed(4)}');
  print('    Entropy:            ${qualityResult.entropyScore.toStringAsFixed(4)}');
  print('    Contrast:           ${qualityResult.contrastScore.toStringAsFixed(4)}');
  print('    Passes:             ${qualityResult.passes}');
  if (qualityResult.rejectionReasons.isNotEmpty) {
    print('    Rejection Reasons:');
    for (final r in qualityResult.rejectionReasons) {
      print('      - $r');
    }
  }
  print('');
  print('');
}
