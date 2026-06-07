/// @file
/// @brief

import 'search_card/visual_features.dart';

/// @brief PokemonCardStatus
enum PokemonCardStatus {
  pendingValidation,
  validated,
  rejected,
}

/// @brief PokemonCard
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
  final VisualFeatures? visualFeatures;
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
    this.visualFeatures,
    this.status = PokemonCardStatus.pendingValidation,
    this.isActive = true,
    this.audit = const [],
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
    String? rarity,
    String? pokemonType,
    int? hp,
    String? illustrator,
    int? year,
    String? createdBy,
    String? backImageData,
    VisualFeatures? visualFeatures,
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
      visualFeatures: visualFeatures ?? this.visualFeatures,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      audit: audit ?? this.audit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
