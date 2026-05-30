import '../catalog_repository.dart';
import '../catalog_validators.dart';
import '../pokemon_card.dart';

class CreateCardLogicException implements Exception {
  final String code;
  final String message;

  const CreateCardLogicException({required this.code, required this.message});

  @override
  String toString() => 'CreateCardLogicException($code): $message';
}

class CreateCardCommand {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;
  final String? displayName;
  final String? rarity;
  final String? pokemonType;
  final int? hp;
  final String? illustrator;
  final int? year;
  final String? author;
  final String imageData;
  final String? backImageData;

  const CreateCardCommand({
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
    required this.imageData,
    this.displayName,
    this.rarity,
    this.pokemonType,
    this.hp,
    this.illustrator,
    this.year,
    this.author,
    this.backImageData,
  });
}

class CardCreatedResult {
  final String cardId;
  final PokemonCardStatus status;
  final DateTime createdAt;

  const CardCreatedResult({
    required this.cardId,
    required this.status,
    required this.createdAt,
  });
}

class CreateCardLogic {
  final CatalogRepository repository;

  const CreateCardLogic({required this.repository});

  Future<CardCreatedResult> create(CreateCardCommand command) async {
    _validateIdentity(command);
    _validateImage(command.imageData);

    final duplicated = await repository.identityTupleExists(
      set: command.set,
      number: command.number,
      edition: command.edition,
      language: command.language,
      finish: command.finish,
    );

    if (duplicated) {
      throw const CreateCardLogicException(
        code: 'identity_rejected',
        message: 'Identity rejected',
      );
    }

    final created = await repository.saveCard(
      AddPokemonCardInput(
        set: command.set,
        number: command.number,
        edition: command.edition,
        language: command.language,
        finish: command.finish,
        displayName: command.displayName,
        rarity: command.rarity,
        pokemonType: command.pokemonType,
        hp: command.hp,
        illustrator: command.illustrator,
        year: command.year,
        author: command.author,
        imageData: command.imageData,
        backImageData: command.backImageData,
      ),
    );

    return CardCreatedResult(
      cardId: created.id,
      status: created.status,
      createdAt: created.createdAt,
    );
  }

  void _validateIdentity(CreateCardCommand command) {
    final setError = CatalogValidators.validateSet(command.set);
    if (setError != null) {
      throw CreateCardLogicException(
        code: 'identity_rejected',
        message: setError,
      );
    }

    final numberError = CatalogValidators.validateNumber(command.number);
    if (numberError != null) {
      throw CreateCardLogicException(
        code: 'identity_rejected',
        message: numberError,
      );
    }

    final editionError = CatalogValidators.validateEdition(command.edition);
    if (editionError != null) {
      throw CreateCardLogicException(
        code: 'identity_rejected',
        message: editionError,
      );
    }

    final languageError = CatalogValidators.validateLanguage(command.language);
    if (languageError != null) {
      throw CreateCardLogicException(
        code: 'identity_rejected',
        message: languageError,
      );
    }

    final finishError = CatalogValidators.validateFinish(command.finish);
    if (finishError != null) {
      throw CreateCardLogicException(
        code: 'identity_rejected',
        message: finishError,
      );
    }

    final rarityError = CatalogValidators.validateRarity(command.rarity);
    if (rarityError != null) {
      throw CreateCardLogicException(code: 'identity_rejected', message: rarityError);
    }

    final typeError = CatalogValidators.validateType(command.pokemonType);
    if (typeError != null) {
      throw CreateCardLogicException(code: 'identity_rejected', message: typeError);
    }

    final hpError = CatalogValidators.validateHp(command.hp);
    if (hpError != null) {
      throw CreateCardLogicException(code: 'identity_rejected', message: hpError);
    }

    final yearError = CatalogValidators.validateYear(command.year);
    if (yearError != null) {
      throw CreateCardLogicException(code: 'identity_rejected', message: yearError);
    }

    final authorError = CatalogValidators.validateAuthor(command.author);
    if (authorError != null) {
      throw CreateCardLogicException(code: 'identity_rejected', message: authorError);
    }
  }

  void _validateImage(String imageData) {
    final imageError = CatalogValidators.validateImageData(imageData);
    if (imageError != null) {
      throw CreateCardLogicException(
        code: 'image_rejected',
        message: imageError,
      );
    }
  }
}
