class CatalogValidators {
  static final RegExp _imageDataUrlPattern = RegExp(
    r'^data:image\/(png|jpe?g);base64,[A-Za-z0-9+/=\r\n]+$',
    caseSensitive: false,
  );

  static String? validateSet(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'El set es obligatorio';
    }
    if (normalized.length > 60) {
      return 'El set no puede superar 60 caracteres';
    }
    return null;
  }

  static String? validateNumber(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'El numero es obligatorio';
    }
    final pattern = RegExp(r'^[0-9]{1,6}$');
    if (!pattern.hasMatch(normalized)) {
      return 'El numero debe ser numerico (1 a 6 digitos)';
    }
    return null;
  }

  static String? validateEdition(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'La edicion es obligatoria';
    }
    if (normalized.length > 40) {
      return 'La edicion no puede superar 40 caracteres';
    }
    return null;
  }

  static String? validateLanguage(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'El idioma es obligatorio';
    }
    if (normalized.length > 30) {
      return 'El idioma no puede superar 30 caracteres';
    }
    return null;
  }

  static String? validateFinish(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'El acabado es obligatorio';
    }
    if (normalized.length > 30) {
      return 'El acabado no puede superar 30 caracteres';
    }
    return null;
  }

  static String? validateImageData(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'La imagen es obligatoria';
    }
    if (!_imageDataUrlPattern.hasMatch(normalized)) {
      return 'Imagen rechazada: solo se permite PNG o JPG';
    }

    final base64Part = normalized.split(',').last;
    if (base64Part.length < 24) {
      return 'Imagen rechazada';
    }

    return null;
  }
}
