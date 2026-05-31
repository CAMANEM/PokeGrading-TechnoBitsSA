/*
 Validation helpers for submitter catalog inputs.

 Contains static methods to validate identity fields (set, number, edition,
 language, finish), image payloads and optional metadata (rarity, type, hp,
 year, author). Methods return `null` on success or an error message on failure.
*/
class CatalogValidators {
  static final RegExp _imageDataUrlPattern = RegExp(
    r'^data:image\/(png|jpe?g);base64,[A-Za-z0-9+/=\r\n]+$',
    caseSensitive: false,
  );

  static String? validateSet(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Set is required';
    }
    if (normalized.length > 60) {
      return 'Set cannot exceed 60 characters';
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

  static String? validateEdition(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Edition is required';
    }
    if (normalized.length > 40) {
      return 'Edition cannot exceed 40 characters';
    }
    return null;
  }

  static String? validateLanguage(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Language is required';
    }
    const allowedLanguages = ['Español', 'Inglés'];
    if (!allowedLanguages.contains(normalized)) {
      return 'Language must be Español or Inglés';
    }
    if (normalized.length > 30) {
      return 'Language cannot exceed 30 characters';
    }
    return null;
  }

  static String? validateFinish(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Finish is required';
    }
    if (normalized.length > 30) {
      return 'Finish cannot exceed 30 characters';
    }
    return null;
  }

  static String? validateImageData(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Image is required';
    }
    if (!_imageDataUrlPattern.hasMatch(normalized)) {
      return 'Image rejected: only PNG or JPG allowed';
    }

    final base64Part = normalized.split(',').last;
    if (base64Part.length < 5 * 1024) {
      return 'Image rejected: resolution or size insufficient';
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

  static String? validateHp(int? value) {
    if (value == null) return null;
    if (value < 0 || value > 2000) return 'HP out of range';
    return null;
  }

  static String? validateYear(int? value) {
    if (value == null) return null;
    if (value < 1950 || value > DateTime.now().year) return 'Invalid year';
    return null;
  }

  static String? validateAuthor(String? value) {
    if (value == null || value.trim().isEmpty) return 'Author is required';
    if (value.trim().length > 100) return 'Author too long';
    return null;
  }
}
