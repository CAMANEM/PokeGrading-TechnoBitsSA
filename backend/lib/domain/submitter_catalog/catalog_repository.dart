/*
 Repository contract for submitter catalog persistence.

 Implementations of `CatalogRepository` provide methods to check for
 identity tuple collisions, persist a new `PokemonCard` and query by id.
*/
import 'pokemon_card.dart';

/*
 Input DTO used by the repository to persist a new Pokemon card.
*/
class AddPokemonCardInput {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;
  final String? displayName;
  final String? rarity;
  final String? pokemonType;
  final int? hp;
  final String? illustrator;
  final int? year;
  final String? author;
  final String imageData;
  final String? backImageData;

  const AddPokemonCardInput({
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
    this.author,
    this.backImageData,
  });
}

/*
 Abstract repository interface for catalog operations.
*/
abstract class CatalogRepository {
  Future<bool> identityTupleExists({
    required String set,
    required String number,
    required String edition,
    required String language,
    required String finish,
  });

  Future<PokemonCard> saveCard(AddPokemonCardInput input);

  Future<PokemonCard?> findById(String id);
}
