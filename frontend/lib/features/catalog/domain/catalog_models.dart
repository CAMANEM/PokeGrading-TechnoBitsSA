enum CatalogFlowStage {
  identity,
  image,
  submitting,
  success,
  error,
}

class CardIdentityInput {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;

  const CardIdentityInput({
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
  });
}

class AddCardPayload {
  final CardIdentityInput identity;
  final String? displayName;
  final String? rarity;
  final String? pokemonType;
  final int? hp;
  final String? illustrator;
  final int? year;
  final String? author;
  final String imageData;
  final String? backImageData;

  const AddCardPayload({
    required this.identity,
    required this.imageData,
    this.displayName,
    this.rarity,
    this.pokemonType,
    this.hp,
    this.illustrator,
    this.year,
    this.author,
    this.backImageData,
  });
}

class AddCardResult {
  final String cardId;
  final String cardStatus;
  final DateTime createdAt;

  const AddCardResult({
    required this.cardId,
    required this.cardStatus,
    required this.createdAt,
  });
}

class CatalogSubmissionState {
  final CatalogFlowStage stage;
  final CardIdentityInput? identity;
  final String? displayName;
  final AddCardResult? result;
  final String? message;

  const CatalogSubmissionState({
    required this.stage,
    this.identity,
    this.displayName,
    this.result,
    this.message,
  });

  const CatalogSubmissionState.initial()
      : stage = CatalogFlowStage.identity,
        identity = null,
        displayName = null,
        result = null,
        message = null;

  CatalogSubmissionState copyWith({
    CatalogFlowStage? stage,
    CardIdentityInput? identity,
    String? displayName,
    AddCardResult? result,
    String? message,
  }) {
    return CatalogSubmissionState(
      stage: stage ?? this.stage,
      identity: identity ?? this.identity,
      displayName: displayName ?? this.displayName,
      result: result ?? this.result,
      message: message,
    );
  }
}
