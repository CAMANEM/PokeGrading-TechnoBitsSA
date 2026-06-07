/// @file
/// @brief

import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../domain/submitter_catalog/submit_evaluation/evaluation_repository.dart';
import '../../domain/submitter_catalog/submit_evaluation/evaluation_request.dart';

/// PostgreSQL implementation of [EvaluationRepository].
///
/// Maps evaluation requests to the SOLICITUD_EVALUACION table.
/// Images are stored as IMAGEN rows (front/back) linked to CARTA_SUBMITTER
/// entries. Since auth is not yet implemented, a default user ID 1 is used.
class PostgresEvaluationRepository implements EvaluationRepository {
  final Connection _connection;

  PostgresEvaluationRepository._(this._connection);

  /// Creates and opens a PostgreSQL connection using the provided config.
  static Future<PostgresEvaluationRepository> connect(
      DatabaseConfig config) async {
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
    final connection = await Connection.open(endpoint, settings: settings);
    return PostgresEvaluationRepository._(connection);
  }

  @override
  Future<EvaluationRequest> saveEvaluation(AddEvaluationInput input) async {
    return await _connection.runTx((tx) async {
      final now = DateTime.now().toUtc();

      // 1. Insert front image
      final imgFrontIdRes = await tx
          .execute('SELECT COALESCE(MAX("id_imagen"), 0) + 1 FROM "IMAGEN"');
      final imgFrontId = imgFrontIdRes.first.first as int;
      await tx.execute(
        'INSERT INTO "IMAGEN" ("id_imagen", "ruta_cloud", "calidad_score", "fecha_subida") VALUES (\$1, \$2, \$3, \$4)',
        parameters: [
          imgFrontId,
          'eval_base64_front_${now.millisecondsSinceEpoch}',
          input.frontImageScore,
          now,
        ],
      );

      // 2. Insert back image
      final imgBackIdRes = await tx
          .execute('SELECT COALESCE(MAX("id_imagen"), 0) + 1 FROM "IMAGEN"');
      final imgBackId = imgBackIdRes.first.first as int;
      await tx.execute(
        'INSERT INTO "IMAGEN" ("id_imagen", "ruta_cloud", "calidad_score", "fecha_subida") VALUES (\$1, \$2, \$3, \$4)',
        parameters: [
          imgBackId,
          'eval_base64_back_${now.millisecondsSinceEpoch}',
          input.backImageScore,
          now,
        ],
      );

      // 3. Insert solicitud
      final solicitudIdRes = await tx.execute(
          'SELECT COALESCE(MAX("id_solicitud"), 0) + 1 FROM "SOLICITUD_EVALUACION"');
      final solicitudId = solicitudIdRes.first.first as int;
      final correlationId =
          'eval_${solicitudId}_${now.millisecondsSinceEpoch}';

      await tx.execute(
        'INSERT INTO "SOLICITUD_EVALUACION" ("id_solicitud", "id_usuario", "correlation_id", "estado_proceso", "fecha_solicitud") VALUES (\$1, \$2, \$3, \$4, \$5)',
        parameters: [
          solicitudId,
          1, // default user until auth is implemented
          correlationId,
          'identificado',
          now,
        ],
      );

      // 4. Insert carta_submitter linking the card to this solicitud
      if (input.cardId != null) {
        final parsedCardId = int.tryParse(input.cardId!);
        if (parsedCardId != null) {
          await tx.execute(
            'INSERT INTO "CARTA_SUBMITTER" ("id_carta", "id_solicitud", "id_carta_ref") VALUES (\$1, \$2, \$3)',
            parameters: [
              parsedCardId,
              solicitudId,
              parsedCardId, // uses same card as reference
            ],
          );
        }
      }

      return EvaluationRequest(
        id: solicitudId.toString(),
        frontImageData: input.frontImageData,
        backImageData: input.backImageData,
        frontImageScore: input.frontImageScore,
        backImageScore: input.backImageScore,
        status: EvaluationStatus.pending,
        createdAt: now,
        cardId: input.cardId,
      );
    });
  }

  @override
  Future<EvaluationRequest?> findById(String id) async {
    final parsedId = int.tryParse(id);
    if (parsedId == null) return null;

    final result = await _connection.execute(
      'SELECT "id_solicitud", "estado_proceso", "fecha_solicitud" FROM "SOLICITUD_EVALUACION" WHERE "id_solicitud" = \$1',
      parameters: [parsedId],
    );

    if (result.isEmpty) return null;
    final row = result.first;

    final status = switch (row[1].toString()) {
      'completado' => EvaluationStatus.completed,
      'rechazado' => EvaluationStatus.rejected,
      'validando' => EvaluationStatus.underReview,
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
    );
  }

  @override
  Future<void> saveSecurityAudit(SecurityAuditEvent event) async {
    try {
      await _connection.execute(
        'INSERT INTO "AUDITORIA_SEGURIDAD" ("tipo_evento", "detalles", "fecha_evento") VALUES (\$1, \$2, \$3)',
        parameters: [
          event.eventType,
          event.details,
          event.timestamp,
        ],
      );
    } catch (_) {
      // Table may not exist if migration 002 hasn't been applied
    }
  }

  Future<void> close() async {
    await _connection.close();
  }
}
