/// @file
/// @brief Summary models for catalog browse UI.

/// Lightweight card row for list endpoints (no image payloads).
class CatalogCardSummary {
  final String id;
  final String source;
  final String? displayName;
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;
  final String? rarity;
  final String? pokemonType;
  final int? hp;
  final bool active;
  final DateTime? createdAt;
  final bool hasImages;

  const CatalogCardSummary({
    required this.id,
    required this.source,
    this.displayName,
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
    this.rarity,
    this.pokemonType,
    this.hp,
    required this.active,
    this.createdAt,
    required this.hasImages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'display_name': displayName,
        'set': set,
        'number': number,
        'edition': edition,
        'language': language,
        'finish': finish,
        if (rarity != null) 'rarity': rarity,
        if (pokemonType != null) 'type': pokemonType,
        if (hp != null) 'hp': hp,
        'active': active,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        'has_images': hasImages,
      };
}

/// Full card detail including optional image data URLs.
class CatalogCardDetail {
  final CatalogCardSummary summary;
  final String? frontImageData;
  final String? backImageData;

  const CatalogCardDetail({
    required this.summary,
    this.frontImageData,
    this.backImageData,
  });

  Map<String, dynamic> toJson() => {
        'card': summary.toJson(),
        if (frontImageData != null) 'front_image_data': frontImageData,
        if (backImageData != null) 'back_image_data': backImageData,
      };
}
