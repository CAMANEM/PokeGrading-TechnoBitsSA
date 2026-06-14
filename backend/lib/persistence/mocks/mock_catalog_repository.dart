/// @file
/// @brief

import '../card_data_provider/catalog_repository.dart';
import '../../domain/catalog/catalog_models.dart';
import '../../domain/image_services/hash_prefilter.dart';
import '../../domain/image_services/visual_features.dart';
import '../../shared/id_service/id_generator.dart';

/// @brief MockCatalogRepository
class MockCatalogRepository implements CatalogRepository {
  final IdGenerator _idGenerator;
  final Map<String, PokemonCard> _cardsById = <String, PokemonCard>{};
  final Set<String> _identityKeys = <String>{};

  MockCatalogRepository({IdGenerator? idGenerator})
      : _idGenerator = idGenerator ?? UuidIdGenerator();

  @override
  Future<bool> identityTupleExists({required CardIdentity identity}) async {
    final key = _identityKey(identity: identity);
    return _identityKeys.contains(key);
  }

  @override
  Future<PokemonCard> saveCard(AddPokemonCardInput input) async {
    final key = _identityKey(identity: input.identity);

    final id = _idGenerator.generateCardId();
    final now = DateTime.now().toUtc();

    final frontFeatures =
        input.visualFeatures ?? VisualFeatureExtractor.extract(input.imageData);
    final backFeatures = input.backImageData != null
        ? VisualFeatureExtractor.extract(input.backImageData!)
        : const VisualFeatures();
    final features = frontFeatures.withBackFrom(backFeatures);

    final card = PokemonCard(
      id: id,
      identity: input.identity,
      display: input.display,
      imageData: input.imageData.trim(),
      backImageData: input.backImageData,
      visualFeatures: features,
      status: PokemonCardStatus.pendingValidation,
      isActive: true,
      audit: [
        {
          'action': 'created',
          'author': input.display?.author,
          'timestamp': now.toIso8601String(),
          'data': {
            'set': input.identity.set,
            'number': input.identity.number,
            'edition': input.identity.edition,
            'language': input.identity.language,
            'finish': input.identity.finish,
          }
        }
      ],
      createdAt: now,
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
  Future<List<PokemonCard>> searchCards() async {
    return _cardsById.values.toList();
  }

  @override
  Future<List<PokemonCard>> findByVisualFeatures(VisualFeatures query) async {
    final scores = <String, int>{};

    for (final card in _cardsById.values) {
      final features = card.visualFeatures;
      if (features == null) continue;

      final score = scoreHashChunkOverlap(query, features);
      if (score > 0) {
        scores[card.id] = score;
      }
    }

    final sortedIds = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedIds
        .take(20)
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
      final cardSet = card.identity.set.toLowerCase();
      final cardNumber = card.identity.number.toLowerCase();
      final cardName = card.display?.displayName?.toLowerCase() ?? '';

      for (final term in terms) {
        if (cardSet == term) {
          score += 10;
        } else if (cardSet.contains(term)) {
          score += 5;
        }
        if (cardNumber == term) {
          score += 10;
        } else if (cardNumber.startsWith(term)) {
          score += 4;
        }
        if (cardName == term) {
          score += 8;
        } else if (cardName.contains(term)) {
          score += 3;
        }
      }

      if (score > 0) {
        results.add(_FuzzyMatch(card: card, score: score));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));

    return results.map((r) => r.card).toList();
  }

  String _identityKey({required CardIdentity identity}) {
    return [
      identity.set,
      identity.number,
      identity.edition,
      identity.language,
      identity.finish
    ].map((value) => value.trim().toLowerCase()).join('|');
  }
}

/// @brief _FuzzyMatch
class _FuzzyMatch {
  final PokemonCard card;
  final int score;

  const _FuzzyMatch({required this.card, required this.score});
}
