class LogicException implements Exception {
  final String feature;

  /// Short error code for programmatic handling.
  final String code;

  /// Human readable message describing the reason for the exception.
  final String message;

  const LogicException(
      {required this.feature, required this.code, required this.message});

  @override
  String toString() => '$feature($code): $message';
}
