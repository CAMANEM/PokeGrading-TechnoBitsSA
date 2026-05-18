enum PokemonCardStatus {
  pendingValidation,
  validated,
  rejected,
}

class PokemonCard {
  final String id;
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;
  final String? displayName;
  final String imageData;
  final PokemonCardStatus status;
  final DateTime createdAt;

  const PokemonCard({
    required this.id,
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
    required this.imageData,
    this.displayName,
    this.status = PokemonCardStatus.pendingValidation,
    required this.createdAt,
  });

  PokemonCard copyWith({
    String? id,
    String? set,
    String? number,
    String? edition,
    String? language,
    String? finish,
    String? displayName,
    String? imageData,
    PokemonCardStatus? status,
    DateTime? createdAt,
  }) {
    return PokemonCard(
      id: id ?? this.id,
      set: set ?? this.set,
      number: number ?? this.number,
      edition: edition ?? this.edition,
      language: language ?? this.language,
      finish: finish ?? this.finish,
      displayName: displayName ?? this.displayName,
      imageData: imageData ?? this.imageData,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
