/// @file
/// @brief Tests for baseline selection, calibration, and coherence rule.

import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/scoring/grading/baseline_config.dart';
import 'package:pokegrading_backend/domain/scoring/grading/baseline_registry.dart';
import 'package:pokegrading_backend/domain/scoring/grading/baseline_calibrator.dart';

void main() {
  group('BaselineConfig', () {
    test('globalFallback has correct version', () {
      final config = BaselineConfig.globalFallback;
      expect(config.version, 'global_v1.0');
      expect(config.description, isNotEmpty);
    });

    test('toJson and fromJson roundtrip', () {
      final config = BaselineConfig(
        version: 'test_v1.0',
        description: 'Test baseline',
        cornerWhiteningBrightnessThreshold: 240.0,
        uniformCVThreshold: 0.40,
      );

      final json = config.toJson();
      final restored = BaselineConfig.fromJson(json);

      expect(restored.version, 'test_v1.0');
      expect(restored.cornerWhiteningBrightnessThreshold, 240.0);
      expect(restored.uniformCVThreshold, 0.40);
    });
  });

  group('BaselineRegistry', () {
    late BaselineRegistry registry;

    setUp(() {
      registry = BaselineRegistry();
    });

    test('select returns global fallback when empty', () {
      final selection = registry.select('Base Set', 'holo');
      expect(selection.isCalibrated, false);
      expect(selection.version, 'global_v1.0');
    });

    test('select returns global fallback when null set/finish', () {
      final selection = registry.select(null, null);
      expect(selection.isCalibrated, false);
    });

    test('select returns calibrated baseline when sufficient ground truth', () {
      registry.register('Base Set', 'holo', BaselineEntry(
        config: BaselineConfig(version: 'base_set_holo_v1.0', description: 'Base Set Holo'),
        referenceCardCount: 25,
        calibratedAt: DateTime(2024, 1, 15),
        averagePsaGrade: 7.5,
      ));

      final selection = registry.select('Base Set', 'holo');
      expect(selection.isCalibrated, true);
      expect(selection.version, 'base_set_holo_v1.0');
      expect(selection.set, 'Base Set');
      expect(selection.finish, 'holo');
      expect(selection.referenceCardCount, 25);
    });

    test('select returns global fallback when insufficient ground truth', () {
      registry.register('Base Set', 'holo', BaselineEntry(
        config: BaselineConfig(version: 'base_set_holo_v1.0', description: 'Base Set Holo'),
        referenceCardCount: 10, // Less than 15 minimum
        calibratedAt: DateTime(2024, 1, 15),
        averagePsaGrade: 7.5,
      ));

      final selection = registry.select('Base Set', 'holo');
      expect(selection.isCalibrated, false);
      expect(selection.version, 'global_v1.0');
    });

    test('select is case-insensitive', () {
      registry.register('base set', 'holo', BaselineEntry(
        config: BaselineConfig(version: 'base_set_holo_v1.0', description: 'Test'),
        referenceCardCount: 20,
        calibratedAt: DateTime(2024, 1, 15),
        averagePsaGrade: 7.5,
      ));

      final selection = registry.select('BASE SET', 'HOLO');
      expect(selection.isCalibrated, true);
      expect(selection.version, 'base_set_holo_v1.0');
    });

    test('toJson includes baseline info', () {
      final selection = registry.select('Unknown', 'finish');
      final json = selection.toJson();
      expect(json.containsKey('baseline_version'), true);
      expect(json.containsKey('baseline_is_calibrated'), true);
      expect(json['baseline_is_calibrated'], false);
    });
  });

  group('BaselineCalibrator', () {
    test('calibrate with empty dataset returns global fallback', () {
      final result = BaselineCalibrator.calibrate(
        cards: [],
        baselineVersion: 'test_v1.0',
        description: 'Test',
      );

      expect(result.cardCount, 0);
      expect(result.config.version, 'global_v1.0');
      expect(result.warnings, isNotEmpty);
    });

    test('calibrate with insufficient cards warns', () {
      final cards = List.generate(10, (i) => GradedCardRecord(
        features: CardFeatures(
          centeringSymmetry: 0.8 + (i * 0.02),
          cornerWhiteningPercentages: [0.1 * i, 0.1 * i, 0.1 * i, 0.1 * i],
          edgeWhiteningPercentages: [0.05 * i, 0.05 * i, 0.05 * i, 0.05 * i],
          edgeStraightnessCVs: [0.1, 0.1, 0.1, 0.1],
          surfaceScratchDensity: 0.01 * i,
          surfaceUniformityCV: 0.3 + (i * 0.02),
        ),
        psaGrade: 5.0 + (i * 0.5),
        set: 'Test Set',
        finish: 'holo',
      ));

      final result = BaselineCalibrator.calibrate(
        cards: cards,
        baselineVersion: 'test_v1.0',
        description: 'Test calibration',
      );

      expect(result.cardCount, 10);
      expect(result.hasSufficientGroundTruth, false);
      expect(result.warnings.length, greaterThanOrEqualTo(1));
    });

    test('calibrate with sufficient cards produces calibrated baseline', () {
      final cards = List.generate(20, (i) => GradedCardRecord(
        features: CardFeatures(
          centeringSymmetry: 0.8 + (i * 0.01),
          cornerWhiteningPercentages: [0.1 * i, 0.1 * i, 0.1 * i, 0.1 * i],
          edgeWhiteningPercentages: [0.05 * i, 0.05 * i, 0.05 * i, 0.05 * i],
          edgeStraightnessCVs: [0.1, 0.1, 0.1, 0.1],
          surfaceScratchDensity: 0.01 * i,
          surfaceUniformityCV: 0.3 + (i * 0.01),
        ),
        psaGrade: 1.0 + (i * 0.5),
        set: 'Test Set',
        finish: 'holo',
      ));

      final result = BaselineCalibrator.calibrate(
        cards: cards,
        baselineVersion: 'test_set_holo_v1.0',
        description: 'Test Set Holo calibration',
      );

      expect(result.cardCount, 20);
      expect(result.hasSufficientGroundTruth, true);
      expect(result.config.version, 'test_set_holo_v1.0');
      expect(result.qualityScore, greaterThan(0));
    });
  });
}
