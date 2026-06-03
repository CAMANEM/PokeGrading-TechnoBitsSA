import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../domain/submitter_catalog/create_card/create_card_logic.dart';
import '../../domain/submitter_catalog/search_card/search_logic.dart';
import '../http_helpers.dart';

Router buildCatalogRoutes(
    CreateCardLogic createCardLogic, SearchLogic searchLogic) {
  final router = Router();

  router.post('/cards/search/image', (Request request) async {
    final payload = await readJson(request);

    final imageData = (payload['image_data'] ?? '').toString();

    try {
      final result = await searchLogic.searchByImg(
        SearchByImageCommand(
          imageData: imageData,
        ),
      );

      final cardsJson = result.candidates.map((candidate) {
        final card = candidate.card;

        return {
          'card_id': card.id,
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
              'message': 'Image quality insufficient for identification',
            },
          );
        case SearchResultType.notFound:
          return jsonResponse(401,
              {'status': 'card_not_found', 'message': 'Card does not exist'});
      }
    } on SearchEvaluationLogicException catch (error) {
      return jsonResponse(
        400,
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

      final candidate = result.candidates.first;

      return jsonResponse(
        200,
        {
          'status': 'single_candidate',
          'candidate': {
            'card_id': candidate.card.id,
            'name': candidate.card.displayName,
            'confidence': candidate.confidence,
          },
        },
      );
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

  return router;
}
