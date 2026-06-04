import 'package:logging/logging.dart';

import 'confidence_score.dart';
import 'visual_features.dart';
import '../submit_evaluation/image_quality_service.dart';
import '../catalog_repository.dart';
import '../pokemon_card.dart';

final _log = Logger('SearchLogic');

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
  final VisualFeatureExtractor featureExtractor;
  final double confidenceAutoAcceptThreshold;

  const SearchLogic(
      {required this.repository,
      required this.imageQualityService,
      required this.confidenceScore,
      this.confidenceAutoAcceptThreshold = 90.0})
      : featureExtractor = const VisualFeatureExtractor();

  Future<SearchCardResult> searchByImg(SearchByImageCommand command) async {
    final queryFeatures = featureExtractor.extract(command.imageData);

    _log.info('Features extracted — aHash: ${queryFeatures.averageHashHex?.substring(0, 8)}..., dHash: ${queryFeatures.differenceHashHex?.substring(0, 8)}..., isEmpty: ${queryFeatures.isEmpty}');

    if (queryFeatures.isEmpty) {
      _log.info('→ manualSearchRequired (features empty)');
      return SearchCardResult(
        type: SearchResultType.manualSearchRequired,
        candidates: [],
      );
    }

    final candidates = <SearchCandidate>[];

    final indexedCards = await repository.findByVisualFeatures(queryFeatures);

    if (indexedCards.isNotEmpty) {
      for (final card in indexedCards) {
        candidates.add(
          SearchCandidate(
            card: card,
            confidence: confidenceScore.similarityAgainstFeatures(
              card.visualFeatures ?? queryFeatures,
              command.imageData,
            ),
          ),
        );
      }
    } else {
      final readCards = await repository.searchCards();

      for (final card in readCards) {
        candidates.add(
          SearchCandidate(
            card: card,
            confidence: card.visualFeatures != null
                ? confidenceScore.similarityAgainstFeatures(
                    card.visualFeatures!,
                    command.imageData,
                  )
                : confidenceScore.similarity(
                    command.imageData,
                    card.imageData,
                  ),
          ),
        );
      }
    }

    candidates.sort(
      (a, b) => b.confidence.compareTo(a.confidence),
    );

    if (candidates.isNotEmpty &&
        candidates.first.confidence >= confidenceAutoAcceptThreshold) {
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
