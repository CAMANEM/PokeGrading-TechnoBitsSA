/// @file
/// @brief

import '../image_services/visual_features.dart';
import 'catalog_models.dart';

/// @brief ScoredCandidateEntry
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

/// @brief SearchTrace
class SearchTrace {
  final String id;
  final DateTime timestamp;
  final String method;
  final VisualFeatures? queryFeatures;
  final CardIdentity? queryMetadata;
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
