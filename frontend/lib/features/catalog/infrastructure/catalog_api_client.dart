import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/catalog_models.dart';

class CatalogApiException implements Exception {
  final String message;

  const CatalogApiException(this.message);

  @override
  String toString() => message;
}

class CatalogApiClient {
  final http.Client _client;

  CatalogApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<AddCardResult> addCard(AddCardPayload payload) async {
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

    final response = await _client.post(uri, headers: headers, body: jsonEncode(bodyMap));

    final body = _decodeResponse(response.body);
    if (response.statusCode == 201) {
      return AddCardResult(
        cardId: body['card_id'] as String,
        cardStatus: body['card_status'] as String,
        createdAt: DateTime.parse(body['created_at'] as String),
      );
    }

    final message = body['message']?.toString() ?? 'No se pudo agregar la carta';
    throw CatalogApiException(message);
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }
}
