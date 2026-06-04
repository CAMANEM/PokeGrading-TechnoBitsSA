import '../../domain/submitter_catalog/catalog_repository.dart';
import '../../domain/submitter_catalog/pokemon_card.dart';
import '../../domain/submitter_catalog/search_card/visual_features.dart';
import 'id_generator.dart';

class MockCatalogRepository implements CatalogRepository {
  final IdGenerator _idGenerator;
  final VisualFeatureExtractor _extractor;
  final Map<String, PokemonCard> _cardsById = <String, PokemonCard>{};
  final Set<String> _identityKeys = <String>{};
  final Map<String, List<String>> _featureIndex = <String, List<String>>{};

  MockCatalogRepository({IdGenerator? idGenerator, VisualFeatureExtractor? extractor})
      : _idGenerator = idGenerator ?? UuidIdGenerator(),
        _extractor = extractor ?? const VisualFeatureExtractor();

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

    final features = input.visualFeatures ??
        _extractor.extract(input.imageData);

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
      visualFeatures: features,
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
    _indexCard(card);
    return card;
  }

  @override
  Future<PokemonCard?> findById(String id) async {
    return _cardsById[id];
  }

  @override
  Future<List<PokemonCard>> searchCards() async {
    return _cardsById.values.toList();
  }

  Future<List<PokemonCard>> findByVisualFeatures(VisualFeatures query) async {
    final scores = <String, int>{};

    for (final hash in [query.averageHashHex, query.differenceHashHex]) {
      if (hash == null || hash.length != 16) continue;

      for (int i = 0; i < 4; i++) {
        final chunk = hash.substring(i * 4, (i + 1) * 4);
        final prefix = hash == query.averageHashHex ? 'ahash' : 'dhash';
        final key = '$prefix:chunk$i:$chunk';
        final ids = _featureIndex[key];
        if (ids != null) {
          for (final id in ids) {
            scores.update(id, (v) => v + 1, ifAbsent: () => 1);
          }
        }
      }
    }

    final sortedIds = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedIds
        .map((e) => _cardsById[e.key])
        .where((card) => card != null)
        .cast<PokemonCard>()
        .toList();
  }

  @override
  Future<List<PokemonCard>> fuzzySearchCards(String query) async {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return [];

    final results = <_FuzzyMatch>[];
    final terms = lowerQuery.split(RegExp(r'\s+'));

    for (final card in _cardsById.values) {
      int score = 0;
      final cardSet = card.set.toLowerCase();
      final cardNumber = card.number.toLowerCase();
      final cardName = card.displayName?.toLowerCase() ?? '';

      for (final term in terms) {
        if (cardSet == term) score += 10;
        else if (cardSet.contains(term)) score += 5;
        if (cardNumber == term) score += 10;
        else if (cardNumber.startsWith(term)) score += 4;
        if (cardName == term) score += 8;
        else if (cardName.contains(term)) score += 3;
      }

      if (score > 0) {
        results.add(_FuzzyMatch(card: card, score: score));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));

    return results.map((r) => r.card).toList();
  }

  void _indexCard(PokemonCard card) {
    final features = card.visualFeatures;
    if (features == null) return;

    for (final entry in [
      if (features.averageHashHex != null)
        MapEntry('ahash', features.averageHashHex!),
      if (features.differenceHashHex != null)
        MapEntry('dhash', features.differenceHashHex!),
    ]) {
      final hash = entry.value;
      if (hash.length != 16) continue;

      for (int i = 0; i < 4; i++) {
        final chunk = hash.substring(i * 4, (i + 1) * 4);
        final key = '${entry.key}:chunk$i:$chunk';
        _featureIndex.putIfAbsent(key, () => <String>[]).add(card.id);
      }
    }
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

class _FuzzyMatch {
  final PokemonCard card;
  final int score;

  const _FuzzyMatch({required this.card, required this.score});
}
