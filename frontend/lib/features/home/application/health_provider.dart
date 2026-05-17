// ============================================================
// PokéGrading — Health Check Provider (Home Feature)
// Riverpod provider that requests /health from the backend.
// ============================================================
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

/// Provider that performs the health check against the backend.
///
/// It is a [FutureProvider] because it is an asynchronous operation (HTTP).
/// Riverpod automatically handles the states:
///   - loading: while waiting for the response
///   - data: successful response
///   - error: connection failure
final healthCheckProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final uri = Uri.parse('${AppConfig.apiBaseUrl}/health');

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Status ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to connect to backend: $e');
  }
});
