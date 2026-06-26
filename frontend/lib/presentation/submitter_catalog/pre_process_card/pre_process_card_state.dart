/// @file
/// @brief State models for the pre-process card flow.

enum PreProcessCardStage {
  initial,
  preprocessing,
  success,
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
  final PreProcessCardResult? result;
  final String? message;

  const PreProcessCardState({
    required this.stage,
    this.result,
    this.message,
  });

  const PreProcessCardState.initial()
      : stage = PreProcessCardStage.initial,
        result = null,
        message = null;

  PreProcessCardState copyWith({
    PreProcessCardStage? stage,
    PreProcessCardResult? result,
    String? message,
  }) {
    return PreProcessCardState(
      stage: stage ?? this.stage,
      result: result ?? this.result,
      message: message,
    );
  }
}
