/// @file
/// @brief Catalog image and metadata search orchestration.

import 'package:uuid/uuid.dart';

import '../image_services/confidence_score.dart';
import 'search_trace.dart';
import '../image_services/visual_features.dart';
import '../image_services/image_quality_service.dart';
import 'catalog_models.dart';

import '../../persistence/card_data_provider/catalog_repository.dart';
import '../../persistence/card_data_provider/search_trace_repository.dart';
import '../../core/logging/app_logger.dart';

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
  static const _loggerName = 'PokéGrading.SearchCard';

  /// Fast search auto-accept threshold (diagram: 85%).
  static const double fastAcceptThreshold = 85.0;

  /// Specialized search auto-accept threshold (diagram: 75%).
  static const double specializedAcceptThreshold = 75.0;

  /// Minimum gap between top-1 and top-2 confidence to auto-accept.
  static const double minWinnerMargin = 6.0;

  final CatalogRepository repository;
  final SearchTraceRepository? traceRepository;

  SearchCardLogic({required this.repository, this.traceRepository});

  double _thresholdFor(ConfidenceType mode) {
    return switch (mode) {
      ConfidenceType.fast => fastAcceptThreshold,
      ConfidenceType.specialized => specializedAcceptThreshold,
    };
  }

  Future<SearchCardResult> searchByImg(SearchByImageCommand command) async {
    final started = DateTime.now().toUtc();
    final modeName = command.mode.name;
    final threshold = _thresholdFor(command.mode);

    final queryFeatures = VisualFeatureExtractor.extract(command.imageData);
    final iqsBelow =
        ImageQualityService.calculateScore(command.imageData).score <
            ImageQualityService.acceptedThreshold;

    if (queryFeatures.isEmpty || iqsBelow) {
      _logSearchMetric(
        stage: 'identify_$modeName',
        mode: modeName,
        started: started,
        decision: 'manual_search_required',
      );
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
      final features = card.visualFeatures;
      if (features == null || features.isEmpty) continue;

      final score = ConfidenceScore.calculateConfidence(
        queryFeatures,
        features,
        command.mode,
      );

      scored.add(SearchCandidate(card: card, confidence: score));
    }

    scored.sort((a, b) => b.confidence.compareTo(a.confidence));

    if (scored.isNotEmpty) {
      final top = scored.first;
      final runnerUp =
          scored.length > 1 ? scored[1].confidence : 0.0;
      final margin = top.confidence - runnerUp;
      final hamming = ConfidenceScore.hammingBreakdown(
        queryFeatures,
        top.card.visualFeatures!,
      );

      AppLogger.metric(
        _loggerName,
        'identify.score_breakdown',
        context: {
          'mode': modeName,
          'top_confidence': top.confidence,
          'runner_up_confidence': runnerUp,
          'margin': margin,
          'threshold': threshold,
          ...hamming,
        },
      );

      if (top.confidence >= threshold && margin >= minWinnerMargin) {
        _logSearchMetric(
          stage: 'identify_$modeName',
          mode: modeName,
          started: started,
          decision: 'auto_accept',
        );
        await _recordTrace(
          method: 'image',
          queryFeatures: queryFeatures,
          candidates: scored,
          decision: 'auto_accept',
          decisionReason:
              'Top confidence ${top.confidence.toStringAsFixed(1)}% >= $threshold% with margin ${margin.toStringAsFixed(1)}',
        );
        return SearchCardResult(
          type: SearchResultType.singleCandidate,
          candidates: [top],
        );
      }
    }

    if (scored.isEmpty) {
      _logSearchMetric(
        stage: 'identify_$modeName',
        mode: modeName,
        started: started,
        decision: 'not_found',
      );
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

    _logSearchMetric(
      stage: 'identify_$modeName',
      mode: modeName,
      started: started,
      decision: 'multiple_candidates',
    );
    await _recordTrace(
      method: 'image',
      queryFeatures: queryFeatures,
      candidates: scored,
      decision: 'multiple_candidates',
      decisionReason:
          'Top confidence ${scored.first.confidence.toStringAsFixed(1)}% below threshold $threshold% or insufficient margin',
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

  void _logSearchMetric({
    required String stage,
    required String mode,
    required DateTime started,
    required String decision,
  }) {
    final durationMs =
        DateTime.now().toUtc().difference(started).inMilliseconds;
    AppLogger.metric(
      _loggerName,
      'stage.latency',
      context: {
        'stage': stage,
        'mode': mode,
        'duration_ms': durationMs,
        'decision': decision,
      },
    );
  }
}
