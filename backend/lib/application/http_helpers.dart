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

Response jsonResponse(int statusCode, Map<String, dynamic> body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

int registerStatusCodeFor(String code) {
  return switch (code) {
    'invalid_email' => 400,
    'invalid_username' => 400,
    'invalid_password' => 400,
    'invalid_token' => 400,
    'email_exists' => 409,
    'username_exists' => 409,
    'invalid_country' => 400,
    'invalid_language' => 400,
    'disclosure_required' => 400,
    'blocked_email_domain' => 403,
    _ => 500,
  };
}

int createCardStatusCodeFor(String code) {
  return switch (code) {
    'identity_rejected' => 409,
    'image_rejected' => 400,
    _ => 500,
  };
}
