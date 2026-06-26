/// @file
/// @brief API client for the pre-process card endpoint.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/client_log_reporter.dart';
import 'pre_process_card_state.dart';

/// @brief PreProcessCardApiException
class PreProcessCardApiException implements Exception {
  final String message;

  const PreProcessCardApiException(this.message);

  @override
  String toString() => message;
}

/// @brief PreProcessCardApi
class PreProcessCardApi {
  final http.Client _client;

  PreProcessCardApi({http.Client? client}) : _client = client ?? http.Client();

  Future<PreProcessCardResult> preprocess(
    PreProcessCardPayload payload,
  ) async {
    final correlationId = const Uuid().v4();
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/scoring/preprocess');
      final headers = {
        'content-type': 'application/json',
        'X-Correlation-ID': correlationId,
      };

      final bodyMap = <String, dynamic>{
        'image_data': payload.imageData,
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(bodyMap),
      );

      final body = _decodeResponse(response.body);

      if (response.statusCode == 200) {
        return PreProcessCardResult(
          correctedImage: body['corrected_image'] as String,
          corners: (body['corners'] as List<dynamic>?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList(),
          metadata: body['metadata'] != null
              ? Map<String, dynamic>.from(body['metadata'] as Map)
              : null,
        );
      }

      final message =
          body['message']?.toString() ?? 'Pre-procesamiento fallido';
      throw PreProcessCardApiException(message);
    } on PreProcessCardApiException {
      rethrow;
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.PreProcessCardApi',
        correlationId: correlationId,
        message: 'Preprocess network error',
        context: {'error': error.toString()},
      );
      throw PreProcessCardApiException('Error de red: ${error.toString()}');
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
