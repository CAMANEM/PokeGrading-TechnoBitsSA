import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../application/auth_service.dart';

Router buildAuthRouter(AuthService authService) {
  final router = Router();

  router.post('/register', (Request request) async {
    final payload = await _readJson(request);
    final email = (payload['email'] ?? '').toString();
    final username = (payload['username'] ?? '').toString();
    final password = (payload['password'] ?? '').toString();
    final country = (payload['country'] ?? '').toString();
    final language = (payload['language'] ?? '').toString();
    final acceptedDisclosure = payload['acceptedDisclosure'] == true;

    try {
      final session = await authService.startRegistration(
        email: email,
        username: username,
        password: password,
        country: country,
        language: language,
        acceptedDisclosure: acceptedDisclosure
      );

      return _jsonResponse(
        201,
        {
          'status': 'pending_confirmation',
          'message': 'Confirmation token sent to the provided email address.',
          'email': session.email,
          'username': session.username,
          'expires_at': session.expiresAt.toIso8601String(),
        },
      );
    } on AuthServiceException catch (error) {
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
        502,
        {
          'status': 'error',
          'error': 'email_delivery_failed',
          'message': error.toString(),
        },
      );
    }
  });

  router.post('/confirm', (Request request) async {
    final payload = await _readJson(request);
    final token = (payload['token'] ?? '').toString();

    try {
      final user = await authService.confirmRegistration(token: token);
      return _jsonResponse(
        200,
        {
          'status': 'active',
          'message': 'Account confirmed successfully.',
          'user': {
            'id': user.id,
            'email': user.email,
            'username': user.username,
          },
        },
      );
    } on AuthServiceException catch (error) {
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
        502,
        {
          'status': 'error',
          'error': 'confirmation_failed',
          'message': 'Unable to process registration',
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

  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
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