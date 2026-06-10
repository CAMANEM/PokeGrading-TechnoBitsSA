/// @file
/// @brief

import 'package:uuid/uuid.dart';

import '../image_services/confidence_score.dart';
import 'search_trace.dart';
import '../image_services/visual_features.dart';
import 'catalog_models.dart';

import '../../persistence/card_data_provider/catalog_repository.dart';
import '../../persistence/card_data_provider/search_trace_repository.dart';

/// @brief SearchByImageCommand
class SearchByImageCommand {
  final String imageData;
  final ConfidenceType mode;

  const SearchByImageCommand({
    required this.imageData,
    required this.mode,
  });
}

/// @brief SearchResultType
enum SearchResultType {
  manualSearchRequired,
  singleCandidate,
  multipleCandidates,
  notFound
}

/// @brief SearchCandidate
class SearchCandidate {
  final PokemonCard card;
  final double confidence;

  const SearchCandidate({
    required this.card,
    required this.confidence,
  });
}

/// @brief SearchCardResult
class SearchCardResult {
  final SearchResultType type;
  final List<SearchCandidate> candidates;
  final String? reason;

  const SearchCardResult(
      {required this.type,
      this.candidates = const <SearchCandidate>[],
      this.reason});
}

/// @brief SearchLogic
class SearchCardLogic {
  final CatalogRepository repository;
  static const double acceptedConfidence = 90.0;
  final SearchTraceRepository? traceRepository;

  SearchCardLogic({required this.repository, this.traceRepository});

  Future<SearchCardResult> searchByImg(SearchByImageCommand command) async {
    final queryFeatures = VisualFeatureExtractor.extract(command.imageData);

    if (queryFeatures.isEmpty) {
      await _recordTrace(
        method: 'image',
        queryFeatures: queryFeatures,
        candidates: [],
        decision: 'manual_search_required',
        decisionReason: 'Failed to extract visual features from image',
      );
      return SearchCardResult(
          type: SearchResultType.manualSearchRequired,
          candidates: [],
          reason: "No se pudieron extraer caracteristicas visuales");
    }

    var searchCards = await repository.findByVisualFeatures(queryFeatures);

    if (searchCards.isEmpty) {
      searchCards = await repository.searchCards();
    }

    final scored = <SearchCandidate>[];

    for (final card in searchCards) {
      final score = ConfidenceScore.calculateConfidence(
          queryFeatures, card.visualFeatures!, command.mode);

      scored.add(SearchCandidate(card: card, confidence: score));
    }

    scored.sort((a, b) => b.confidence.compareTo(a.confidence));

    if (scored.isNotEmpty && scored.first.confidence >= acceptedConfidence) {
      await _recordTrace(
        method: 'image',
        queryFeatures: queryFeatures,
        candidates: scored,
        decision: 'auto_accept',
        decisionReason:
            'Top candidate confidence ${scored.first.confidence.toStringAsFixed(1)}% >= threshold $acceptedConfidence%',
      );
      return SearchCardResult(
        type: SearchResultType.singleCandidate,
        candidates: [scored.first],
      );
    }

    if (scored.isEmpty) {
      await _recordTrace(
        method: 'image',
        queryFeatures: queryFeatures,
        candidates: [],
        decision: 'not_found',
        decisionReason: 'No candidates matched the visual features',
      );
      return SearchCardResult(
          type: SearchResultType.notFound,
          candidates: [],
          reason: "Ninguna carta fue encontrada");
    }

    await _recordTrace(
      method: 'image',
      queryFeatures: queryFeatures,
      candidates: scored,
      decision: 'multiple_candidates',
      decisionReason:
          'Top candidate confidence ${scored.first.confidence.toStringAsFixed(1)}% below threshold, showing top 3',
    );
    return SearchCardResult(
      type: SearchResultType.multipleCandidates,
      candidates: scored.take(3).toList(),
    );
  }

  Future<SearchCardResult> searchByMetadata(CardIdentity command) async {
    final readCards = await repository.searchCards();

    for (final card in readCards) {
      if (command == card.identity) {
        final candidates = [SearchCandidate(card: card, confidence: 100.0)];
        await _recordTrace(
          method: 'manual',
          queryMetadata: command,
          candidates: candidates,
          decision: 'auto_accept',
          decisionReason: 'Exact identity match found for card ${card.id}',
        );
        return SearchCardResult(
            type: SearchResultType.singleCandidate, candidates: candidates);
      }
    }

    await _recordTrace(
      method: 'manual',
      queryMetadata: command,
      candidates: [],
      decision: 'not_found',
      decisionReason: 'No exact match found',
    );

    return SearchCardResult(
        type: SearchResultType.notFound,
        candidates: <SearchCandidate>[],
        reason: "No se encontro ninguna carta");
  }

  Future<void> _recordTrace({
    required String method,
    VisualFeatures? queryFeatures,
    CardIdentity? queryMetadata,
    required List<SearchCandidate> candidates,
    required String decision,
    String? decisionReason,
  }) async {
    final repo = traceRepository;
    if (repo == null) return;

    final trace = SearchTrace(
      id: const Uuid().v4(),
      timestamp: DateTime.now().toUtc(),
      method: method,
      queryFeatures: queryFeatures,
      queryMetadata: queryMetadata,
      candidates: candidates.map((c) {
        return ScoredCandidateEntry(
          cardId: c.card.id,
          displayName: c.card.display?.displayName,
          confidence: c.confidence,
        );
      }).toList(),
      decision: decision,
      decisionReason: decisionReason,
    );

    await repo.save(trace);
  }
}
