import 'dart:async';

/// Propagates [correlationId] through async call chains via [Zone].
abstract final class CorrelationContext {
  static final Object _zoneKey = Object();

  static String? get current =>
      Zone.current[_zoneKey] as String?;

  static T run<T>(String correlationId, T Function() body) {
    return runZoned(body, zoneValues: {_zoneKey: correlationId});
  }

  static Future<T> runAsync<T>(
    String correlationId,
    Future<T> Function() body,
  ) {
    return runZoned(body, zoneValues: {_zoneKey: correlationId});
  }
}
