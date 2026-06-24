/// @file
/// @brief Canonical codes and per-card validation for the B2B API.

import 'b2b_models.dart';
import '../../persistence/b2b_data_provider/api_key_repository.dart';
import '../../core/logging/app_logger.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';

Never _throwValidationError(String code, String err) {
  throw LogicException(
    feature: 'b2b',
    code: code,
    message: err,
  );
}

/// B2B canonical codes and per-card validation (isolated from submitter validators).
class B2bValidators {
  static const allowedLanguages = {'EN', 'ES', 'JP'};

  /// Maps B2B language code to DB lookup `language.name`.
  static const languageToLookupName = {
    'EN': 'English',
    'ES': 'Español',
    'JP': 'Japanese'
  };

  /// Maps DB lookup name to B2B language code.
  static const lookupNameToLanguage = {
    'english': 'EN',
    'español': 'ES',
    'japanese': 'JP'
  };

  static String lookupNameForLanguageCode(String code) {
    return languageToLookupName[code] ?? code;
  }

  static String languageCodeForLookupName(String lookupName) {
    final normalized = lookupName.trim().toLowerCase();
    return lookupNameToLanguage[normalized] ?? lookupName;
  }

  static String? validateSet(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'Set is required';
    if (normalized.length > 60) return 'Set cannot exceed 60 characters';
    return null;
  }

  static String? validateNumber(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'Number is required';
    final pattern = RegExp(r'^[0-9]{1,6}$');
    if (!pattern.hasMatch(normalized)) {
      return 'Number must be numeric (1 to 6 digits)';
    }
    return null;
  }

  static String? validateLanguageOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    if (!allowedLanguages.contains(normalized)) {
      return 'Language must be one of: ${allowedLanguages.join(', ')}';
    }
    return null;
  }

  /// Validates a single card; returns field + message on failure.
  static ({String field, String message})? validateCard(
      B2bConsultCardInput card) {
    final setError = validateSet(card.set);
    if (setError != null) return (field: 'set', message: setError);

    final numberError = validateNumber(card.number);
    if (numberError != null) return (field: 'number', message: numberError);

    final languageError = validateLanguageOptional(card.language);
    if (languageError != null)
      return (field: 'language', message: languageError);

    return null;
  }

  static Future<void> validateKey(
      String plaintextKey, ApiKeyRepository apiKeyRepository) async {
    B2bAuthContext? result = await apiKeyRepository.keyLookUp(plaintextKey);
    if (result == null) {
      _throwValidationError("404", 'Api Key Not Found');
    }
    if (result.apiKeyStatus == 'revoked') {
      DateTime? grace =
          await apiKeyRepository.checkGracePeriod(result.apiKeyId);
      if (grace != null) {
        if (DateTime.now().toUtc().isAfter(grace)) {
          AppLogger.warning(
            'PokéGrading.Persistence.ApiKeyRepository',
            'Revoked API key rejected - grace period expired',
            context: {'api_key_id': result.apiKeyId},
          );
          _throwValidationError('409', 'Grace period expired');
        }
      } else {
        AppLogger.warning(
          'PokéGrading.Persistence.ApiKeyRepository',
          'Revoked API key rejected - no grace period',
          context: {'api_key_id': result.apiKeyId},
        );
        _throwValidationError('404', 'No grace period');
      }
    }

    if (result.apiKeyStatus != 'active' && result.apiKeyStatus != 'revoked') {
      /// Negocio
      AppLogger.warning(
        'PokéGrading.Persistence.ApiKeyRepository',
        'API key rejected - invalid status',
        context: {
          'api_key_id': result.apiKeyId,
          'status': result.apiKeyStatus,
        },
      );
      _throwValidationError('409', 'Invalid status');
    }
  }
}
