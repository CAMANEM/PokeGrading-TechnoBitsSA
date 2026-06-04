import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import 'search_card_state.dart';

/*
 Frontend client for creating catalog cards.

 `CreateCardApi.addCard` posts a JSON payload representing the card and
 includes a `X-Correlation-ID` header to help correlate client-side actions
 with server logs. It converts successful responses into `CreateCardResult`.
*/
class SearchCardApiException implements Exception {
  final String message;

  const SearchCardApiException(this.message);

  @override
  String toString() => message;
}

class SearchCardApi {
  final http.Client _client;

  SearchCardApi({http.Client? client}) : _client = client ?? http.Client();

  Future<SearchCardResult> searchByImage(SearchCardPayload payload) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards/search/image');
    final correlationId = const Uuid().v4();
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
    } else {
      return const SearchCardResult(
        nextStage: SearchCardStage.manualSearch,
      );
    }
  }

  Future<SearchCardResult> searchManual(ManualSearchPayload payload) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards/search/manual');
    final correlationId = const Uuid().v4();
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
            confidence: 1.0,
          ),
        ],
      );
    }

    final message = body['message']?.toString() ?? 'Could not find card';
    throw SearchCardApiException(message);
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }
}
