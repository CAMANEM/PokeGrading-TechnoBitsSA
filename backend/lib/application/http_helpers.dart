/*
 HTTP helper utilities used by route handlers.

 - `readJson`: safely reads and decodes a JSON request body into a Map.
 - `jsonResponse`: convenience to construct a JSON `Response` with correct
   content-type header.
 - `registerStatusCodeFor`: maps domain error codes from registration logic
   to HTTP status codes.
 - `createCardStatusCodeFor`: maps create-card domain error codes to HTTP
   status codes.
*/
import 'dart:convert';

import 'package:shelf/shelf.dart';

Future<Map<String, dynamic>> readJson(Request request) async {
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

/*
 Returns a JSON `Response` with the provided `statusCode` and body.
 The body is encoded using `jsonEncode` and the `content-type` header is set
 to `application/json; charset=utf-8`.
*/
Response jsonResponse(
  int statusCode,
  Map<String, dynamic> body, {
  Map<String, String>? headers,
}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      if (headers != null) ...headers,
    },
  );
}

/*
 Maps registration-specific domain error codes to HTTP status codes. The
 mapping is intentionally concise; unknown codes map to `500`.
*/
int registerStatusCodeFor(String code) {
  return switch (code) {
    'invalid_email' => 400,
    'invalid_username' => 400,
    'invalid_password' => 400,
    'email_exists' => 409,
    'username_exists' => 409,
    'invalid_country' => 400,
    'invalid_language' => 400,
    'disclosure_required' => 400,
    'blocked_email_domain' => 403,
    _ => 500,
  };
}

/*
 Maps create-card domain error codes to HTTP status codes.
*/
int createCardStatusCodeFor(String code) {
  return switch (code) {
    'identity_rejected' => 409,
    'image_rejected' => 400,
    _ => 500,
  };
}

int submitEvaluationStatusCodeFor(String code) {
  return switch (code) {
    'image_rejected' => 400,
    _ => 500,
  };
}
