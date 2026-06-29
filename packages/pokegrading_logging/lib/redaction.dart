/// Scrubs sensitive values from log context maps before emission.
abstract final class LogRedaction {
  static const _blockedKeys = {
    'password',
    'secret',
    'token',
    'authorization',
    'api_key',
    'smtp_password',
    'jwt',
    'jwt_secret',
    'image_data',
    'front_image_data',
    'back_image_data',
    'frontImageData',
    'backImageData',
  };

  static const redactedValue = '[REDACTED]';

  static Map<String, dynamic>? scrubMap(Map<String, dynamic>? input) {
    if (input == null) return null;
    return _scrub(input);
  }

  static Map<String, dynamic> _scrub(Map<String, dynamic> input) {
    final result = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key;
      final lowerKey = key.toLowerCase();
      if (_blockedKeys.contains(lowerKey) ||
          lowerKey.contains('password') ||
          lowerKey.contains('secret')) {
        result[key] = redactedValue;
        continue;
      }

      final value = entry.value;
      if (value is Map<String, dynamic>) {
        result[key] = _scrub(value);
      } else if (value is Map) {
        result[key] = _scrub(Map<String, dynamic>.from(value));
      } else if (value is String && _looksLikeBase64Image(value)) {
        result[key] = redactedValue;
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  static bool _looksLikeBase64Image(String value) {
    if (value.length < 256) return false;
    final trimmed = value.trim();
    if (trimmed.startsWith('data:image/')) return true;
    return trimmed.length > 1024 &&
        RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(trimmed);
  }
}
