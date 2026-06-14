/// @file
/// @brief Reference catalog lookup for B2B coverage consult.

import '../../domain/b2b/b2b_models.dart';

/// Lookup against the reference catalog (`card_reference`).
abstract class ReferenceCatalogRepository {
  Future<List<ReferenceCard>> findActiveMatches({
    required String set,
    required String number,
    String? edition,
    String? languageLookupName,
    String? finish,
  });
}
