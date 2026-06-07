/*
 Frontend HTTP client for user registration flows.

 `RegisterApi` wraps HTTP calls to the backend registration endpoints and
 converts responses into frontend DTOs defined in `register_state.dart`.
 It throws `RegisterApiException` on non-successful results.
*/
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'register_state.dart';

/// @brief RegisterApiException
class RegisterApiException implements Exception {
  final String message;

  const RegisterApiException(this.message);

  @override
  String toString() => message;
}

/// @brief RegisterApi
class RegisterApi {
  final http.Client _client;

  RegisterApi({http.Client? client}) : _client = client ?? http.Client();

  Future<ConfirmedUserData> register({
    required String email,
    required String username,
    required String password,
    required String country,
    required String language,
    required bool acceptedDisclosure,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/auth/register');
    final response = await _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'username': username,
            'password': password,
            'country': country,
            'language': language,
            'acceptedDisclosure': acceptedDisclosure,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final payload = _decodeResponse(response.body);
    if (response.statusCode == 201) {
      final user = payload['user'] as Map<String, dynamic>;
      return ConfirmedUserData(
        id: user['id'] as String,
        email: user['email'] as String,
        username: user['username'] as String,
      );
    }

    throw RegisterApiException(
      payload['message']?.toString() ?? 'Registration failed',
    );
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }
}
