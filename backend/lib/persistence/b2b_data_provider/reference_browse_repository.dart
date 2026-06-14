/// @file
/// @brief Browse API for reference catalog cards (`card_reference`).

import '../../domain/catalog/card_browse_models.dart';

abstract class ReferenceBrowseRepository {
  Future<List<CatalogCardSummary>> listCards();

  Future<CatalogCardSummary?> findSummaryById(String id);
}
