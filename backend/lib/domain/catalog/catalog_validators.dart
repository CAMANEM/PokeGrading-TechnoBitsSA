/*
 Validation helpers for submitter catalog inputs.

 Contains static methods to validate identity fields (set, number, edition,
 language, finish), image payloads and optional metadata (rarity, type, hp,
 year, author). Methods return `null` on success or an error message on failure.
*/
import '../image_services/image_quality_service.dart';
import '../image_services/polyglot_detection.dart';
import '../../core/config/app_config.dart';

/// @brief CatalogValidators
class CatalogValidators {
  static final RegExp _imageDataUrlPattern = RegExp(
    r'^data:image\/(png|jpe?g);base64,[A-Za-z0-9+/=\r\n]+$',
    caseSensitive: false,
  );

  static String? validateSet(String value, {ThresholdConfig? thresholds}) {
    final t = thresholds ?? const ThresholdConfig();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Set is required';
    }
    if (normalized.length > t.validationMaxSetLength) {
      return 'Set cannot exceed ${t.validationMaxSetLength} characters';
    }
    return null;
  }

  static String? validateNumber(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Number is required';
    }
    final pattern = RegExp(r'^[0-9]{1,6}$');
    if (!pattern.hasMatch(normalized)) {
      return 'Number must be numeric (1 to 6 digits)';
    }
    return null;
  }

  static String? validateEdition(String value, {ThresholdConfig? thresholds}) {
    final t = thresholds ?? const ThresholdConfig();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Edition is required';
    }
    if (normalized.length > t.validationMaxEditionLength) {
      return 'Edition cannot exceed ${t.validationMaxEditionLength} characters';
    }
    return null;
  }

  static String? validateLanguage(String value, {ThresholdConfig? thresholds}) {
    final t = thresholds ?? const ThresholdConfig();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Language is required';
    }
    const allowedLanguages = ['Español', 'English', 'Japanese'];
    if (!allowedLanguages.contains(normalized)) {
      return 'Language must be Español, English or Japanese';
    }
    if (normalized.length > t.validationMaxLanguageLength) {
      return 'Language cannot exceed ${t.validationMaxLanguageLength} characters';
    }
    return null;
  }

  static String? validateFinish(String value, {ThresholdConfig? thresholds}) {
    final t = thresholds ?? const ThresholdConfig();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Finish is required';
    }
    if (normalized.length > t.validationMaxFinishLength) {
      return 'Finish cannot exceed ${t.validationMaxFinishLength} characters';
    }
    return null;
  }

  static String? validateImageData(
    String value, {
    ThresholdConfig? thresholds,
  }) {
    final t = thresholds ?? const ThresholdConfig();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Image is required';
    }
    if (!_imageDataUrlPattern.hasMatch(normalized)) {
      return 'Image rejected: only PNG or JPG allowed';
    }

    final base64Part = normalized.split(',').last;
    if (base64Part.length < t.validationMinImageBase64Bytes) {
      return 'Image rejected: resolution or size insufficient';
    }

    final iqs = ImageQualityService.calculateScore(value, thresholds: t);
    if (iqs.score < t.iqsAcceptedThreshold) {
      return 'Image rejected: IQS not satisfied'
          'Reasons: ${iqs.rejectionReasons.join(', ')}';
    }

    final polyglot = PolyglotDetector.inspect(value);
    if (polyglot.isPolyglot) {
      return 'Image rejected: ${polyglot.indicators.join(', ')} detected';
    }

    return null;
  }

  static const List<String> allowedRarities = [
    'Common',
    'Uncommon',
    'Rare',
    'Holo Rare',
    'Ultra Rare',
    'Secret Rare',
  ];

  static String? validateRarity(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!allowedRarities.contains(value)) return 'Invalid rarity';
    return null;
  }

  static const List<String> allowedTypes = [
    'Normal',
    'Fighting',
    'Fire',
    'Water',
    'Grass',
    'Electric',
    'Psychic',
    'Dark',
    'Metal',
    'Dragon',
    'Fairy',
  ];

  static String? validateType(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!allowedTypes.contains(value)) return 'Invalid type';
    return null;
  }

  static String? validateHp(int? value, {ThresholdConfig? thresholds}) {
    final t = thresholds ?? const ThresholdConfig();
    if (value == null) return null;
    if (value < t.validationHpMin || value > t.validationHpMax) {
      return 'HP out of range';
    }
    return null;
  }

  static String? validateYear(int? value, {ThresholdConfig? thresholds}) {
    final t = thresholds ?? const ThresholdConfig();
    if (value == null) return null;
    if (value < t.validationYearMin || value > DateTime.now().year) {
      return 'Invalid year';
    }
    return null;
  }

  static String? validateAuthor(String value, {ThresholdConfig? thresholds}) {
    final t = thresholds ?? const ThresholdConfig();
    if (value.trim().isEmpty) return 'Author is required';
    if (value.trim().length > t.validationMaxAuthorLength) return 'Author too long';
    return null;
  }
}
