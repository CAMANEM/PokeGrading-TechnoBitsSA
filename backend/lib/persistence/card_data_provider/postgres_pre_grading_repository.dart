import 'package:postgres/postgres.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/scoring/pre_grading_logic.dart';
import '../../domain/scoring/scoring_models.dart';
import '../image_provider/image_storage_repository.dart';
import '../lookup/lookup_resolver.dart';

class PostgresPreGradingRepository implements PreGradingRepository {
  final Connection _connection;
  final ImageStorageRepository _images;

  PostgresPreGradingRepository._(this._connection, this._images);

  static Future<PostgresPreGradingRepository> connect(
    Connection connection,
    ImageStorageRepository images,
  ) async {
    return PostgresPreGradingRepository._(connection, images);
  }

  @override
  Future<PreGradingResult?> findExistingPreGrade(
    int cardSubmitterId,
    int cardReferenceId,
  ) async {
    try {
      final result = await _connection.execute(
        '''
        SELECT pg.id,
               pg.centering_grade, pg.corners_grade,
               pg.edges_grade, pg.surface_grade,
               pg.final_estimated_grade,
               pg.confidence_score, pg.uncertainty_band,
               pg.baseline_used, pg.requires_manual_review,
               pg.review_reason, pg.algorithm_version,
               pg.graded_date
        FROM pre_grade pg
        JOIN card_submitter cs ON pg.card_submitter_id = cs.id
        WHERE pg.card_submitter_id = \$1
          AND cs.card_reference_id = \$2
          AND pg.edges_grade IS NOT NULL
          AND pg.surface_grade IS NOT NULL
        ORDER BY pg.graded_date DESC
        LIMIT 1
        ''',
        parameters: [cardSubmitterId, cardReferenceId],
      );

      if (result.isEmpty) return null;

      final row = result.first;
      return PreGradingResult(
        preGradeId: row[0] as int,
        grading: GradingResult(
          centerGrade: (row[1] as num?)?.toDouble() ?? 0,
          cornersGrade: (row[2] as num?)?.toDouble() ?? 0,
          edgesGrade: (row[3] as num?)?.toDouble() ?? 0,
          surfaceGrade: (row[4] as num?)?.toDouble() ?? 0,
          finalGrade: (row[5] as num?)?.toDouble() ?? 0,
          confidenceScore: (row[6] as num?)?.toDouble() ?? 0,
          uncertaintyBand: (row[7] as num?)?.toDouble() ?? 0,
          baselineUsed: row[8]?.toString() ?? 'global_v1',
          requiresManualReview: row[9] as bool? ?? false,
          reviewReason: row[10]?.toString(),
        ),
        gradedAt: row[12] as DateTime? ?? DateTime.now().toUtc(),
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.PreGradingRepository',
        'findExistingPreGrade failed',
        context: {
          'card_submitter_id': cardSubmitterId,
          'card_reference_id': cardReferenceId,
        },
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  @override
  Future<({String front, String back})?> loadSubmitterImages(
    int cardSubmitterId,
  ) async {
    return _images.loadSubmitterImages(cardSubmitterId);
  }

  @override
  Future<({String front, String back})?> loadReferenceImages(
    int cardReferenceId,
  ) async {
    return _images.loadReferenceImages(cardReferenceId);
  }

  @override
  Future<int> savePreGrade({
    required int cardSubmitterId,
    required int cardReferenceId,
    required GradingResult grading,
    required DateTime gradedAt,
    required String correlationId,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final lookups = LookupResolver(_connection);
      final completedStatusId = await lookups.resolveStatusId('completed');

      final result = await _connection.execute(
        '''
        INSERT INTO pre_grade (
          card_submitter_id,
          algorithm_version,
          status_id,
          centering_grade,
          corners_grade,
          edges_grade,
          surface_grade,
          final_estimated_grade,
          confidence_score,
          uncertainty_band,
          baseline_used,
          requires_manual_review,
          review_reason,
          log_id,
          requested_date,
          graded_date,
          last_modified_date
        ) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13, \$14, \$15, \$16, \$17)
        RETURNING id
        ''',
        parameters: [
          cardSubmitterId,
          '1.0.0',
          completedStatusId,
          grading.centerGrade,
          grading.cornersGrade,
          grading.edgesGrade,
          grading.surfaceGrade,
          grading.finalGrade,
          grading.confidenceScore,
          grading.uncertaintyBand,
          grading.baselineUsed,
          grading.requiresManualReview,
          grading.reviewReason,
          correlationId,
          now,
          gradedAt,
          now,
        ],
      );

      final preGradeId = result.first.first as int;

      AppLogger.info(
        'PokéGrading.Persistence.PreGradingRepository',
        'Pre-grade saved',
        context: {
          'pre_grade_id': preGradeId,
          'card_submitter_id': cardSubmitterId,
          'final_grade': grading.finalGrade,
        },
      );

      return preGradeId;
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.PreGradingRepository',
        'savePreGrade failed',
        context: {'card_submitter_id': cardSubmitterId},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
