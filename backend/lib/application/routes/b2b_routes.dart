/// @file
/// @brief HTTP routes for the B2B catalog coverage API (`POST /consult`).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:pokegrading_logging/pokegrading_logging.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_helpers.dart';
import '../../domain/b2b/b2b_models.dart';
import '../../domain/b2b/b2b_validators.dart';
import '../../domain/b2b/consult/consult_logic.dart';
import '../../persistence/b2b_data_provider/api_key_repository.dart';
import '../../persistence/b2b_data_provider/b2b_audit_repository.dart';
import '../../persistence/b2b_data_provider/idempotency_repository.dart';
import '../../persistence/b2b_data_provider/rate_limit_repository.dart';
import '../http_helpers.dart';

const _loggerName = 'PokéGrading.Routes.B2B';

/// Builds the B2B sub-router mounted at `/api/v1/b2b/`.
///
/// Handles API-key authentication, idempotency, rate limiting, and catalog
/// coverage consult per ADR-005.
Router buildB2bRoutes({
  required ConsultLogic consultLogic,
  required ApiKeyRepository apiKeyRepository,
  required B2bAuditRepository auditRepository,
  required IdempotencyRepository idempotencyRepository,
  required RateLimitRepository rateLimitRepository,
  required B2bConfig b2bConfig,
  required String apiVersion,
}) {
  final router = Router();

  router.post('/consult', (Request request) async {
    final started = DateTime.now().toUtc();
    final correlationId =
        request.context['correlation_id']?.toString() ?? 'none';
    final baseContext = httpLogContext(request: request);

    Response reject(
      int status,
      String code,
      String message, {
      String? field,
      int? cardIndex,
      Map<String, dynamic>? extra,
      String? auditOutcome,
    }) {
      AppLogger.warning(
        _loggerName,
        'B2B consult rejected',
        context: {
          ...baseContext,
          'error_code': code,
          'status_code': status,
          'correlation_id': correlationId,
          if (field != null) 'field': field,
          if (cardIndex != null) 'card_index': cardIndex,
          if (extra != null) ...extra,
        },
      );

      if (auditOutcome != null) {
        AppLogger.audit(
          _loggerName,
          AuditEventTypes.b2bCatalogConsult,
          result: 'failure',
          context: {
            ...baseContext,
            'outcome': auditOutcome,
            'error_code': code,
            'correlation_id': correlationId,
          },
        );
      }

      return jsonResponse(
        status,
        {
          'error': {
            'code': code,
            'message': message,
            if (field != null) 'field': field,
            if (cardIndex != null) 'card_index': cardIndex,
            'correlation_id': correlationId,
          },
        },
        headers: extra?['retry_after'] != null
            ? {'Retry-After': extra!['retry_after'].toString()}
            : null,
      );
    }

    final apiKey = request.headers['authorization'] ?? '';

    int apiKeyId, customerId;

    try {
      B2bAuthContext auth =
          await B2bValidators.validateKey(apiKey, apiKeyRepository);
      apiKeyId = auth.apiKeyId;
      customerId = auth.customerId;
    } on B2bException catch (error) {
      final extra = error.apiKeyId != null && error.customerId != null
          ? {'customer_id': error.customerId, 'api_key_id': error.apiKeyId}
          : null;
      return reject(error.code, error.err_type, error.message,
          extra: extra, auditOutcome: 'auth_invalid');
    }

    final payload = await readJson(request);
    final requestContext = httpLogContext(
      request: request,
      body: b2bConsultBodySummary(payload),
      extra: {
        'api_key_id': apiKeyId,
        'customer_id': customerId,
        'correlation_id': correlationId,
      },
    );

    AppLogger.info(
      _loggerName,
      'B2B catalog consult request',
      context: requestContext,
    );

    List<B2bConsultCardInput> input;
    try {
      input = B2bValidators.validateCardsField(payload['cards']);
    } on B2bException catch (error) {
      final extra = error.apiKeyId != null && error.customerId != null
          ? {'api_key_id': error.apiKeyId, 'customer_id': error.customerId}
          : null;
      return reject(error.code, error.err_type, error.message, extra: extra);
    }

    final clientRequestId = request.headers['x-request-id'];
    if (clientRequestId != null && clientRequestId.trim().isNotEmpty) {
      final cached = await idempotencyRepository.find(
        apiKeyId: auth.apiKeyId,
        requestId: clientRequestId.trim(),
      );
      if (cached != null) {
        AppLogger.info(
          _loggerName,
          'B2B consult idempotency replay',
          context: {
            ...requestContext,
            'request_id': clientRequestId.trim(),
            'idempotency': 'replay',
          },
        );

        final body = Map<String, dynamic>.from(cached.responsePayload);
        body.remove('etag');
        body.remove('last_modified');
        return _consultResponse(
          200,
          body,
          etag: cached.etag,
          lastModified: cached.lastModified,
        );
      }
    }

    final ifNoneMatch = request.headers['if-none-match'];

    try {
      final retryAfter = await rateLimitRepository.tryConsume(
        apiKeyId: auth.apiKeyId,
        cardCount: cards.length,
        monthlyLimit: b2bConfig.rateLimitCardsPerMonth,
      );

      if (retryAfter != null) {
        return reject(
          429,
          'RATE_LIMIT_EXCEEDED',
          'Monthly card consult quota exceeded',
          extra: {
            'api_key_id': auth.apiKeyId,
            'customer_id': auth.customerId,
            'card_count': cards.length,
            'retry_after': retryAfter,
          },
          auditOutcome: 'rate_limited',
        );
      }

      final result = await consultLogic.consult(input);

      if (ifNoneMatch != null && ifNoneMatch.trim() == result.etag) {
        AppLogger.info(
          _loggerName,
          'B2B consult not modified',
          context: {
            ...requestContext,
            'etag': result.etag,
            'status_code': 304,
          },
        );

        return Response(
          304,
          headers: {
            'ETag': result.etag,
            'Last-Modified': _formatHttpDate(result.lastModified),
          },
        );
      }

      final responseBody = result.toJson();
      final storedPayload = {
        ...responseBody,
        'etag': result.etag,
        'last_modified': result.lastModified.toIso8601String(),
      };

      final ip = request.headers['x-forwarded-for'] ??
          request.headers['x-real-ip'] ??
          'unknown';

      await auditRepository.recordConsult(
        apiKeyId: auth.apiKeyId,
        customerId: auth.customerId,
        requestId: clientRequestId?.trim(),
        ipAddress: ip,
        cardCount: cards.length,
        apiVersion: apiVersion,
        outcome: 'success',
      );

      AppLogger.audit(
        _loggerName,
        AuditEventTypes.b2bCatalogConsult,
        result: 'success',
        context: {
          ...requestContext,
          'card_count': cards.length,
          'outcome': 'success',
        },
      );

      if (clientRequestId != null && clientRequestId.trim().isNotEmpty) {
        final requestHash =
            sha256.convert(utf8.encode(jsonEncode(payload))).toString();
        await idempotencyRepository.store(
          apiKeyId: auth.apiKeyId,
          requestId: clientRequestId.trim(),
          requestHash: requestHash,
          responsePayload: storedPayload,
          expiresAt: DateTime.now().toUtc().add(
                Duration(seconds: b2bConfig.idempotencyTtlSeconds),
              ),
        );

        AppLogger.info(
          _loggerName,
          'B2B consult idempotency stored',
          context: {
            ...requestContext,
            'request_id': clientRequestId.trim(),
            'idempotency_ttl_seconds': b2bConfig.idempotencyTtlSeconds,
          },
        );
      }

      final durationMs =
          DateTime.now().toUtc().difference(started).inMilliseconds;
      AppLogger.metric(
        _loggerName,
        'b2b.consult.latency',
        context: {
          'duration_ms': durationMs,
          'card_count': cards.length,
          'status_code': 200,
          'api_key_id': auth.apiKeyId,
          'customer_id': auth.customerId,
        },
      );

      return _consultResponse(
        200,
        responseBody,
        etag: result.etag,
        lastModified: result.lastModified,
      );
    } on ConsultLogicException catch (error) {
      AppLogger.audit(
        _loggerName,
        AuditEventTypes.b2bCatalogConsult,
        result: 'failure',
        context: {
          ...requestContext,
          'error_code': error.code,
          'error_message': error.message,
        },
      );

      return reject(
        b2bStatusCodeFor(error.code),
        error.code,
        error.message,
        extra: {
          'api_key_id': auth.apiKeyId,
          'customer_id': auth.customerId,
        },
      );
    } catch (error, stack) {
      AppLogger.error(
        _loggerName,
        'B2B consult failed',
        error: error,
        stackTrace: stack,
        context: requestContext,
      );
      return reject(
        500,
        'INTERNAL_ERROR',
        'An unexpected error occurred',
        extra: {
          'api_key_id': auth.apiKeyId,
          'customer_id': auth.customerId,
        },
        auditOutcome: 'internal_error',
      );
    }
  });

  return router;
}

/// Parses `Authorization: ApiKey <plaintext>` header value.
String? _parseApiKey(String authorization) {
  final key = authorization.trim();
  return key.isEmpty ? null : key;
}

/// JSON response with caching headers for consult results.
Response _consultResponse(
  int status,
  Map<String, dynamic> body, {
  required String etag,
  required DateTime lastModified,
}) {
  return jsonResponse(
    status,
    body,
    headers: {
      'ETag': etag,
      'Last-Modified': _formatHttpDate(lastModified),
    },
  );
}

/// Formats a UTC timestamp for the HTTP `Last-Modified` header.
String _formatHttpDate(DateTime date) {
  final utc = date.toUtc();
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[utc.weekday - 1];
  final month = months[utc.month - 1];
  return '$weekday, ${utc.day.toString().padLeft(2, '0')} $month ${utc.year} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}:'
      '${utc.second.toString().padLeft(2, '0')} GMT';
}
