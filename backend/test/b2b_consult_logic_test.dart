import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'package:pokegrading_backend/core/config/logging_config.dart';
import 'package:pokegrading_backend/core/logging/app_logger.dart';
import 'package:pokegrading_backend/domain/b2b/b2b_models.dart';
import 'package:pokegrading_backend/domain/b2b/b2b_validators.dart';
import 'package:pokegrading_backend/domain/b2b/consult/consult_logic.dart';
import 'package:pokegrading_backend/persistence/mocks/mock_reference_catalog_repository.dart';

void main() {
  setUpAll(() {
    AppLogger.init(
      level: Level.INFO,
      config: const LoggingConfig(
        logDir: './logs',
        fileEnabled: false,
        format: LogFormat.json,
        retentionDays: 1,
        appInsightsEnabled: false,
      ),
    );
  });

  group('B2bValidators', () {
    test('rejects invalid language code', () {
      final error = B2bValidators.validateCard(
        const B2bConsultCardInput(
          set: 'SVP',
          number: '001',
          language: 'FR',
        ),
      );
      expect(error, isNotNull);
      expect(error!.field, 'language');
    });

    test('accepts card with only set and number', () {
      final error = B2bValidators.validateCard(
        const B2bConsultCardInput(set: 'SVP', number: '001'),
      );
      expect(error, isNull);
    });
  });

  group('ConsultLogic', () {
    late ConsultLogic logic;

    setUp(() {
      logic = ConsultLogic(
        catalogRepository: MockReferenceCatalogRepository(),
        maxCardsPerRequest: 100,
      );
    });

    test('returns COVERED for unique match', () async {
      final result = await logic.consult([
        const B2bConsultCardInput(
          set: 'SVP',
          number: '001',
          edition: 'FIRST_EDITION',
          language: 'EN',
          finish: 'HOLO',
        ),
      ]);

      expect(result.results.length, 1);
      expect(result.results.first.status, B2bConsultStatus.covered);
      expect(result.results.first.cardId, '1');
    });

    test('returns MULTIPLE_MATCH with stable ordering', () async {
      final result = await logic.consult([
        const B2bConsultCardInput(set: 'SVP', number: '002'),
      ]);

      expect(result.results.first.status, B2bConsultStatus.multipleMatch);
      final candidates = result.results.first.candidates!;
      expect(candidates.length, 2);
      expect(candidates[0].cardId, '2');
      expect(candidates[1].cardId, '3');
    });

    test('INVALID_PARAMETERS does not block sibling cards', () async {
      final result = await logic.consult([
        const B2bConsultCardInput(set: 'SVP', number: '001', language: 'FR'),
        const B2bConsultCardInput(set: 'SVP', number: '001'),
      ]);

      expect(result.results.length, 2);
      expect(result.results[0].status, B2bConsultStatus.invalidParameters);
      expect(result.results[1].status, B2bConsultStatus.covered);
    });

    test('returns NOT_COVERED when no match', () async {
      final result = await logic.consult([
        const B2bConsultCardInput(set: 'XYZ', number: '999'),
      ]);

      expect(result.results.first.status, B2bConsultStatus.notCovered);
    });

    test('throws when cards array exceeds limit', () async {
      final cards = List.generate(
        101,
        (_) => const B2bConsultCardInput(set: 'SVP', number: '001'),
      );

      await expectLater(
        logic.consult(cards),
        throwsA(isA<ConsultLogicException>()),
      );
    });
  });
}
