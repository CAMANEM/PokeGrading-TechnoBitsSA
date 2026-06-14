/// Builds sanitized request parameter maps safe for structured logs.
import 'redaction.dart';

abstract final class RequestLogContext {
  /// Returns a copy of [payload] with sensitive fields redacted.
  static Map<String, dynamic> sanitize(Map<String, dynamic> payload) {
    return LogRedaction.scrubMap(payload) ?? {};
  }

  /// Wraps sanitized body fields under `params` for audit/operational context.
  static Map<String, dynamic> withParams(Map<String, dynamic> payload) {
    return {'params': sanitize(payload)};
  }
}
