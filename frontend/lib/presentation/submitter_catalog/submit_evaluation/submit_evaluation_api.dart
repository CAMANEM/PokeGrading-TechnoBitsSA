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

    if (response.statusCode == 201) {
      return SubmitEvaluationResult(
        evaluationId: body['evaluation_id'] as String,
        status: body['status'] as String,
        createdAt: DateTime.parse(
          body['created_at'] as String,
        ),
        estimatedTime: body['estimated_time']?.toString(),
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
        }),
      );
    } on http.ClientException catch (_) {
      throw const SubmitEvaluationApiException(
        'No se pudo completar el envio por un fallo de red. Reintenta sin volver a seleccionar las imagenes.',
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
