/// Domain logic for creating a new Pokemon card in the submitter catalog.
///
/// This file contains the command objects, result wrappers and the
/// `CreateCardLogic` use-case which validates identity and image data,
/// checks for duplicates and delegates persistence to a `CatalogRepository`.
///
/// Public API:
/// - `CreateCardCommand` : input DTO for the create operation
/// - `CardCreatedResult` : response DTO returned on success
/// - `CreateCardLogic` : orchestrator for validation and persistence
///
/// Errors are represented by `CreateCardLogicException` and use simple
/// string `code` values for mapping to HTTP responses in the application layer.
/*
 Domain logic for creating a new Pokemon card in the submitter catalog.

 This file contains the command objects, result wrappers and the
 `CreateCardLogic` use-case which validates identity and image data,
 checks for duplicates and delegates persistence to a `CatalogRepository`.

 Public API:
 - `CreateCardCommand` : input DTO for the create operation
 - `CardCreatedResult` : response DTO returned on success
 - `CreateCardLogic` : orchestrator for validation and persistence

 Errors are represented by `CreateCardLogicException` and use simple
 string `code` values for mapping to HTTP responses in the application layer.
*/
import '../catalog_repository.dart';
import '../catalog_validators.dart';
import '../pokemon_card.dart';

/// Represents an error produced by `CreateCardLogic`.
///
/// The `code` is a short machine-friendly identifier (for example
/// `identity_rejected` or `image_rejected`) and `message` contains a
/// human-readable explanation suitable for logs and error responses.
class CreateCardLogicException implements Exception {
  /// Short error code for programmatic handling.
  final String code;

  /// Human readable message describing the reason for the exception.
  final String message;

  const CreateCardLogicException({required this.code, required this.message});

  @override
  String toString() => 'CreateCardLogicException($code): $message';
}

/// Input DTO for the `CreateCardLogic.create` operation.
///
/// Contains the identity tuple (set, number, edition, language, finish),
/// optional metadata and Base64-encoded image payloads. Fields that are
/// nullable are optional and will be persisted when present.
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

/// Result returned after successfully creating a card.
///
/// `cardId` is the repository-generated identifier, `status` is the initial
/// workflow status of the created `PokemonCard` and `createdAt` is the
/// timestamp recorded by the persistence layer.
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
  /// Repository used to persist and query catalog data.
  final CatalogRepository repository;

  /// Creates a new `CreateCardLogic` instance.
  /* Creates a new `CreateCardLogic` instance. */
  const CreateCardLogic({required this.repository}); 

  /*
   Validates the provided `command`, ensures the identity tuple is unique
   and delegates the creation to the configured `CatalogRepository`.

   Parameters:
   - `command`: the input DTO containing identity, metadata and image data.

   Returns:
   - a `CardCreatedResult` with the created card id, initial status and
     creation timestamp.

   Throws:
   - `CreateCardLogicException` with `code: 'identity_rejected'` when any
     identity validation fails or the identity tuple already exists.
   - `CreateCardLogicException` with `code: 'image_rejected'` when the image
     validation fails.
  */
  Future<CardCreatedResult> create(CreateCardCommand command) async {
    _validateIdentity(command);
    _validateImage(command.imageData);
    _validateBackImage(command.backImageData);

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

  Future<List<PokemonCard>> searchCards({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    return repository.searchCards(
      query: query,
      limit: limit,
      offset: offset,
    );
  }

  // Private helpers validate parts of the command. These throw
  // `CreateCardLogicException` with `identity_rejected` when invalid.
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

  void _validateBackImage(String? backImageData) {
    if (backImageData == null || backImageData.isEmpty) {
      throw const CreateCardLogicException(
        code: 'image_rejected',
        message: 'Back image is required',
      );
    }
    final imageError = CatalogValidators.validateImageData(backImageData);
    if (imageError != null) {
      throw CreateCardLogicException(
        code: 'image_rejected',
        message: imageError,
      );
    }
  }
}
