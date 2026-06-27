/// @file
/// @brief

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/image_services/visual_features.dart';
import '../../domain/scoring/scoring_models.dart';
import '../image_provider/image_storage_repository.dart';
import '../lookup/lookup_resolver.dart';
import 'evaluation_repository.dart';

/// PostgreSQL implementation of [EvaluationRepository].
///
/// Maps evaluation requests to the pre_grade table and stores images in MongoDB.
class PostgresEvaluationRepository implements EvaluationRepository {
  final Connection _connection;
  final ImageStorageRepository _images;

  PostgresEvaluationRepository._(
    this._connection,
    this._images,
  );

  /// Creates and opens a PostgreSQL connection using the provided config.
  static Future<PostgresEvaluationRepository> connect(
    DatabaseConfig config,
    ImageStorageRepository images,
  ) async {
    AppLogger.info(
      'PokéGrading.Persistence.EvaluationRepository',
      'Connecting to PostgreSQL evaluation database',
      context: {'host': config.host, 'database': config.name},
    );

    final endpoint = Endpoint(
      host: config.host,
      port: config.port,
      database: config.name,
      username: config.user,
      password: config.password,
    );
    final settings = ConnectionSettings(
      connectTimeout: config.connectionTimeout,
      sslMode: SslMode.disable,
    );
    try {
      final connection = await Connection.open(endpoint, settings: settings);
      AppLogger.info(
        'PokéGrading.Persistence.EvaluationRepository',
        'PostgreSQL evaluation repository connected',
      );
      return PostgresEvaluationRepository._(
        connection,
        images,
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.EvaluationRepository',
        'Failed to connect to PostgreSQL evaluation database',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<EvaluationRequest> saveEvaluation(
      AddEvaluationInput input, GradingResult grade) async {
    AppLogger.info(
      'PokéGrading.Persistence.EvaluationRepository',
      'Saving evaluation',
      context: {'card_id': input.cardId, 'correlation_id': input.correlationId},
    );

    try {
      final saved = await _connection.runTx<_SavedEvaluation>((tx) async {
        final now = DateTime.now().toUtc();
        final lookups = LookupResolver(tx);
        final pendingStatusId = await lookups.resolveStatusId('pending');

        final cardSubmitterId = await _resolveCardSubmitterId(
          tx,
          input.cardId,
          input.frontVisualFeatures,
        );

        final preGradeResult = await tx.execute(
          '''
          INSERT INTO pre_grade (
            card_submitter_id,
            status_id,
            log_id,
            requested_date,
            last_modified_date,
            centering_grade,
            corners_grade,
            final_estimated_grade
          ) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9)
          RETURNING id
          ''',
          parameters: [
            cardSubmitterId,
            pendingStatusId,
            input.correlationId,
            now,
            now,
            grade.centerGrade,
            grade.cornersGrade,
            grade.finalGrade
          ],
        );
        final preGradeId = preGradeResult.first.first as int;

        return _SavedEvaluation(
          id: preGradeId,
          cardSubmitterId: cardSubmitterId,
          frontImageData: input.frontImageData,
          backImageData: input.backImageData,
          frontImageScore: input.frontImageScore,
          backImageScore: input.backImageScore,
          cardId: input.cardId,
          createdAt: now,
        );
      });

      await _images.saveSubmitterImages(
        cardSubmitterId: saved.cardSubmitterId,
        frontBase64: saved.frontImageData,
        backBase64: saved.backImageData,
      );

      AppLogger.info(
        'PokéGrading.Persistence.EvaluationRepository',
        'Evaluation saved successfully',
        context: {
          'evaluation_id': saved.id.toString(),
          'card_submitter_id': saved.cardSubmitterId,
        },
      );

      return EvaluationRequest(
        id: saved.id.toString(),
        frontImageData: saved.frontImageData,
        backImageData: saved.backImageData,
        frontImageScore: saved.frontImageScore,
        backImageScore: saved.backImageScore,
        status: EvaluationStatus.pending,
        createdAt: saved.createdAt,
        cardId: saved.cardId,
        logId: input.correlationId,
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.EvaluationRepository',
        'Save evaluation failed',
        context: {'card_id': input.cardId},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<int> _resolveCardSubmitterId(
    Session tx,
    String? cardReferenceId,
    VisualFeatures? features,
  ) async {
    AppLogger.info(
      'PokéGrading.Persistence.EvaluationRepository',
      'Creating card_submitter',
      context: {
        if (cardReferenceId != null) 'card_reference_id': cardReferenceId
      },
    );

    final submitterResult = await tx.execute(
      'SELECT id FROM submitter ORDER BY id LIMIT 1',
    );
    if (submitterResult.isEmpty) {
      AppLogger.error(
        'PokéGrading.Persistence.EvaluationRepository',
        'No submitter exists in database',
      );
      throw StateError(
        'No submitter exists. Register a user before submitting evaluations.',
      );
    }
    final submitterId = submitterResult.first.first as int;
    final now = DateTime.now().toUtc();

    final hashResult = await tx.execute(
      '''
      INSERT INTO hash_submitter (
        average_hash_hex,
        difference_hash_hex,
        center_average_hash_hex,
        center_difference_hash_hex,
        date
      ) VALUES (\$1, \$2, \$3, \$4, \$5)
      RETURNING id
      ''',
      parameters: [
        features?.averageHashHex,
        features?.differenceHashHex,
        features?.centerAverageHashHex,
        features?.centerDifferenceHashHex,
        now,
      ],
    );
    final hashId = hashResult.first.first as int;

    final parsedReferenceId =
        cardReferenceId != null ? int.tryParse(cardReferenceId) : null;

    final cardResult = await tx.execute(
      '''
      INSERT INTO card_submitter (
        submitter_id,
        hash_id,
        card_reference_id,
        registration_date,
        active
      ) VALUES (\$1, \$2, \$3, \$4, \$5)
      RETURNING id
      ''',
      parameters: [submitterId, hashId, parsedReferenceId, now, true],
    );
    return cardResult.first.first as int;
  }

  @override
  Future<EvaluationRequest?> findById(String id) async {
    try {
      final parsedId = int.tryParse(id);
      if (parsedId == null) {
        AppLogger.warning(
          'PokéGrading.Persistence.EvaluationRepository',
          'Invalid evaluation ID format',
          context: {'raw_id': id},
        );
        return null;
      }

      final result = await _connection.execute(
        '''
        SELECT pg.id, s.name, pg.requested_date, pg.card_submitter_id
        FROM pre_grade pg
        LEFT JOIN status s ON pg.status_id = s.id
        WHERE pg.id = \$1
        ''',
        parameters: [parsedId],
      );

      if (result.isEmpty) {
        AppLogger.info(
          'PokéGrading.Persistence.EvaluationRepository',
          'Evaluation not found',
          context: {'evaluation_id': id},
        );
        return null;
      }
      final row = result.first;

      final statusName = row[1]?.toString() ?? 'pending';
      final status = switch (statusName) {
        'completed' => EvaluationStatus.completed,
        'rejected' => EvaluationStatus.rejected,
        'under_review' => EvaluationStatus.underReview,
        _ => EvaluationStatus.pending,
      };

      return EvaluationRequest(
        id: row[0].toString(),
        frontImageData: '',
        backImageData: '',
        frontImageScore: 0,
        backImageScore: 0,
        status: status,
        createdAt: row[2] as DateTime,
        cardId: row[3]?.toString(),
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.EvaluationRepository',
        'findById failed',
        context: {'evaluation_id': id},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> close() async {
    await _connection.close();
  }
}

class _SavedEvaluation {
  final int id;
  final int cardSubmitterId;
  final String frontImageData;
  final String backImageData;
  final double frontImageScore;
  final double backImageScore;
  final String? cardId;
  final DateTime createdAt;

  const _SavedEvaluation({
    required this.id,
    required this.cardSubmitterId,
    required this.frontImageData,
    required this.backImageData,
    required this.frontImageScore,
    required this.backImageScore,
    required this.cardId,
    required this.createdAt,
  });
}
