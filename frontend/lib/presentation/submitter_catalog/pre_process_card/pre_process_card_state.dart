/// @file
/// @brief State models for the pre-process card flow.

enum PreProcessCardStage {
  initial,
  preprocessing,
  frontSuccess,
  preprocessingBack,
  backSuccess,
  error,
}

/// @brief PreProcessCardPayload
class PreProcessCardPayload {
  final String imageData;

  const PreProcessCardPayload({required this.imageData});
}

/// @brief PreProcessCardResult
class PreProcessCardResult {
  final String correctedImage;
  final List<Map<String, dynamic>>? corners;
  final Map<String, dynamic>? metadata;

  const PreProcessCardResult({
    required this.correctedImage,
    this.corners,
    this.metadata,
  });
}

/// @brief PreProcessCardState
class PreProcessCardState {
  final PreProcessCardStage stage;
  final PreProcessCardResult? frontResult;
  final PreProcessCardResult? backResult;
  final String? message;

  const PreProcessCardState({
    required this.stage,
    this.frontResult,
    this.backResult,
    this.message,
  });

  const PreProcessCardState.initial()
      : stage = PreProcessCardStage.initial,
        frontResult = null,
        backResult = null,
        message = null;

  PreProcessCardState copyWith({
    PreProcessCardStage? stage,
    PreProcessCardResult? frontResult,
    PreProcessCardResult? backResult,
    String? message,
  }) {
    return PreProcessCardState(
      stage: stage ?? this.stage,
      frontResult: frontResult ?? this.frontResult,
      backResult: backResult ?? this.backResult,
      message: message,
    );
  }
}
