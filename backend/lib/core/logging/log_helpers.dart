import 'package:pokegrading_logging/pokegrading_logging.dart';
import 'package:shelf/shelf.dart';

/// HTTP metadata and sanitized request body for structured logs.
Map<String, dynamic> httpLogContext({
  required Request request,
  Map<String, dynamic>? body,
  Map<String, dynamic>? extra,
}) {
  return {
    'http_method': request.method,
    'http_path': request.requestedUri.path,
    if (body != null) ...RequestLogContext.withParams(body),
    if (extra != null) ...extra,
  };
}

/// Sanitized summary when the body contains large/redacted image fields.
Map<String, dynamic> evaluationBodySummary(Map<String, dynamic> payload) {
  return RequestLogContext.sanitize({
    'card_id': payload['card_id'],
    'front_image_data': payload['front_image_data'] != null ? '[present]' : null,
    'back_image_data': payload['back_image_data'] != null ? '[present]' : null,
  });
}

/// Sanitized catalog card create summary (no raw image bytes).
Map<String, dynamic> catalogCreateBodySummary(Map<String, dynamic> payload) {
  return RequestLogContext.sanitize({
    'set': payload['set'],
    'number': payload['number'],
    'edition': payload['edition'],
    'language': payload['language'],
    'finish': payload['finish'],
    'display_name': payload['display_name'],
    'rarity': payload['rarity'],
    'type': payload['type'],
    'hp': payload['hp'],
    'illustrator': payload['illustrator'],
    'year': payload['year'],
    'author': payload['author'],
    'image_data': payload['image_data'] != null ? '[present]' : null,
    'back_image_data': payload['back_image_data'] != null ? '[present]' : null,
  });
}

/// Sanitized catalog image search summary.
Map<String, dynamic> catalogSearchBodySummary(Map<String, dynamic> payload) {
  return RequestLogContext.sanitize({
    'mode': payload['mode'],
    'image_data': payload['image_data'] != null ? '[present]' : null,
  });
}
