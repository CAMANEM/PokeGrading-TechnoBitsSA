/*
 Repository contract for submitter catalog persistence.

 Implementations of `CatalogRepository` provide methods to check for
 identity tuple collisions, persist a new `PokemonCard` and query by id.
*/
import '../../domain/catalog/catalog_models.dart';
import '../../domain/image_services/visual_features.dart';
import '../../domain/scoring/grading/baseline_calibrator.dart';

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
  final double? psaGrade;
  final Map<String, dynamic>? gradingFeaturesJson;

  const AddPokemonCardInput({
    required this.identity,
    required this.imageData,
    this.display,
    this.backImageData,
    this.visualFeatures,
    this.psaGrade,
    this.gradingFeaturesJson,
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

  /// Finds all graded reference cards for a (set, finish) combination.
  /// Used by the calibration pipeline to build GradedCardRecord lists.
  Future<List<GradedCardRecord>> findGradedCardsForCalibration({
    required String set,
    required String finish,
  });
}
