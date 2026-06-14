/// @file
/// @brief Catalog browse use-cases for submitter and reference cards.

import '../../persistence/b2b_data_provider/reference_browse_repository.dart';
import '../../persistence/card_data_provider/catalog_repository.dart';
import '../../persistence/image_provider/image_storage_repository.dart';
import 'card_browse_models.dart';
import 'catalog_models.dart';

/// Loads catalog summaries and card details for the browse UI.
class CardBrowseLogic {
  final CatalogRepository catalogRepository;
  final ReferenceBrowseRepository referenceBrowseRepository;
  final ImageStorageRepository? imageRepository;

  CardBrowseLogic({
    required this.catalogRepository,
    required this.referenceBrowseRepository,
    this.imageRepository,
  });

  Future<List<CatalogCardSummary>> listSubmitterCards() async {
    final cards = await catalogRepository.searchCards();
    return cards.map(_submitterSummaryFromCard).toList();
  }

  Future<CatalogCardDetail?> getSubmitterCardDetail(String id) async {
    final card = await catalogRepository.findById(id);
    if (card == null) return null;

    final summary = _submitterSummaryFromCard(card);
    String? front = card.imageData.isNotEmpty ? card.imageData : null;
    String? back = card.backImageData;

    final parsedId = int.tryParse(id);
    if (imageRepository != null && parsedId != null) {
      final images = await imageRepository!.loadSubmitterImages(parsedId);
      if (images != null) {
        front = images.front;
        back = images.back;
      }
    }

    return CatalogCardDetail(
      summary: summary.copyWith(hasImages: front != null || back != null),
      frontImageData: front,
      backImageData: back,
    );
  }

  Future<List<CatalogCardSummary>> listReferenceCards() async {
    return referenceBrowseRepository.listCards();
  }

  Future<CatalogCardDetail?> getReferenceCardDetail(String id) async {
    final summary = await referenceBrowseRepository.findSummaryById(id);
    if (summary == null) return null;

    return CatalogCardDetail(summary: summary);
  }

  CatalogCardSummary _submitterSummaryFromCard(PokemonCard card) {
    final hasImages = card.imageData.isNotEmpty ||
        (card.backImageData != null && card.backImageData!.isNotEmpty);

    return CatalogCardSummary(
      id: card.id,
      source: 'submitter',
      displayName: card.display?.displayName,
      set: card.identity.set,
      number: card.identity.number,
      edition: card.identity.edition,
      language: card.identity.language,
      finish: card.identity.finish,
      rarity: card.display?.rarity,
      pokemonType: card.display?.pokemonType,
      hp: card.display?.hp,
      active: card.isActive,
      createdAt: card.createdAt,
      hasImages: hasImages,
    );
  }
}

extension on CatalogCardSummary {
  CatalogCardSummary copyWith({
    bool? hasImages,
  }) {
    return CatalogCardSummary(
      id: id,
      source: source,
      displayName: displayName,
      set: set,
      number: number,
      edition: edition,
      language: language,
      finish: finish,
      rarity: rarity,
      pokemonType: pokemonType,
      hp: hp,
      active: active,
      createdAt: createdAt,
      hasImages: hasImages ?? this.hasImages,
    );
  }
}
