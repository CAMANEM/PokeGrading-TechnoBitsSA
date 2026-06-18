/// @file
/// @brief

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/logging/client_log_reporter.dart';

/// @brief HomeApi
class HomeApi {
  final http.Client _client;

  HomeApi({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> fetchHealth() async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/health');

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.HomeApi',
        correlationId: '',
        message: 'Health check failed',
        context: {'status_code': response.statusCode},
      );

      throw Exception('Status ${response.statusCode}');
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.HomeApi',
        correlationId: '',
        message: 'Health check error',
        context: {'error': error.toString()},
      );
      rethrow;
    }
  }
}
