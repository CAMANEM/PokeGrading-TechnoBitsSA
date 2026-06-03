import 'confidence_score.dart';
import '../submit_evaluation/image_quality_service.dart';
import '../catalog_repository.dart';
import '../pokemon_card.dart';

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

class SearchByImageCommand {
  final String imageData;

  const SearchByImageCommand({
    required this.imageData,
  });
}

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

enum SearchResultType {
  manualSearchRequired,
  singleCandidate,
  multipleCandidates,
  notFound
}

class SearchCandidate {
  final PokemonCard card;
  final double confidence;

  const SearchCandidate({
    required this.card,
    required this.confidence,
  });
}

class SearchCardResult {
  final SearchResultType type;
  final List<SearchCandidate> candidates;

  const SearchCardResult({
    required this.type,
    this.candidates = const <SearchCandidate>[],
  });
}

class SearchLogic {
  final CatalogRepository repository;
  final ImageQualityService imageQualityService;
  final ConfidenceScore confidenceScore;

  const SearchLogic(
      {required this.repository,
      required this.imageQualityService,
      required this.confidenceScore});

  Future<SearchCardResult> searchByImg(SearchByImageCommand command) async {
    final quality = await imageQualityService.calculateScore(
      command.imageData,
    );

    if (quality.score < 60) {
      return SearchCardResult(
        type: SearchResultType.manualSearchRequired,
        candidates: [],
      );
    }

    final readCards = await repository.searchCards();

    final candidates = <SearchCandidate>[];

    for (final card in readCards) {
      candidates.add(
        SearchCandidate(
          card: card,
          confidence: confidenceScore.similarity(
            command.imageData,
            card.imageData,
          ),
        ),
      );
    }

    candidates.sort(
      (a, b) => b.confidence.compareTo(a.confidence),
    );

    const threshold = 90.0;

    if (candidates.isNotEmpty && candidates.first.confidence >= threshold) {
      return SearchCardResult(
        type: SearchResultType.singleCandidate,
        candidates: [candidates.first],
      );
    }

    return SearchCardResult(
      type: SearchResultType.multipleCandidates,
      candidates: candidates.take(3).toList(),
    );
  }

  Future<SearchCardResult> searchByMetadata(
      SearchByMetadataCommand command) async {
    final readCards = await repository.searchCards();

    for (final card in readCards) {
      if ((command.set == card.set) &&
          (command.number == card.number) &&
          (command.edition == card.edition) &&
          (command.language == card.language) &&
          (command.finish == card.finish)) {
        return SearchCardResult(
            type: SearchResultType.singleCandidate,
            candidates: [SearchCandidate(card: card, confidence: 100.0)]);
      }
    }

    return SearchCardResult(
        type: SearchResultType.notFound, candidates: <SearchCandidate>[]);
  }
}
