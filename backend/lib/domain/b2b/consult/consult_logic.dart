/// @file
/// @brief Domain logic for batch B2B catalog coverage consult.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/logging/app_logger.dart';
import '../b2b_models.dart';
import '../b2b_validators.dart';
import '../../../persistence/b2b_data_provider/reference_catalog_repository.dart';
import '../../../persistence/b2b_data_provider/idempotency_repository.dart';
import '../../../persistence/b2b_data_provider/b2b_audit_repository.dart';

/// Orchestrates batch catalog coverage lookup for B2B customers.
///
/// Validates each card independently, queries the reference catalog, and
/// aggregates per-card statuses (`COVERED`, `MULTIPLE_MATCH`, etc.).
class ConsultLogic {
  static const _loggerName = 'PokéGrading.B2B.Consult';

  final ReferenceCatalogRepository catalogRepository;
  final int maxCardsPerRequest;

  ConsultLogic({
    required this.catalogRepository,
    required this.maxCardsPerRequest,
  });

  /// Runs catalog coverage lookup for a batch of cards.
  ///
  /// Throws [ConsultLogicException] when the envelope is invalid (empty or
  /// too many cards). Per-card validation failures are returned as
  /// `INVALID_PARAMETERS` without aborting the batch.
  Future<B2bConsultResult> consult(List<B2bConsultCardInput> cards) async {
    final started = DateTime.now().toUtc();

    if (cards.isEmpty) {
      throw ConsultLogicException(
        code: 'EMPTY_CARDS',
        message: 'Request must include at least one card',
      );
    }

    if (cards.length > maxCardsPerRequest) {
      throw ConsultLogicException(
        code: 'TOO_MANY_CARDS',
        message:
            'Request exceeds maximum of $maxCardsPerRequest cards per consult',
      );
    }

    final results = <B2bConsultCardResult>[];
    DateTime? maxModified = null;
    var covered = 0;
    var multiple = 0;
    var notCovered = 0;
    var invalid = 0;

    for (final card in cards) {
      final validationError = B2bValidators.validateCard(card);
      if (validationError != null) {
        invalid++;
        results.add(B2bConsultCardResult(
          status: B2bConsultStatus.invalidParameters,
          reason: validationError.message,
          field: validationError.field,
        ));
        continue;
      }

      final languageLookup = card.language != null && card.language!.isNotEmpty
          ? B2bValidators.lookupNameForLanguageCode(card.language!)
          : null;

      final matches = await catalogRepository.findActiveMatches(
        set: card.set,
        number: card.number,
        edition: card.edition,
        languageLookupName: languageLookup,
        finish: card.finish,
      );

      for (final match in matches) {
        if (match.modificationDate != null) {
          if (maxModified == null ||
              match.modificationDate!.isAfter(maxModified)) {
            maxModified = match.modificationDate;
          }
        }
      }

      if (matches.isEmpty) {
        notCovered++;
        results.add(const B2bConsultCardResult(
          status: B2bConsultStatus.notCovered,
        ));
      } else if (matches.length == 1) {
        covered++;
        final match = matches.first;
        results.add(B2bConsultCardResult(
          status: B2bConsultStatus.covered,
          cardId: match.id,
          identity: match.identity,
        ));
      } else {
        multiple++;
        results.add(B2bConsultCardResult(
          status: B2bConsultStatus.multipleMatch,
          candidates: matches
              .map((m) => B2bConsultCandidate(
                    cardId: m.id,
                    identity: m.identity,
                  ))
              .toList(),
        ));
      }
    }

    final lastModified = maxModified ?? DateTime.now().toUtc();
    final etag = _computeEtag(results);

    final durationMs =
        DateTime.now().toUtc().difference(started).inMilliseconds;
    AppLogger.metric(
      _loggerName,
      'b2b.consult.batch',
      context: {
        'duration_ms': durationMs,
        'card_count': cards.length,
        'covered': covered,
        'multiple_match': multiple,
        'not_covered': notCovered,
        'invalid_parameters': invalid,
      },
    );

    return B2bConsultResult(
      results: results,
      etag: etag,
      lastModified: lastModified,
    );
  }

  Future<IdempotencyRecord?> consultIdempotency(int apiKey, String requestId,
      IdempotencyRepository idempotencyRepository) async {
    return await idempotencyRepository.find(
        apiKeyId: apiKey, requestId: requestId);
  }

  Future<void> recordAuditConsult(
      int apiKeyId,
      int customerId,
      String? clientRequestId,
      String ip,
      int cardCount,
      String apiVersion,
      B2bAuditRepository auditRepository) async {
    await auditRepository.recordConsult(
      apiKeyId: apiKeyId,
      customerId: customerId,
      requestId: clientRequestId?.trim(),
      ipAddress: ip,
      cardCount: cardCount,
      apiVersion: apiVersion,
      outcome: 'success',
    );
  }

  Future<void> recordIdempotency(
      String requestHash,
      int apiKeyId,
      String clientRequestId,
      Map<String, dynamic> storedPayload,
      int seconds,
      IdempotencyRepository idempotencyRepository) async {
    await idempotencyRepository.store(
      apiKeyId: apiKeyId,
      requestId: clientRequestId.trim(),
      requestHash: requestHash,
      responsePayload: storedPayload,
      expiresAt: DateTime.now().toUtc().add(
            Duration(seconds: seconds),
          ),
    );
  }

  String _computeEtag(List<B2bConsultCardResult> results) {
    final json = jsonEncode(results.map((r) => r.toJson()).toList());
    final hash = sha256.convert(utf8.encode(json)).toString();
    return '"$hash"';
  }
}

/// Domain error for invalid consult envelopes (not per-card validation).
class ConsultLogicException implements Exception {
  final String code;
  final String message;

  ConsultLogicException({required this.code, required this.message});
}
