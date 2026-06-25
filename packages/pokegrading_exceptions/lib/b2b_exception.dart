class B2bException implements Exception {
  /// Short error code for programmatic handling.
  final int code;

  final String err_type;

  /// Human readable message describing the reason for the exception.
  final String message;

  final int? apiKeyId;
  final String? apiKeyStatus;
  final int? customerId;
  final String? customerStatus;

  const B2bException(
      {required this.code,
      required this.err_type,
      required this.message,
      this.apiKeyId,
      this.apiKeyStatus,
      this.customerId,
      this.customerStatus});

  @override
  String toString() => 'Failure($code): $message';
}
