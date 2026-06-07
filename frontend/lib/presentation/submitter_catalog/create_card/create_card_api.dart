/// @file
/// @brief

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import 'create_card_state.dart';

/*
 Frontend client for creating catalog cards.

 `CreateCardApi.addCard` posts a JSON payload representing the card and
 includes a `X-Correlation-ID` header to help correlate client-side actions
 with server logs. It converts successful responses into `CreateCardResult`.
*/

/// @brief CreateCardApiException
class CreateCardApiException implements Exception {
  final String message;

  const CreateCardApiException(this.message);

  @override
  String toString() => message;
}

/// @brief CreateCardApi
class CreateCardApi {
  final http.Client _client;

  CreateCardApi({http.Client? client}) : _client = client ?? http.Client();

  Future<CreateCardResult> addCard(CreateCardPayload payload) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards');
    final correlationId = const Uuid().v4();
    final headers = {
      'content-type': 'application/json',
      'X-Correlation-ID': correlationId,
    };

    final bodyMap = <String, dynamic>{
      'set': payload.identity.set,
      'number': payload.identity.number,
      'edition': payload.identity.edition,
      'language': payload.identity.language,
      'finish': payload.identity.finish,
      'display_name': payload.displayName,
      'rarity': payload.rarity,
      'type': payload.pokemonType,
      'hp': payload.hp,
      'illustrator': payload.illustrator,
      'year': payload.year,
      'author': payload.author,
      'image_data': payload.imageData,
      'back_image_data': payload.backImageData,
    };

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(bodyMap),
    );

    final body = _decodeResponse(response.body);
    if (response.statusCode == 201) {
      return CreateCardResult(
        cardId: body['card_id'] as String,
        cardStatus: body['card_status'] as String,
        createdAt: DateTime.parse(body['created_at'] as String),
      );
    }

    final message = body['message']?.toString() ?? 'Could not add card';
    throw CreateCardApiException(message);
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }
}
