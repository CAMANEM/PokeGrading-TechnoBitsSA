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

import 'package:pokegrading_logging/pokegrading_logging.dart';

import '../../core/logging/app_logger.dart';
import 'catalog_validators.dart';
import 'catalog_models.dart';
import '../image_services/visual_features.dart';
import '../scoring/grading/grading_feature_extractor.dart';
import '../../persistence/card_data_provider/catalog_repository.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';

const _logger = 'PokéGrading.Domain.CreateCard';

Never _throwCardError(String code, String err) {
  AppLogger.warning(
    _logger,
    'Card creation validation failed',
    context: {'error_code': code, 'error_message': err},
  );
  throw LogicException(
    feature: 'create_card',
    code: code,
    message: err,
  );
}

/// Input DTO for the `CreateCardLogic.create` operation.
///
/// Contains the identity tuple (set, number, edition, language, finish),
/// optional metadata and Base64-encoded image payloads. Fields that are
/// nullable are optional and will be persisted when present.
class CreateCardCommand {
  final CardIdentity identity;
  final CardDisplay? display;
  final String imageData;
  final String? backImageData;
  final double? psaGrade;

  const CreateCardCommand({
    required this.identity,
    required this.imageData,
    this.display,
    this.backImageData,
    this.psaGrade,
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

/// @brief CreateCardLogic
class CreateCardLogic {
  final CatalogRepository repository;

  static const String _identityConflictCode = 'identity_rejected';
  static const String _imageConflitCode = 'image_rejected';
  static const String _identityConflictMessage =
      'Identidad rechazada: ya existe una carta con la misma combinación de Set, Número, Edición, Idioma y Acabado.';

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
    _validateImage(command.imageData, 'Front image is required');
    _validateImage(command.backImageData, 'Back image is required');

    final duplicated =
        await repository.identityTupleExists(identity: command.identity);

    if (duplicated) {
      AppLogger.info(
        _logger,
        'Duplicate card identity detected',
        context: {
          'set': command.identity.set,
          'number': command.identity.number,
          'edition': command.identity.edition,
          'language': command.identity.language,
          'finish': command.identity.finish,
        },
      );
      _throwCardError(_identityConflictCode, _identityConflictMessage);
    }

    try {
      final features = VisualFeatureExtractor.extract(command.imageData);
      if (features.isEmpty) {
        AppLogger.warning(
          _logger,
          'Visual feature extraction returned empty result',
          context: {
            'set': command.identity.set,
            'number': command.identity.number,
          },
        );
      }

      // Extract grading features from image (for calibration)
      Map<String, dynamic>? gradingFeatures;
      try {
        gradingFeatures = GradingFeatureExtractor.extractToMap(command.imageData);
      } catch (error) {
        AppLogger.warning(
          _logger,
          'Grading feature extraction failed (non-critical)',
          context: {
            'set': command.identity.set,
            'number': command.identity.number,
            'error': error.toString(),
          },
        );
      }

      final created = await repository.saveCard(
        AddPokemonCardInput(
          identity: command.identity,
          display: command.display,
          imageData: command.imageData,
          backImageData: command.backImageData,
          visualFeatures: features,
          psaGrade: command.psaGrade,
          gradingFeaturesJson: gradingFeatures,
        ),
      );

      AppLogger.audit(
        _logger,
        AuditEventTypes.catalogPropose,
        result: 'success',
        context: {
          'card_id': created.id,
          'card_status': created.status.name,
          'set': command.identity.set,
          'number': command.identity.number,
        },
      );

      return CardCreatedResult(
        cardId: created.id,
        status: created.status,
        createdAt: created.createdAt,
      );
    } on LogicException catch (error) {
      AppLogger.error(
        _logger,
        'Repository rejected card creation',
        context: {
          'set': command.identity.set,
          'number': command.identity.number,
          'original_code': error.code,
          'original_message': error.message,
        },
        error: error,
      );
      _throwCardError(_identityConflictCode, _identityConflictMessage);
    }
  }

  Future<List<PokemonCard>> searchCards() async {
    return repository.searchCards();
  }

  // Private helpers validate parts of the command. These throw
  // `CreateCardLogicException` with `identity_rejected` when invalid.
  void _validateIdentity(CreateCardCommand command) {
    final setError = CatalogValidators.validateSet(command.identity.set);
    if (setError != null) {
      _throwCardError(_identityConflictCode, setError);
    }

    final numberError =
        CatalogValidators.validateNumber(command.identity.number);
    if (numberError != null) {
      _throwCardError(_identityConflictCode, numberError);
    }

    final editionError =
        CatalogValidators.validateEdition(command.identity.edition);
    if (editionError != null) {
      _throwCardError(_identityConflictCode, editionError);
    }

    final languageError =
        CatalogValidators.validateLanguage(command.identity.language);
    if (languageError != null) {
      _throwCardError(_identityConflictCode, languageError);
    }

    final finishError =
        CatalogValidators.validateFinish(command.identity.finish);
    if (finishError != null) {
      _throwCardError(_identityConflictCode, finishError);
    }

    final display = command.display;
    if (display != null) {
      final rarityError = CatalogValidators.validateRarity(display.rarity);
      if (rarityError != null) {
        _throwCardError(_identityConflictCode, rarityError);
      }

      final typeError = CatalogValidators.validateType(display.pokemonType);
      if (typeError != null) {
        _throwCardError(_identityConflictCode, typeError);
      }

      final hpError = CatalogValidators.validateHp(display.hp);
      if (hpError != null) {
        _throwCardError(_identityConflictCode, hpError);
      }

      final yearError = CatalogValidators.validateYear(display.year);
      if (yearError != null) {
        _throwCardError(_identityConflictCode, yearError);
      }

      final authorError = CatalogValidators.validateAuthor(display.author);
      if (authorError != null) {
        _throwCardError(_identityConflictCode, authorError);
      }
    }
  }

  void _validateImage(String? imageData, String message) {
    if (imageData == null || imageData.isEmpty) {
      _throwCardError(_imageConflitCode, message);
    }
    final imageError = CatalogValidators.validateImageData(imageData);
    if (imageError != null) {
      _throwCardError(_imageConflitCode, imageError);
    }
  }
}
