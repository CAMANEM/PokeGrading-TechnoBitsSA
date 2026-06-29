/// @file
/// @brief

import 'dart:convert';

/// @brief PolyglotDetectionResult
class PolyglotDetectionResult {
  final bool isPolyglot;
  final List<String> indicators;

  const PolyglotDetectionResult({
    required this.isPolyglot,
    required this.indicators,
  });
}

/// @brief PolyglotDetector
class PolyglotDetector {
  static PolyglotDetectionResult inspect(String imageData) {
    final base64Part = imageData.split(',').last;

    final bytes = base64Decode(base64Part);

    final indicators = <String>[];

    final content = latin1.decode(
      bytes,
      allowInvalid: true,
    );

    if (content.contains('PK\u0003\u0004')) {
      indicators.add('embedded_zip');
    }

    if (content.contains('%PDF')) {
      indicators.add('embedded_pdf');
    }

    if (content.contains('<?php')) {
      indicators.add('embedded_php');
    }

    if (content.contains('<script')) {
      indicators.add('embedded_javascript');
    }

    if (content.contains('<html')) {
      indicators.add('embedded_html');
    }

    return PolyglotDetectionResult(
      isPolyglot: indicators.isNotEmpty,
      indicators: indicators,
    );
  }
}
