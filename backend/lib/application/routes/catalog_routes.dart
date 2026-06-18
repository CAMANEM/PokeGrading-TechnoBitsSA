/// @file
/// @brief

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_helpers.dart';
import '../../domain/catalog/create_card_logic.dart';
import '../../domain/catalog/search_card_logic.dart';
import '../../domain/catalog/catalog_models.dart';
import '../../domain/image_services/confidence_score.dart';
import '../../persistence/card_data_provider/search_trace_repository.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';
import 'package:pokegrading_logging/pokegrading_logging.dart';
import '../http_helpers.dart';

Router buildCatalogRoutes(
    CreateCardLogic createCardLogic, SearchCardLogic searchCardLogic,
    {SearchTraceRepository? searchTraceRepository}) {
  final router = Router();

  router.post('/cards/search/image', (Request request) async {
    final payload = await readJson(request);
    final requestContext = httpLogContext(
      request: request,
      body: catalogSearchBodySummary(payload),
    );

    AppLogger.info(
      'PokéGrading.Routes.Catalog',
      'Catalog image search request',
      context: requestContext,
    );

    final imageData = (payload['image_data'] ?? '').toString();
    final mode = switch (payload['mode']) {
      'fast' => ConfidenceType.fast,
      'specialized' => ConfidenceType.specialized,
      _ => ConfidenceType.fast
    };

    try {
      final result = await searchCardLogic.searchByImg(
        SearchByImageCommand(
          imageData: imageData,
          mode: mode,
        ),
      );

      final cardsJson = result.candidates.map((candidate) {
        final card = candidate.card;
        return {
          'id': card.id,
          'name': card.display?.displayName,
          'confidence': candidate.confidence,
        };
      }).toList();

      switch (result.type) {
        case SearchResultType.singleCandidate:
          return jsonResponse(
            200,
            {
              'status': 'single_candidate',
              'candidate': cardsJson.first,
            },
          );

        case SearchResultType.multipleCandidates:
          return jsonResponse(
            201,
            {
              'status': 'multiple_candidates',
              'candidates': cardsJson,
            },
          );

        case SearchResultType.manualSearchRequired:
          return jsonResponse(
            400,
            {
              'status': 'manual_search_required',
              'message': result.reason,
            },
          );
        case SearchResultType.notFound:
          return jsonResponse(
              404, {'status': 'card_not_found', 'message': result.reason});
      }
    } on LogicException catch (error) {
      return jsonResponse(
        404,
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Routes.Catalog',
        'Image search failed',
        context: requestContext,
        error: error,
        stackTrace: stack,
      );
      return jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'search_failed',
          'message': error.toString(),
        },
      );
    }
  });

  router.post('/cards/search/manual', (Request request) async {
    final payload = await readJson(request);
    final requestContext = httpLogContext(
      request: request,
      body: RequestLogContext.sanitize({
        'set': payload['set'],
        'number': payload['number'],
        'edition': payload['edition'],
        'language': payload['language'],
        'finish': payload['finish'],
      }),
    );

    AppLogger.info(
      'PokéGrading.Routes.Catalog',
      'Catalog manual search request',
      context: requestContext,
    );

    try {
      final result = await searchCardLogic.searchByMetadata(
        CardIdentity(
          set: (payload['set'] ?? '').toString(),
          number: (payload['number'] ?? '').toString(),
          edition: (payload['edition'] ?? '').toString(),
          language: (payload['language'] ?? '').toString(),
          finish: (payload['finish'] ?? '').toString(),
        ),
      );

      if (result.candidates.isEmpty) {
        return jsonResponse(
          404,
          {
            'status': 'card_not_found',
            'message': 'No card matches the provided identity',
          },
        );
      }

      final cardsJson = result.candidates.map((candidate) {
        return {
          'id': candidate.card.id,
          'name': candidate.card.display?.displayName,
          'confidence': candidate.confidence,
        };
      }).toList();

      switch (result.type) {
        case SearchResultType.singleCandidate:
          return jsonResponse(200, {
            'status': 'single_candidate',
            'candidate': cardsJson.first,
          });
        case SearchResultType.multipleCandidates:
          return jsonResponse(201, {
            'status': 'multiple_candidates',
            'candidates': cardsJson,
          });
        default:
          return jsonResponse(404, {
            'status': 'card_not_found',
            'message': 'No card matches the provided identity',
          });
      }
    } on LogicException catch (error) {
      return jsonResponse(
        404,
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Routes.Catalog',
        'Manual search failed',
        context: requestContext,
        error: error,
        stackTrace: stack,
      );
      return jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'search_failed',
          'message': error.toString(),
        },
      );
    }
  });

  router.post('/cards', (Request request) async {
    final payload = await readJson(request);
    final identity = CardIdentity(
        set: (payload['set'] ?? '').toString(),
        number: (payload['number'] ?? '').toString(),
        edition: (payload['edition'] ?? '').toString(),
        language: (payload['language'] ?? '').toString(),
        finish: (payload['finish'] ?? '').toString());
    final display = CardDisplay(
        displayName: payload['display_name']?.toString(),
        rarity: payload['rarity']?.toString(),
        pokemonType: payload['type']?.toString(),
        hp: payload['hp'] is int
            ? payload['hp'] as int
            : int.tryParse((payload['hp'] ?? '').toString()),
        illustrator: payload['illustrator']?.toString(),
        year: payload['year'] is int
            ? payload['year'] as int
            : int.tryParse((payload['year'] ?? '').toString()),
        author: payload['author']?.toString());
    final backImageData = payload['back_image_data']?.toString();
    final imageData = (payload['image_data'] ?? '').toString();
    final requestContext = httpLogContext(
      request: request,
      body: catalogCreateBodySummary(payload),
    );

    try {
      final result = await createCardLogic.create(
        CreateCardCommand(
          identity: identity,
          display: display,
          imageData: imageData,
          backImageData: backImageData,
        ),
      );

      AppLogger.audit(
        'PokéGrading.Routes.Catalog',
        AuditEventTypes.catalogPropose,
        result: 'success',
        context: {
          ...requestContext,
          'card_id': result.cardId,
          'card_status': result.status.name,
        },
      );

      return jsonResponse(
        201,
        {
          'status': 'pending_validation',
          'message': 'Card added to catalog',
          'card_id': result.cardId,
          'card_status': result.status.name,
          'created_at': result.createdAt.toIso8601String(),
        },
      );
    } on LogicException catch (error) {
      AppLogger.audit(
        'PokéGrading.Routes.Catalog',
        AuditEventTypes.catalogPropose,
        result: 'failure',
        context: {
          ...requestContext,
          'error_code': error.code,
          'error_message': error.message,
        },
      );
      return jsonResponse(
        createCardStatusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Routes.Catalog',
        'Catalog add failed',
        context: requestContext,
        error: error,
        stackTrace: stack,
      );
      return jsonResponse(
        500,
        {
          'status': 'error',
          'error': 'catalog_add_failed',
          'message': error.toString(),
        },
      );
    }
  });

  if (searchTraceRepository != null) {
    router.get('/search-traces', (Request request) async {
      final traces = await searchTraceRepository.findRecent(50);
      final json = traces.map((t) {
        return {
          'id': t.id,
          'timestamp': t.timestamp.toIso8601String(),
          'method': t.method,
          'candidates': t.candidates
              .map((c) => {
                    'card_id': c.cardId,
                    'display_name': c.displayName,
                    'confidence': c.confidence,
                  })
              .toList(),
          'decision': t.decision,
          'decision_reason': t.decisionReason,
        };
      }).toList();

      return jsonResponse(200, {'traces': json});
    });
  }

  return router;
}
