/// @file
/// @brief Canonical codes and per-card validation for the B2B API.

import 'b2b_models.dart';
import '../../persistence/b2b_data_provider/api_key_repository.dart';
import '../../core/logging/app_logger.dart';
import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';

Never _throwValidationError(
    int code,
    String err_type,
    String err_message,
    int? apiKeyId,
    String? apiKeyStatus,
    int? customerId,
    String? customerStatus) {
  throw B2bException(
      code: code,
      err_type: err_type,
      message: err_message,
      apiKeyId: apiKeyId,
      apiKeyStatus: apiKeyStatus,
      customerId: customerId,
      customerStatus: customerStatus);
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

  static Future<B2bAuthContext> validateKey(
      String plaintextKey, ApiKeyRepository apiKeyRepository) async {
    String key = plaintextKey.trim();
    if (key.isEmpty) {
      _throwValidationError(401, 'MISSING_API_KEY',
          'Authorization header must contain API key', null, null, null, null);
    }
    B2bAuthContext? result = await apiKeyRepository.keyLookUp(key);
    if (result == null) {
      _throwValidationError(404, 'AUTH_INVALID_API_KEY', 'Api Key Not Found',
          null, null, null, null);
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
          _throwValidationError(
              409,
              'EXPIRED_GRACE_PERIOD',
              'Grace period expired',
              result.apiKeyId,
              result.apiKeyStatus,
              result.customerId,
              result.customerStatus);
        }
      } else {
        AppLogger.warning(
          'PokéGrading.Persistence.ApiKeyRepository',
          'Revoked API key rejected - no grace period',
          context: {'api_key_id': result.apiKeyId},
        );
        _throwValidationError(
            404,
            'GRACE_PERIOD_NOT_FOUND',
            'No grace period',
            result.apiKeyId,
            result.apiKeyStatus,
            result.customerId,
            result.customerStatus);
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
      _throwValidationError(
          409,
          'INVALID_API_KEY_STATUS',
          'Invalid status',
          result.apiKeyId,
          result.apiKeyStatus,
          result.customerId,
          result.customerStatus);
    }

    if (result.customerStatus == 'suspended') {
      _throwValidationError(
          403,
          'CUSTOMER_SUSPENDED',
          'B2B customer account is suspended',
          result.apiKeyId,
          result.apiKeyStatus,
          result.customerId,
          result.customerStatus);
    }

    if (result.apiKeyStatus == 'suspended') {
      _throwValidationError(
          403,
          'API_KEY_SUSPENDED',
          'API key is suspended',
          result.apiKeyId,
          result.apiKeyStatus,
          result.customerId,
          result.customerStatus);
    }

    return result;
  }
}
