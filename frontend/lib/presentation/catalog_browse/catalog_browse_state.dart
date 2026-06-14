/// @file
/// @brief State models for catalog browse UI.

enum CatalogBrowseTab { submitter, reference }

enum CatalogBrowseStage { idle, loading, loaded, error }

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

  factory CatalogCardSummary.fromJson(Map<String, dynamic> json) {
    return CatalogCardSummary(
      id: json['id'].toString(),
      source: json['source']?.toString() ?? '',
      displayName: json['display_name']?.toString(),
      set: json['set']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      edition: json['edition']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      finish: json['finish']?.toString() ?? '',
      rarity: json['rarity']?.toString(),
      pokemonType: json['type']?.toString(),
      hp: json['hp'] as int?,
      active: json['active'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      hasImages: json['has_images'] as bool? ?? false,
    );
  }

  String get title {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    return '$set #$number';
  }
}

class CatalogCardDetail {
  final CatalogCardSummary summary;
  final String? frontImageData;
  final String? backImageData;

  const CatalogCardDetail({
    required this.summary,
    this.frontImageData,
    this.backImageData,
  });

  factory CatalogCardDetail.fromJson(Map<String, dynamic> json) {
    final cardJson = json['card'] as Map<String, dynamic>? ?? json;
    return CatalogCardDetail(
      summary: CatalogCardSummary.fromJson(cardJson),
      frontImageData: json['front_image_data']?.toString(),
      backImageData: json['back_image_data']?.toString(),
    );
  }
}

class CatalogBrowseState {
  final CatalogBrowseTab tab;
  final CatalogBrowseStage stage;
  final List<CatalogCardSummary> cards;
  final String? errorMessage;
  final CatalogCardDetail? selectedDetail;
  final bool loadingDetail;

  const CatalogBrowseState({
    this.tab = CatalogBrowseTab.submitter,
    this.stage = CatalogBrowseStage.idle,
    this.cards = const [],
    this.errorMessage,
    this.selectedDetail,
    this.loadingDetail = false,
  });

  CatalogBrowseState copyWith({
    CatalogBrowseTab? tab,
    CatalogBrowseStage? stage,
    List<CatalogCardSummary>? cards,
    String? errorMessage,
    CatalogCardDetail? selectedDetail,
    bool clearSelectedDetail = false,
    bool? loadingDetail,
  }) {
    return CatalogBrowseState(
      tab: tab ?? this.tab,
      stage: stage ?? this.stage,
      cards: cards ?? this.cards,
      errorMessage: errorMessage,
      selectedDetail:
          clearSelectedDetail ? null : (selectedDetail ?? this.selectedDetail),
      loadingDetail: loadingDetail ?? this.loadingDetail,
    );
  }
}
