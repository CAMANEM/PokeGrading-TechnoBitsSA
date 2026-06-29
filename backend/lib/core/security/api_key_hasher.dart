/// @file
/// @brief SHA-256 hashing for B2B API keys at rest.

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hashes API keys for storage and comparison (SHA-256 + optional pepper).
class ApiKeyHasher {
  final String pepper;

  const ApiKeyHasher({this.pepper = ''});

  String hash(String plaintextKey) {
    final normalized = plaintextKey.trim();
    final input = pepper.isEmpty ? normalized : '$pepper$normalized';
    return sha256.convert(utf8.encode(input)).toString();
  }

  bool matches(String plaintextKey, String storedHash) {
    return hash(plaintextKey) == storedHash;
  }
}
