/// @file
/// @brief

import '../image_services/visual_features.dart';

/// @brief PokemonCardStatus
enum PokemonCardStatus {
  pendingValidation,
  validated,
  rejected,
}

class CardIdentity {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;

  const CardIdentity(
      {required this.set,
      required this.number,
      required this.edition,
      required this.language,
      required this.finish});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardIdentity &&
          set == other.set &&
          number == other.number &&
          edition == other.edition &&
          language == other.language &&
          finish == other.finish;

  @override
  int get hashCode => Object.hash(set, number, edition, language, finish);
}

class CardDisplay {
  final String? displayName;
  final String? rarity;
  final String? pokemonType;
  final int? hp;
  final String? illustrator;
  final int? year;
  final String? author;

  const CardDisplay(
      {this.displayName,
      this.rarity,
      this.pokemonType,
      this.hp,
      this.illustrator,
      this.year,
      this.author});
}

/// @brief PokemonCard
class PokemonCard {
  final String id;
  final CardIdentity identity;
  final CardDisplay? display;
  final String imageData;
  final String? backImageData;
  final VisualFeatures? visualFeatures;
  final PokemonCardStatus status;
  final bool isActive;
  final List<Map<String, dynamic>> audit;
  final DateTime createdAt;

  const PokemonCard({
    required this.id,
    required this.identity,
    required this.imageData,
    this.display,
    this.backImageData,
    this.visualFeatures,
    this.status = PokemonCardStatus.pendingValidation,
    this.isActive = true,
    this.audit = const [],
    required this.createdAt,
  });

  PokemonCard copyWith({
    String? id,
    CardIdentity? identity,
    CardDisplay? display,
    String? imageData,
    String? backImageData,
    VisualFeatures? visualFeatures,
    PokemonCardStatus? status,
    bool? isActive,
    List<Map<String, dynamic>>? audit,
    DateTime? createdAt,
  }) {
    return PokemonCard(
      id: id ?? this.id,
      identity: identity ?? this.identity,
      display: display ?? this.display,
      imageData: imageData ?? this.imageData,
      backImageData: backImageData ?? this.backImageData,
      visualFeatures: visualFeatures ?? this.visualFeatures,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      audit: audit ?? this.audit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
