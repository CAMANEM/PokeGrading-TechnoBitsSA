import 'package:flutter/foundation.dart';

import 'submit_evaluation_state.dart';
import 'submit_evaluation_api.dart';

class SubmitEvaluationProvider extends ChangeNotifier {
  SubmitEvaluationProvider(this._api);

  final SubmitEvaluationApi _api;

  SubmitEvaluationState _state = const SubmitEvaluationState.initial();

  SubmitEvaluationState get state => _state;

  Future<void> submit(
    SubmitEvaluationPayload payload,
  ) async {
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

  void retry() {
    _state = _state.copyWith(
      stage: SubmitEvaluationStage.capture,
      message: null,
    );

    notifyListeners();
  }

  void reset() {
    _state = const SubmitEvaluationState.initial();

    notifyListeners();
  }
}
