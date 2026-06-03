/*
 Mock in-memory implementation of `CatalogRepository` for development and tests.

 Behavior:
 - Generates card IDs using an `IdGenerator` (UUID by default).
 - Persists `PokemonCard` instances in a memory map and tracks identity
   tuples to prevent duplicates.
 - Records a simple `audit` entry when a card is created.
*/
import '../../domain/submitter_catalog/catalog_repository.dart';
import '../../domain/submitter_catalog/pokemon_card.dart';
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
      rarity: input.rarity,
      pokemonType: input.pokemonType,
      hp: input.hp,
      illustrator: input.illustrator,
      year: input.year,
      createdBy: input.author,
      backImageData: input.backImageData,
      status: PokemonCardStatus.pendingValidation,
      isActive: true,
      audit: [
        {
          'action': 'created',
          'author': input.author,
          'timestamp': now.toIso8601String(),
          'data': {
            'set': input.set,
            'number': input.number,
            'edition': input.edition,
            'language': input.language,
            'finish': input.finish,
          }
        }
      ],
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

  @override
  Future<List<PokemonCard>> searchCards({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) {
      return _cardsById.values.toList().skip(offset).take(limit).toList();
    }

    final results = _cardsById.values.where((card) {
      final matchesSet = card.set.toLowerCase().contains(lowerQuery);
      final matchesNumber = card.number.toLowerCase().contains(lowerQuery);
      final matchesDisplayName = card.displayName?.toLowerCase().contains(lowerQuery) ?? false;
      final matchesEdition = card.edition.toLowerCase().contains(lowerQuery);
      return matchesSet || matchesNumber || matchesDisplayName || matchesEdition;
    }).toList();

    return results.skip(offset).take(limit).toList();
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
