import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../domain/submitter_catalog/create_card/create_card_logic.dart';
import '../../domain/submitter_catalog/search_card/search_logic.dart';
import '../../domain/submitter_catalog/search_card/search_trace_repository.dart';
import '../http_helpers.dart';

Router buildCatalogRoutes(
    CreateCardLogic createCardLogic, SearchLogic searchLogic,
    {SearchTraceRepository? searchTraceRepository}) {
  final router = Router();

  router.post('/cards/search/image', (Request request) async {
    final payload = await readJson(request);

    final imageData = (payload['image_data'] ?? '').toString();
    final mode = (payload['mode'] ?? 0);

    try {
      final result = await searchLogic.searchByImg(
        SearchByImageCommand(
          imageData: imageData,
          mode: mode,
        ),
      );

      final cardsJson = result.candidates.map((candidate) {
        final card = candidate.card;

        return {
          'id': card.id,
          'name': card.displayName,
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
    } on SearchEvaluationLogicException catch (error) {
      return jsonResponse(
        404,
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error) {
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

    try {
      final result = await searchLogic.searchByMetadata(
        SearchByMetadataCommand(
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
          'name': candidate.card.displayName,
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
    } on SearchEvaluationLogicException catch (error) {
      return jsonResponse(
        404,
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error) {
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
    final set = (payload['set'] ?? '').toString();
    final number = (payload['number'] ?? '').toString();
    final edition = (payload['edition'] ?? '').toString();
    final language = (payload['language'] ?? '').toString();
    final finish = (payload['finish'] ?? '').toString();
    final displayName = payload['display_name']?.toString();
    final rarity = payload['rarity']?.toString();
    final type = payload['type']?.toString();
    final hp = payload['hp'] is int
        ? payload['hp'] as int
        : int.tryParse((payload['hp'] ?? '').toString());
    final illustrator = payload['illustrator']?.toString();
    final year = payload['year'] is int
        ? payload['year'] as int
        : int.tryParse((payload['year'] ?? '').toString());
    final author = payload['author']?.toString();
    final backImageData = payload['back_image_data']?.toString();
    final imageData = (payload['image_data'] ?? '').toString();

    try {
      final result = await createCardLogic.create(
        CreateCardCommand(
          set: set,
          number: number,
          edition: edition,
          language: language,
          finish: finish,
          displayName: displayName,
          rarity: rarity,
          pokemonType: type,
          hp: hp,
          illustrator: illustrator,
          year: year,
          author: author,
          imageData: imageData,
          backImageData: backImageData,
        ),
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
    } on CreateCardLogicException catch (error) {
      return jsonResponse(
        createCardStatusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error) {
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
