/// @file
/// @brief In-memory reference catalog browse for mock mode.

import '../../domain/catalog/card_browse_models.dart';
import '../b2b_data_provider/reference_browse_repository.dart';

class MockReferenceBrowseRepository implements ReferenceBrowseRepository {
  final List<CatalogCardSummary> _cards;

  MockReferenceBrowseRepository({List<CatalogCardSummary>? cards})
      : _cards = cards ?? _defaultCards();

  static List<CatalogCardSummary> _defaultCards() {
    final now = DateTime.now().toUtc();
    return [
      CatalogCardSummary(
        id: '1',
        source: 'reference',
        displayName: 'Pikachu SVP 001',
        set: 'SVP',
        number: '1',
        edition: 'FIRST_EDITION',
        language: 'EN',
        finish: 'HOLO',
        active: true,
        createdAt: now,
        hasImages: false,
      ),
      CatalogCardSummary(
        id: '2',
        source: 'reference',
        displayName: 'Charizard SVP 002 Holo',
        set: 'SVP',
        number: '2',
        edition: 'FIRST_EDITION',
        language: 'EN',
        finish: 'HOLO',
        active: true,
        createdAt: now,
        hasImages: false,
      ),
      CatalogCardSummary(
        id: '3',
        source: 'reference',
        displayName: 'Charizard SVP 002 Normal',
        set: 'SVP',
        number: '2',
        edition: 'UNLIMITED',
        language: 'EN',
        finish: 'NORMAL',
        active: true,
        createdAt: now,
        hasImages: false,
      ),
    ];
  }

  @override
  Future<List<CatalogCardSummary>> listCards() async => List.of(_cards);

  @override
  Future<CatalogCardSummary?> findSummaryById(String id) async {
    for (final card in _cards) {
      if (card.id == id) return card;
    }
    return null;
  }
}
