/// @file
/// @brief

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

/// @brief HomeApi
class HomeApi {
  final http.Client _client;

  HomeApi({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> fetchHealth() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/health');

    final response = await _client.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Status ${response.statusCode}');
  }
}
