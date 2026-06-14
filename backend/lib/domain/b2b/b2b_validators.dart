/// @file
/// @brief Canonical codes and per-card validation for the B2B API.

import 'b2b_models.dart';

/// B2B canonical codes and per-card validation (isolated from submitter validators).
class B2bValidators {
  static const allowedLanguages = {'EN', 'ES', 'JP'};
  static const allowedEditions = {'FIRST_EDITION', 'UNLIMITED'};
  static const allowedFinishes = {'HOLO', 'NORMAL', 'REVERSE_HOLO'};

  /// Maps B2B language code to DB lookup `language.name`.
  static const languageToLookupName = {
    'EN': 'English',
    'ES': 'Spanish',
    'JP': 'Japanese',
  };

  /// Maps DB lookup name to B2B language code.
  static const lookupNameToLanguage = {
    'english': 'EN',
    'inglés': 'EN',
    'ingles': 'EN',
    'spanish': 'ES',
    'español': 'ES',
    'espanol': 'ES',
    'japanese': 'JP',
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

  static String? validateEditionOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    if (!allowedEditions.contains(normalized)) {
      return 'Edition must be one of: ${allowedEditions.join(', ')}';
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

  static String? validateFinishOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    if (!allowedFinishes.contains(normalized)) {
      return 'Finish must be one of: ${allowedFinishes.join(', ')}';
    }
    return null;
  }

  /// Validates a single card; returns field + message on failure.
  static ({String field, String message})? validateCard(B2bConsultCardInput card) {
    final setError = validateSet(card.set);
    if (setError != null) return (field: 'set', message: setError);

    final numberError = validateNumber(card.number);
    if (numberError != null) return (field: 'number', message: numberError);

    final editionError = validateEditionOptional(card.edition);
    if (editionError != null) return (field: 'edition', message: editionError);

    final languageError = validateLanguageOptional(card.language);
    if (languageError != null) return (field: 'language', message: languageError);

    final finishError = validateFinishOptional(card.finish);
    if (finishError != null) return (field: 'finish', message: finishError);

    return null;
  }
}
