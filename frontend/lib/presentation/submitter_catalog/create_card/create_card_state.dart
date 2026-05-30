enum CreateCardStage {
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

class CreateCardPayload {
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

  const CreateCardPayload({
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

class CreateCardResult {
  final String cardId;
  final String cardStatus;
  final DateTime createdAt;

  const CreateCardResult({
    required this.cardId,
    required this.cardStatus,
    required this.createdAt,
  });
}

class CreateCardState {
  final CreateCardStage stage;
  final CardIdentityInput? identity;
  final String? displayName;
  final CreateCardResult? result;
  final String? message;

  const CreateCardState({
    required this.stage,
    this.identity,
    this.displayName,
    this.result,
    this.message,
  });

  const CreateCardState.initial()
      : stage = CreateCardStage.identity,
        identity = null,
        displayName = null,
        result = null,
        message = null;

  CreateCardState copyWith({
    CreateCardStage? stage,
    CardIdentityInput? identity,
    String? displayName,
    CreateCardResult? result,
    String? message,
  }) {
    return CreateCardState(
      stage: stage ?? this.stage,
      identity: identity ?? this.identity,
      displayName: displayName ?? this.displayName,
      result: result ?? this.result,
      message: message,
    );
  }
}
