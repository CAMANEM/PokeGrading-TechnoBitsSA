/// @file
/// @brief HTTP client for catalog browse endpoints.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'catalog_browse_state.dart';

class CatalogBrowseApiException implements Exception {
  final String message;

  const CatalogBrowseApiException(this.message);

  @override
  String toString() => message;
}

class CatalogBrowseApi {
  final http.Client _client;

  CatalogBrowseApi({http.Client? client}) : _client = client ?? http.Client();

  Future<List<CatalogCardSummary>> listSubmitterCards() async {
    final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards/submitter');
    final response = await _client.get(uri);
    final body = _decodeResponse(response.body);

    if (response.statusCode != 200) {
      throw CatalogBrowseApiException(
        body['message']?.toString() ?? 'Failed to load submitter cards',
      );
    }

    final raw = body['cards'] as List<dynamic>? ?? [];
    return raw
        .map((c) => CatalogCardSummary.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<CatalogCardDetail> getSubmitterCardDetail(String id) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards/submitter/$id');
    final response = await _client.get(uri);
    final body = _decodeResponse(response.body);

    if (response.statusCode == 404) {
      throw CatalogBrowseApiException('Submitter card not found');
    }
    if (response.statusCode != 200) {
      throw CatalogBrowseApiException(
        body['message']?.toString() ?? 'Failed to load card detail',
      );
    }

    return CatalogCardDetail.fromJson(body);
  }

  Future<List<CatalogCardSummary>> listReferenceCards() async {
    final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards/reference');
    final response = await _client.get(uri);
    final body = _decodeResponse(response.body);

    if (response.statusCode != 200) {
      throw CatalogBrowseApiException(
        body['message']?.toString() ?? 'Failed to load reference cards',
      );
    }

    final raw = body['cards'] as List<dynamic>? ?? [];
    return raw
        .map((c) => CatalogCardSummary.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<CatalogCardDetail> getReferenceCardDetail(String id) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/catalog/cards/reference/$id');
    final response = await _client.get(uri);
    final body = _decodeResponse(response.body);

    if (response.statusCode == 404) {
      throw CatalogBrowseApiException('Reference card not found');
    }
    if (response.statusCode != 200) {
      throw CatalogBrowseApiException(
        body['message']?.toString() ?? 'Failed to load card detail',
      );
    }

    return CatalogCardDetail.fromJson(body);
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }
}
