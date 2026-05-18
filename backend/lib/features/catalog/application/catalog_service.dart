import '../domain/catalog_repository.dart';
import '../domain/catalog_validators.dart';
import '../domain/pokemon_card.dart';

class CatalogServiceException implements Exception {
  final String code;
  final String message;

  const CatalogServiceException({required this.code, required this.message});

  @override
  String toString() => 'CatalogServiceException($code): $message';
}

class AddCardCommand {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;
  final String? displayName;
  final String imageData;

  const AddCardCommand({
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
    required this.imageData,
    this.displayName,
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

class CatalogService {
  final CatalogRepository repository;

  const CatalogService({required this.repository});

  Future<CardCreatedResult> addCard(AddCardCommand command) async {
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
      throw const CatalogServiceException(
        code: 'identity_rejected',
        message: 'Identidad rechazada',
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
        imageData: command.imageData,
      ),
    );

    return CardCreatedResult(
      cardId: created.id,
      status: created.status,
      createdAt: created.createdAt,
    );
  }

  void _validateIdentity(AddCardCommand command) {
    final setError = CatalogValidators.validateSet(command.set);
    if (setError != null) {
      throw CatalogServiceException(
        code: 'identity_rejected',
        message: setError,
      );
    }

    final numberError = CatalogValidators.validateNumber(command.number);
    if (numberError != null) {
      throw CatalogServiceException(
        code: 'identity_rejected',
        message: numberError,
      );
    }

    final editionError = CatalogValidators.validateEdition(command.edition);
    if (editionError != null) {
      throw CatalogServiceException(
        code: 'identity_rejected',
        message: editionError,
      );
    }

    final languageError = CatalogValidators.validateLanguage(command.language);
    if (languageError != null) {
      throw CatalogServiceException(
        code: 'identity_rejected',
        message: languageError,
      );
    }

    final finishError = CatalogValidators.validateFinish(command.finish);
    if (finishError != null) {
      throw CatalogServiceException(
        code: 'identity_rejected',
        message: finishError,
      );
    }
  }

  void _validateImage(String imageData) {
    final imageError = CatalogValidators.validateImageData(imageData);
    if (imageError != null) {
      throw CatalogServiceException(
        code: 'image_rejected',
        message: imageError,
      );
    }
  }
}
