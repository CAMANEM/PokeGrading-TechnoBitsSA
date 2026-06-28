/// @file
/// @brief

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/client_log_reporter.dart';
import 'submit_evaluation_state.dart';

/// @brief SubmitEvaluationApiException
class SubmitEvaluationApiException implements Exception {
  final String message;

  const SubmitEvaluationApiException(this.message);

  @override
  String toString() => message;
}

/// @brief SubmitEvaluationApi
class SubmitEvaluationApi {
  final http.Client _client;

  SubmitEvaluationApi({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<SubmitEvaluationResult> submit(
    SubmitEvaluationPayload payload,
  ) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/scoring/evaluations');

    final correlationId = const Uuid().v4();

    final response = await _postEvaluation(uri, correlationId, payload);

    final body = _decodeResponse(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return SubmitEvaluationResult(
        evaluationId: body['evaluation_id'] as String,
        status: body['status'] as String,
        createdAt: DateTime.parse(
          body['created_at'] as String,
        ),
        estimatedTime: body['estimated_time']?.toString(),
        gradingResult: body['grading'] as Map<String, dynamic>?,
        rejectionReason: body['rejection_reason']?.toString(),
        algorithmVersion: body['metadata'] != null
            ? (body['metadata'] as Map<String, dynamic>)['algorithm_version']?.toString()
            : null,
      );
    }

    ClientLogReporter.reportError(
      logger: 'PokéGrading.Client.SubmitEvaluation',
      correlationId: correlationId,
      message: body['message']?.toString() ?? 'Error al enviar la evaluación',
      context: {
        'status_code': response.statusCode,
        'error': body['error']?.toString(),
      },
    );

    throw SubmitEvaluationApiException(
      body['message']?.toString() ?? 'Error al enviar la evaluación',
    );
  }

  Future<List<Grading>> getGradings() async {
    final uri = Uri.parse('${AppConfig.apiUrl}/scoring/evaluations');
    final correlationId = const Uuid().v4();

    final response = await _getEvaluation(uri, correlationId);

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);

      return body
          .map((json) => Grading.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    final body = _decodeResponse(response.body);

    ClientLogReporter.reportError(
      logger: 'PokéGrading.Client.SubmitEvaluation',
      correlationId: correlationId,
      message: body['message']?.toString() ?? 'Error obteniendo evaluaciones',
      context: {
        'status_code': response.statusCode,
        'error': body['error']?.toString(),
      },
    );

    throw SubmitEvaluationApiException(
      body['message']?.toString() ?? 'No se pudieron obtener las evaluaciones.',
    );
  }

  Future<http.Response> _postEvaluation(
    Uri uri,
    String correlationId,
    SubmitEvaluationPayload payload,
  ) async {
    try {
      return await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'X-Correlation-ID': correlationId,
        },
        body: jsonEncode({
          'front_image_data': payload.frontImageData,
          'back_image_data': payload.backImageData,
          if (payload.cardId != null) 'card_id': payload.cardId,
          if (payload.setName != null) 'set_name': payload.setName,
          if (payload.setFinish != null) 'set_finish': payload.setFinish,
        }),
      );
    } on http.ClientException catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SubmitEvaluation',
        correlationId: correlationId,
        message: 'Network error during evaluation submission',
        context: {'error': error.toString()},
      );
      throw const SubmitEvaluationApiException(
        'No se pudo completar el envio por un fallo de red. Reintenta sin volver a seleccionar las imagenes.',
      );
    }
  }

  Future<http.Response> _getEvaluation(Uri uri, String correlationId) async {
    try {
      return await _client.get(uri, headers: {
        'content-type': 'application/json',
        'X-Correlation-ID': correlationId
      });
    } on http.ClientException catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SubmitEvaluation',
        correlationId: correlationId,
        message: 'Network error during evaluation submission',
        context: {'error': error.toString()},
      );
      throw const SubmitEvaluationApiException(
        'No se pudo completar la solicitud por fallo de servidor.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }
}
