/*
 Domain entity representing a submitted Pokemon card.

 `PokemonCard` is an immutable value object that contains identity fields
 (set, number, edition, language, finish), image payloads and optional
 metadata. The `status` field represents the moderation workflow state and
 `audit` holds an append-only list of events recorded by persistence or
 business logic.
*/

/*
 Represents the moderation/validation status of a Pokemon card.
 - `pendingValidation`: newly created and awaiting validation by the system or human reviewer.
 - `validated`: accepted into the reference catalog.
 - `rejected`: rejected due to identity/image/metadata validation.
*/
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
  final String? rarity;
  final String? pokemonType;
  final int? hp;
  final String? illustrator;
  final int? year;
  final String? createdBy;
  final String? backImageData;
  final PokemonCardStatus status;
  final bool isActive;
  final List<Map<String, dynamic>> audit;
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
    this.rarity,
    this.pokemonType,
    this.hp,
    this.illustrator,
    this.year,
    this.createdBy,
    this.backImageData,
    this.status = PokemonCardStatus.pendingValidation,
    this.isActive = true,
    this.audit = const [],
    required this.createdAt,
  });

  /*
   Returns a copy of the card with specified fields replaced. Useful
   when updating metadata or status while preserving immutability.
  */
  PokemonCard copyWith({
    String? id,
    String? set,
    String? number,
    String? edition,
    String? language,
    String? finish,
    String? displayName,
    String? imageData,
    String? rarity,
    String? pokemonType,
    int? hp,
    String? illustrator,
    int? year,
    String? createdBy,
    String? backImageData,
    PokemonCardStatus? status,
    bool? isActive,
    List<Map<String, dynamic>>? audit,
    DateTime? createdAt,
  }) {
    return PokemonCard(
      id: id ?? this.id,
      set: set ?? this.set,
      number: number ?? this.number,
      edition: edition ?? this.edition,
      language: language ?? this.language,
      finish: finish ?? this.finish,
      imageData: imageData ?? this.imageData,
      displayName: displayName ?? this.displayName,
      rarity: rarity ?? this.rarity,
      pokemonType: pokemonType ?? this.pokemonType,
      hp: hp ?? this.hp,
      illustrator: illustrator ?? this.illustrator,
      year: year ?? this.year,
      createdBy: createdBy ?? this.createdBy,
      backImageData: backImageData ?? this.backImageData,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      audit: audit ?? this.audit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
