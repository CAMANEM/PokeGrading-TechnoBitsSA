/// @file
/// @brief

class EvaluationValidators {
  static final RegExp _imagePattern = RegExp(
    r'^data:image\/(png|jpe?g|heic);base64,',
    caseSensitive: false,
  );

  static String? validateImage(String imageData) {
    if (imageData.trim().isEmpty) {
      return 'Image is required';
    }

    if (!_imagePattern.hasMatch(imageData)) {
      return 'Invalid image format';
    }

    return null;
  }
}
