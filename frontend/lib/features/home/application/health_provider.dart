// ============================================================
// PokéGrading — Health Check Provider (Home Feature)
// Provider de Riverpod que consulta el /health del backend.
// ============================================================
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

/// Provider que realiza el health check al backend.
///
/// Es un [FutureProvider] porque es una operación asíncrona (HTTP).
/// Riverpod maneja automáticamente los estados:
///   - loading: mientras espera la respuesta
///   - data: respuesta exitosa
///   - error: fallo en la conexión
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
    throw Exception('No se pudo conectar con el backend: $e');
  }
});
