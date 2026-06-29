/// @file
/// @brief

enum SearchCardStage {
  capture,
  searching,
  showingCandidates,
  manualSearch,
  success,
  error
}

enum ConfidenceType { fast, specialized }

/// @brief CandidateCard
class CandidateCard {
  final String id;
  final String name;
  final double confidence;

  CandidateCard({
    required this.id,
    required this.name,
    required this.confidence,
  });
}

/// @brief SearchCardPayload
class SearchCardPayload {
  final String imageData;
  final ConfidenceType mode;

  const SearchCardPayload({required this.imageData, required this.mode});
}

/// @brief ManualSearchPayload
class ManualSearchPayload {
  final String set;
  final String number;
  final String edition;
  final String language;
  final String finish;

  const ManualSearchPayload({
    required this.set,
    required this.number,
    required this.edition,
    required this.language,
    required this.finish,
  });
}

/// @brief SearchCardResult
class SearchCardResult {
  final SearchCardStage nextStage;
  final List<CandidateCard> candidates;
  final String? reason;

  const SearchCardResult(
      {required this.nextStage, this.candidates = const [], this.reason});
}

/// @brief SearchCardState
class SearchCardState {
  final SearchCardStage stage;
  final CandidateCard? selectedCandidate;
  final List<CandidateCard> candidates;
  final String? message;

  const SearchCardState(
      {required this.stage,
      this.selectedCandidate,
      required this.candidates,
      this.message});

  const SearchCardState.initial()
      : stage = SearchCardStage.capture,
        selectedCandidate = null,
        candidates = const [],
        message = null;

  SearchCardState copyWith({
    SearchCardStage? stage,
    CandidateCard? selectedCandidate,
    List<CandidateCard>? candidates,
    String? message,
  }) {
    return SearchCardState(
      stage: stage ?? this.stage,
      selectedCandidate: selectedCandidate ?? this.selectedCandidate,
      candidates: candidates ?? this.candidates,
      message: message ?? this.message,
    );
  }
}
