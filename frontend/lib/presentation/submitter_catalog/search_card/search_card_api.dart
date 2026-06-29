/// @file
/// @brief

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/client_log_reporter.dart';
import 'search_card_state.dart';

/*
 Frontend client for creating catalog cards.

 `CreateCardApi.addCard` posts a JSON payload representing the card and
 includes a `X-Correlation-ID` header to help correlate client-side actions
 with server logs. It converts successful responses into `CreateCardResult`.
*/

/// @brief SearchCardApiException
class SearchCardApiException implements Exception {
  final String message;

  const SearchCardApiException(this.message);

  @override
  String toString() => message;
}

/// @brief SearchCardApi
class SearchCardApi {
  final http.Client _client;

  SearchCardApi({http.Client? client}) : _client = client ?? http.Client();

  Future<SearchCardResult> searchByImage(SearchCardPayload payload) async {
    final correlationId = const Uuid().v4();
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards/search/image');
      final headers = {
        'content-type': 'application/json',
        'X-Correlation-ID': correlationId,
      };

      final bodyMap = <String, dynamic>{
        'image_data': payload.imageData,
        'mode': payload.mode.name,
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(bodyMap),
      );

      final body = _decodeResponse(response.body);
      if (response.statusCode == 200) {
        return SearchCardResult(
          nextStage: SearchCardStage.success,
          candidates: [
            CandidateCard(
              id: body['candidate']['id'],
              name: body['candidate']['name'],
              confidence: (body['candidate']['confidence'] as num).toDouble(),
            ),
          ],
        );
      } else if (response.statusCode == 201) {
        final raw = body['candidates'] as List<dynamic>? ?? [];

        return SearchCardResult(
          nextStage: SearchCardStage.showingCandidates,
          candidates: raw
              .map(
                (c) => CandidateCard(
                  id: c['id'].toString(),
                  name: c['name'].toString(),
                  confidence: (c['confidence'] as num).toDouble(),
                ),
              )
              .toList(),
        );
      } else if (response.statusCode == 400) {
        return SearchCardResult(
          nextStage: SearchCardStage.manualSearch,
          candidates: [],
          reason: body['message'],
        );
      } else {
        return SearchCardResult(
            nextStage: SearchCardStage.capture, reason: body['message']);
      }
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SearchCardApi',
        correlationId: correlationId,
        message: 'Image search failed',
        context: {'error': error.toString()},
      );
      rethrow;
    }
  }

  Future<SearchCardResult> searchManual(ManualSearchPayload payload) async {
    final correlationId = const Uuid().v4();
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards/search/manual');
      final headers = {
        'content-type': 'application/json',
        'X-Correlation-ID': correlationId,
      };

      final bodyMap = <String, dynamic>{
        'set': payload.set,
        'number': payload.number,
        'edition': payload.edition,
        'language': payload.language,
        'finish': payload.finish,
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(bodyMap),
      );

      final body = _decodeResponse(response.body);
      if (response.statusCode == 200) {
        return SearchCardResult(
          nextStage: SearchCardStage.success,
          candidates: [
            CandidateCard(
              id: body['candidate']['id'].toString(),
              name: body['candidate']['name'].toString(),
              confidence:
                  (body['candidate']['confidence'] as num?)?.toDouble() ?? 1.0,
            ),
          ],
        );
      } else if (response.statusCode == 201) {
        final raw = body['candidates'] as List<dynamic>? ?? [];

        return SearchCardResult(
          nextStage: SearchCardStage.showingCandidates,
          candidates: raw
              .map(
                (c) => CandidateCard(
                  id: c['id'].toString(),
                  name: c['name'].toString(),
                  confidence: (c['confidence'] as num).toDouble(),
                ),
              )
              .toList(),
        );
      }

      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SearchCardApi',
        correlationId: correlationId,
        message: 'Manual search rejected',
        context: {
          'status_code': response.statusCode,
          'error': body['message']?.toString(),
        },
      );

      final message = body['message']?.toString() ?? 'Could not find card';
      throw SearchCardApiException(message);
    } on SearchCardApiException {
      rethrow;
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SearchCardApi',
        correlationId: correlationId,
        message: 'Manual search network error',
        context: {'error': error.toString()},
      );
      throw SearchCardApiException('Network error: ${error.toString()}');
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
