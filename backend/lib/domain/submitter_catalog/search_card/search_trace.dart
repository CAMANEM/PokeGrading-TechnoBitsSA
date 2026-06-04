import 'visual_features.dart';

class ScoredCandidateEntry {
  final String cardId;
  final String? displayName;
  final double confidence;

  const ScoredCandidateEntry({
    required this.cardId,
    this.displayName,
    required this.confidence,
  });
}

class SearchMetadataEntry {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;

  const SearchMetadataEntry({
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
  });
}

class SearchTrace {
  final String id;
  final DateTime timestamp;
  final String method;
  final VisualFeatures? queryFeatures;
  final SearchMetadataEntry? queryMetadata;
  final List<ScoredCandidateEntry> candidates;
  final String decision;
  final String? decisionReason;

  const SearchTrace({
    required this.id,
    required this.timestamp,
    required this.method,
    this.queryFeatures,
    this.queryMetadata,
    this.candidates = const [],
    required this.decision,
    this.decisionReason,
  });
}
