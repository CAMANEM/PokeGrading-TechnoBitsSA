/// @file
/// @brief

import 'package:flutter/foundation.dart';

import 'submit_evaluation_state.dart';
import 'submit_evaluation_api.dart';

/// @brief SubmitEvaluationProvider
class SubmitEvaluationProvider extends ChangeNotifier {
  SubmitEvaluationProvider(this._api);

  final SubmitEvaluationApi _api;
  SubmitEvaluationPayload? _lastPayload;

  SubmitEvaluationState _state = const SubmitEvaluationState.initial();

  SubmitEvaluationState get state => _state;

  Future<void> submit(
    SubmitEvaluationPayload payload,
  ) async {
    _lastPayload = payload;
    _state = _state.copyWith(
      stage: SubmitEvaluationStage.submitting,
      message: null,
    );

    notifyListeners();

    try {
      final result = await _api.submit(payload);

      _state = _state.copyWith(
        stage: SubmitEvaluationStage.success,
        result: result,
        message: 'Solicitud recibida correctamente',
      );
    } on SubmitEvaluationApiException catch (error) {
      _state = _state.copyWith(
        stage: SubmitEvaluationStage.error,
        message: error.message,
      );
    }

    notifyListeners();
  }

  Future<void> retry() async {
    final payload = _lastPayload;
    if (payload == null) {
      _state = _state.copyWith(
        stage: SubmitEvaluationStage.capture,
        message: null,
      );

      notifyListeners();
      return;
    }

    await submit(payload);
  }

  void reset() {
    _lastPayload = null;
    _state = const SubmitEvaluationState.initial();

    notifyListeners();
  }
}
