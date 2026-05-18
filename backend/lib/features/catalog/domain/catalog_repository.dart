import 'pokemon_card.dart';

class AddPokemonCardInput {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;
  final String? displayName;
  final String imageData;

  const AddPokemonCardInput({
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
    required this.imageData,
    this.displayName,
  });
}

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
