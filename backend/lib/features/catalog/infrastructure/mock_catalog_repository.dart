import '../domain/catalog_repository.dart';
import '../domain/pokemon_card.dart';
import 'id_generator.dart';

class MockCatalogRepository implements CatalogRepository {
  final IdGenerator _idGenerator;
  final Map<String, PokemonCard> _cardsById = <String, PokemonCard>{};
  final Set<String> _identityKeys = <String>{};

  MockCatalogRepository({IdGenerator? idGenerator})
      : _idGenerator = idGenerator ?? UuidIdGenerator();

  @override
  Future<bool> identityTupleExists({
    required String set,
    required String number,
    required String edition,
    required String language,
    required String finish,
  }) async {
    final key = _identityKey(
      set: set,
      number: number,
      edition: edition,
      language: language,
      finish: finish,
    );
    return _identityKeys.contains(key);
  }

  @override
  Future<PokemonCard> saveCard(AddPokemonCardInput input) async {
    final id = _idGenerator.generateCardId();
    final now = DateTime.now().toUtc();
    final card = PokemonCard(
      id: id,
      set: input.set.trim(),
      number: input.number.trim(),
      edition: input.edition.trim(),
      language: input.language.trim(),
      finish: input.finish.trim(),
      displayName: input.displayName?.trim().isEmpty == true
          ? null
          : input.displayName?.trim(),
      imageData: input.imageData.trim(),
      status: PokemonCardStatus.pendingValidation,
      createdAt: now,
    );

    final key = _identityKey(
      set: card.set,
      number: card.number,
      edition: card.edition,
      language: card.language,
      finish: card.finish,
    );

    _cardsById[id] = card;
    _identityKeys.add(key);
    return card;
  }

  @override
  Future<PokemonCard?> findById(String id) async {
    return _cardsById[id];
  }

  String _identityKey({
    required String set,
    required String number,
    required String edition,
    required String language,
    required String finish,
  }) {
    return [set, number, edition, language, finish]
        .map((value) => value.trim().toLowerCase())
        .join('|');
  }
}
