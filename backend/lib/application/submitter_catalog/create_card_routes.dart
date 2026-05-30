import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../domain/submitter_catalog/create_card/create_card_logic.dart';
import '../http_helpers.dart';

Router buildCreateCardRoutes(CreateCardLogic createCardLogic) {
  final router = Router();

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
