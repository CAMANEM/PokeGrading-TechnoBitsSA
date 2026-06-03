import 'package:test/test.dart';

import 'package:pokegrading_backend/domain/submitter_catalog/catalog_repository.dart';
import 'package:pokegrading_backend/domain/submitter_catalog/create_card/create_card_logic.dart';
import 'package:pokegrading_backend/domain/submitter_catalog/pokemon_card.dart';
import 'package:pokegrading_backend/persistence/submitter_catalog/id_generator.dart';
import 'package:pokegrading_backend/persistence/submitter_catalog/mock_catalog_repository.dart';

void main() {
  group('CreateCardLogic', () {
    test('blocks duplicate identity before saving the second card', () async {
      final repository = _SpyCatalogRepository();
      final logic = CreateCardLogic(repository: repository);
      final command = _validCommand();

      final firstResult = await logic.create(command);

      expect(firstResult.cardId, isNotEmpty);
      expect(repository.saveCallCount, 1);

      await expectLater(
        logic.create(command),
        throwsA(
          isA<CreateCardLogicException>()
              .having((error) => error.code, 'code', 'identity_rejected')
              .having(
                (error) => error.message,
                'message',
                contains('rechazada'),
              ),
        ),
      );

      expect(repository.saveCallCount, 1);
    });

    test('mock repository rejects direct duplicate saves', () async {
      final repository = MockCatalogRepository(
        idGenerator: _FixedIdGenerator(['card-1', 'card-2']),
      );
      final input = _validInput();

      final firstCard = await repository.saveCard(input);

      expect(firstCard.id, 'card-1');

      await expectLater(
        repository.saveCard(input),
        throwsA(isA<CatalogIdentityConflictException>()),
      );
    });
  });
}

CreateCardCommand _validCommand() {
  return CreateCardCommand(
    set: 'Base Set',
    number: '001',
    edition: '1st Edition',
    language: 'Español',
    finish: 'Holo',
    author: 'Ash Ketchum',
    imageData: _validImageData(),
  );
}

AddPokemonCardInput _validInput() {
  return AddPokemonCardInput(
    set: 'Base Set',
    number: '001',
    edition: '1st Edition',
    language: 'Español',
    finish: 'Holo',
    author: 'Ash Ketchum',
    imageData: _validImageData(),
  );
}

String _validImageData() {
  return 'data:image/png;base64,${List.filled(5200, 'A').join()}';
}

class _SpyCatalogRepository implements CatalogRepository {
  final Set<String> _identityKeys = <String>{};
  int saveCallCount = 0;
  int _nextId = 1;

  @override
  Future<bool> identityTupleExists({
    required String set,
    required String number,
    required String edition,
    required String language,
    required String finish,
  }) async {
    return _identityKeys.contains(_identityKey(
      set: set,
      number: number,
      edition: edition,
      language: language,
      finish: finish,
    ));
  }

  @override
  Future<PokemonCard> saveCard(AddPokemonCardInput input) async {
    saveCallCount += 1;
    final id = 'card-${_nextId++}';
    final now = DateTime.utc(2026, 1, 1);
    final card = PokemonCard(
      id: id,
      set: input.set,
      number: input.number,
      edition: input.edition,
      language: input.language,
      finish: input.finish,
      imageData: input.imageData,
      createdBy: input.author,
      createdAt: now,
    );
    _identityKeys.add(_identityKey(
      set: input.set,
      number: input.number,
      edition: input.edition,
      language: input.language,
      finish: input.finish,
    ));
    return card;
  }

  @override
  Future<PokemonCard?> findById(String id) async {
    return null;
  }

  String _identityKey({
    required String set,
    required String number,
    required String edition,
    required String language,
    required String finish,
  }) {
    return [set, number, edition, language, finish]
        .map((value) => value.trim().toLowerCase())
        .join('|');
  }
}

class _FixedIdGenerator implements IdGenerator {
  final List<String> _ids;
  int _index = 0;

  _FixedIdGenerator(this._ids);

  @override
  String generateCardId() {
    return _ids[_index++];
  }
}