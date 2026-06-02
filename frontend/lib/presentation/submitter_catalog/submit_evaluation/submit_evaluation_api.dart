import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import 'submit_evaluation_state.dart';

class SubmitEvaluationApiException implements Exception {
  final String message;

  const SubmitEvaluationApiException(this.message);

  @override
  String toString() => message;
}

class SubmitEvaluationApi {
  final http.Client _client;

  SubmitEvaluationApi({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<SubmitEvaluationResult> submit(
    SubmitEvaluationPayload payload,
  ) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/evaluations');

    final correlationId = const Uuid().v4();

    final response = await _client.post(
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

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      return SubmitEvaluationResult(
        evaluationId: body['evaluation_id'],
        status: body['status'],
        createdAt: DateTime.parse(
          body['created_at'],
        ),
        estimatedTime: body['estimated_time'],
      );
    }

    throw SubmitEvaluationApiException(
      body['message'] ?? 'Error al enviar la evaluación',
    );
  }
}
