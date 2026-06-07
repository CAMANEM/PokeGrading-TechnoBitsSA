/// @file
/// @brief

import 'package:uuid/uuid.dart';

import 'confidence_score.dart';
import 'search_trace.dart';
import 'search_trace_repository.dart';
import 'visual_features.dart';
import '../catalog_repository.dart';
import '../pokemon_card.dart';

/// @brief SearchEvaluationLogicException
class SearchEvaluationLogicException implements Exception {
  /// Short error code for programmatic handling.
  final String code;

  /// Human readable message describing the reason for the exception.
  final String message;

  const SearchEvaluationLogicException(
      {required this.code, required this.message});

  @override
  String toString() => 'SubmitEvaluationLogicException($code): $message';
}

/// @brief SearchByImageCommand
class SearchByImageCommand {
  final String imageData;
  final int mode;

  const SearchByImageCommand({
    required this.imageData,
    required this.mode,
  });
}

/// @brief SearchByMetadataCommand
class SearchByMetadataCommand {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;

  const SearchByMetadataCommand({
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
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
class SearchLogic {
  final CatalogRepository repository;
  final ConfidenceScore confidenceScore;
  final VisualFeatureExtractor featureExtractor;
  final double confidenceAutoAcceptThreshold;
  final SearchTraceRepository? traceRepository;

  SearchLogic(
      {required this.repository,
      required this.confidenceScore,
      this.confidenceAutoAcceptThreshold = 90.0,
      this.traceRepository})
      : featureExtractor = const VisualFeatureExtractor();

  Future<SearchCardResult> searchByImg(SearchByImageCommand command) async {
    final queryFeatures = featureExtractor.extract(command.imageData);

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
      final score = card.visualFeatures != null
          ? command.mode == 1
              ? confidenceScore.specializedSimilarityBetweenFeatures(
                  queryFeatures,
                  card.visualFeatures!,
                )
              : confidenceScore.similarityBetweenFeatures(
                  queryFeatures,
                  card.visualFeatures!,
                )
          : confidenceScore.similarity(
              command.imageData,
              card.imageData,
            );

      scored.add(SearchCandidate(card: card, confidence: score));
    }

    scored.sort((a, b) => b.confidence.compareTo(a.confidence));

    if (scored.isNotEmpty &&
        scored.first.confidence >= confidenceAutoAcceptThreshold) {
      await _recordTrace(
        method: 'image',
        queryFeatures: queryFeatures,
        candidates: scored,
        decision: 'auto_accept',
        decisionReason:
            'Top candidate confidence ${scored.first.confidence.toStringAsFixed(1)}% >= threshold $confidenceAutoAcceptThreshold%',
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

    if (scored.first.confidence < 20.0) {
      final fuzzyName = searchCards.first.displayName ?? '';
      final fuzzyResults = await repository.fuzzySearchCards(fuzzyName);

      if (fuzzyResults.isNotEmpty) {
        final fuzzyCandidates = fuzzyResults.map((card) {
          return SearchCandidate(card: card, confidence: 25.0);
        }).toList();

        await _recordTrace(
          method: 'image',
          queryFeatures: queryFeatures,
          candidates: scored,
          decision: 'fuzzy_fallback',
          decisionReason:
              'Top confidence ${scored.first.confidence.toStringAsFixed(1)}% < 20%, escalated to fuzzy search by "$fuzzyName"',
        );
        return SearchCardResult(
          type: SearchResultType.multipleCandidates,
          candidates: fuzzyCandidates.take(3).toList(),
        );
      }
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

  Future<SearchCardResult> searchByMetadata(
      SearchByMetadataCommand command) async {
    final metadata = SearchMetadataEntry(
      set: command.set,
      number: command.number,
      edition: command.edition,
      language: command.language,
      finish: command.finish,
    );

    final readCards = await repository.searchCards();

    for (final card in readCards) {
      if ((command.set == card.set) &&
          (command.number == card.number) &&
          (command.edition == card.edition) &&
          (command.language == card.language) &&
          (command.finish == card.finish)) {
        final candidates = [SearchCandidate(card: card, confidence: 100.0)];
        await _recordTrace(
          method: 'manual',
          queryMetadata: metadata,
          candidates: candidates,
          decision: 'auto_accept',
          decisionReason: 'Exact identity match found for card ${card.id}',
        );
        return SearchCardResult(
            type: SearchResultType.singleCandidate, candidates: candidates);
      }
    }

    final fuzzyQuery = '${command.set} ${command.number}';
    final fuzzyResults = await repository.fuzzySearchCards(fuzzyQuery);

    if (fuzzyResults.isNotEmpty) {
      final fuzzyCandidates = fuzzyResults.map((card) {
        return SearchCandidate(card: card, confidence: 60.0);
      }).toList();

      await _recordTrace(
        method: 'manual',
        queryMetadata: metadata,
        candidates: fuzzyCandidates,
        decision: 'fuzzy_fallback',
        decisionReason:
            'No exact match, fuzzy search by "$fuzzyQuery" returned ${fuzzyCandidates.length} results',
      );
      return SearchCardResult(
        type: SearchResultType.multipleCandidates,
        candidates: fuzzyCandidates.take(3).toList(),
      );
    }

    await _recordTrace(
      method: 'manual',
      queryMetadata: metadata,
      candidates: [],
      decision: 'not_found',
      decisionReason: 'No exact or fuzzy match found for query "$fuzzyQuery"',
    );
    return SearchCardResult(
        type: SearchResultType.notFound,
        candidates: <SearchCandidate>[],
        reason: "No se encontro ninguna carta");
  }

  Future<void> _recordTrace({
    required String method,
    VisualFeatures? queryFeatures,
    SearchMetadataEntry? queryMetadata,
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
          displayName: c.card.displayName,
          confidence: c.confidence,
        );
      }).toList(),
      decision: decision,
      decisionReason: decisionReason,
    );

    await repo.save(trace);
  }
}
