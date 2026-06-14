/// @file
/// @brief Domain models for the B2B catalog coverage consult API.
library;

/// Canonical identity returned from the reference catalog.
class B2bCardIdentity {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;

  const B2bCardIdentity({
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
  });

  Map<String, dynamic> toJson() => {
        'set': set,
        'number': number,
        'edition': edition,
        'language': language,
        'finish': finish,
      };
}

/// Per-card consult status values from ADR-005.
enum B2bConsultStatus {
  covered,
  multipleMatch,
  notCovered,
  invalidParameters,
}

extension B2bConsultStatusJson on B2bConsultStatus {
  String get wireValue => switch (this) {
        B2bConsultStatus.covered => 'COVERED',
        B2bConsultStatus.multipleMatch => 'MULTIPLE_MATCH',
        B2bConsultStatus.notCovered => 'NOT_COVERED',
        B2bConsultStatus.invalidParameters => 'INVALID_PARAMETERS',
      };
}

/// Input card from the B2B request payload.
class B2bConsultCardInput {
  final String set;
  final String number;
  final String? edition;
  final String? language;
  final String? finish;

  const B2bConsultCardInput({
    required this.set,
    required this.number,
    this.edition,
    this.language,
    this.finish,
  });
}

/// Candidate in a multiple-match result.
class B2bConsultCandidate {
  final String cardId;
  final B2bCardIdentity identity;

  const B2bConsultCandidate({
    required this.cardId,
    required this.identity,
  });

  Map<String, dynamic> toJson() => {
        'card_id': cardId,
        'identity': identity.toJson(),
      };
}

/// Result for a single card in the consult batch.
class B2bConsultCardResult {
  final B2bConsultStatus status;
  final String? cardId;
  final B2bCardIdentity? identity;
  final List<B2bConsultCandidate>? candidates;
  final String? reason;
  final String? field;

  const B2bConsultCardResult({
    required this.status,
    this.cardId,
    this.identity,
    this.candidates,
    this.reason,
    this.field,
  });

  Map<String, dynamic> toJson() => {
        'status': status.wireValue,
        if (cardId != null) 'card_id': cardId,
        if (identity != null) 'identity': identity!.toJson(),
        if (candidates != null)
          'candidates': candidates!.map((c) => c.toJson()).toList(),
        if (reason != null) 'reason': reason,
        if (field != null) 'field': field,
      };
}

/// Full consult response payload.
class B2bConsultResult {
  final List<B2bConsultCardResult> results;
  final String etag;
  final DateTime lastModified;

  const B2bConsultResult({
    required this.results,
    required this.etag,
    required this.lastModified,
  });

  Map<String, dynamic> toJson() => {
        'results': results.map((r) => r.toJson()).toList(),
      };
}

/// Authenticated B2B context after API key validation.
class B2bAuthContext {
  final int apiKeyId;
  final int customerId;
  final String customerStatus;
  final String apiKeyStatus;

  const B2bAuthContext({
    required this.apiKeyId,
    required this.customerId,
    required this.customerStatus,
    required this.apiKeyStatus,
  });
}

/// Reference catalog card (lightweight DTO).
class ReferenceCard {
  final String id;
  final B2bCardIdentity identity;
  final DateTime? modificationDate;

  const ReferenceCard({
    required this.id,
    required this.identity,
    this.modificationDate,
  });
}
