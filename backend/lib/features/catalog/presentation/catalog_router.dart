import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../application/catalog_service.dart';

Router buildCatalogRouter(CatalogService catalogService) {
  final router = Router();

  router.post('/cards', (Request request) async {
    final payload = await _readJson(request);
    final set = (payload['set'] ?? '').toString();
    final number = (payload['number'] ?? '').toString();
    final edition = (payload['edition'] ?? '').toString();
    final language = (payload['language'] ?? '').toString();
    final finish = (payload['finish'] ?? '').toString();
    final displayName = payload['display_name']?.toString();
    final imageData = (payload['image_data'] ?? '').toString();

    try {
      final result = await catalogService.addCard(
        AddCardCommand(
          set: set,
          number: number,
          edition: edition,
          language: language,
          finish: finish,
          displayName: displayName,
          imageData: imageData,
        ),
      );

      return _jsonResponse(
        201,
        {
          'status': 'pending_validation',
          'message': 'Carta agregada al catalogo',
          'card_id': result.cardId,
          'card_status': result.status.name,
          'created_at': result.createdAt.toIso8601String(),
        },
      );
    } on CatalogServiceException catch (error) {
      return _jsonResponse(
        _statusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error) {
      return _jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'catalog_add_failed',
          'message': error.toString(),
        },
      );
    }
  });

  return router;
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  final body = await request.readAsString();
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }

  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } on FormatException {
    return <String, dynamic>{};
  }

  return <String, dynamic>{};
}

Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

int _statusCodeFor(String code) {
  return switch (code) {
    'identity_rejected' => 409,
    'image_rejected' => 400,
    _ => 500,
  };
}
