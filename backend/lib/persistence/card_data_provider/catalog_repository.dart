/*
 Repository contract for submitter catalog persistence.

 Implementations of `CatalogRepository` provide methods to check for
 identity tuple collisions, persist a new `PokemonCard` and query by id.
*/
import '../../domain/catalog/catalog_models.dart';
import '../../domain/image_services/visual_features.dart';

/*
 Input DTO used by the repository to persist a new Pokemon card.
*/

/// @brief AddPokemonCardInput
class AddPokemonCardInput {
  final CardIdentity identity;
  final CardDisplay? display;
  final String imageData;
  final String? backImageData;
  final VisualFeatures? visualFeatures;

  const AddPokemonCardInput({
    required this.identity,
    required this.imageData,
    this.display,
    this.backImageData,
    this.visualFeatures,
  });
}

/// @brief CatalogRepository
abstract class CatalogRepository {
  Future<bool> identityTupleExists({required CardIdentity identity});

  Future<PokemonCard> saveCard(AddPokemonCardInput input);

  Future<PokemonCard?> findById(String id);

  Future<List<PokemonCard>> searchCards();

  Future<List<PokemonCard>> findByVisualFeatures(VisualFeatures query);

  Future<List<PokemonCard>> fuzzySearchCards(String query);
}
