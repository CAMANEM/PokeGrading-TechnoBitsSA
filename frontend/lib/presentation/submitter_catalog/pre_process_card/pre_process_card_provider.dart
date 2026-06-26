/// @file
/// @brief Provider for the pre-process card flow.

import 'package:flutter/foundation.dart';

import '../../../core/logging/client_log_reporter.dart';
import 'pre_process_card_api.dart';
import 'pre_process_card_state.dart';

/// @brief PreProcessCardProvider
class PreProcessCardProvider extends ChangeNotifier {
  PreProcessCardProvider(this._api);

  final PreProcessCardApi _api;
  PreProcessCardPayload? _lastPayload;

  PreProcessCardState _state = const PreProcessCardState.initial();

  PreProcessCardState get state => _state;

  Future<void> preprocessImage(PreProcessCardPayload payload) async {
    _lastPayload = payload;
    _state = _state.copyWith(
      stage: PreProcessCardStage.preprocessing,
      message: null,
    );

    notifyListeners();

    try {
      final result = await _api.preprocess(payload);

      _state = _state.copyWith(
        stage: PreProcessCardStage.success,
        result: result,
        message: 'Carta pre-procesada correctamente',
      );
    } on PreProcessCardApiException catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.PreProcessCardProvider',
        correlationId: '',
        message: 'Preprocess failed',
        context: {'api_error': error.message},
      );
      _state = _state.copyWith(
        stage: PreProcessCardStage.error,
        message: error.message,
      );
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.PreProcessCardProvider',
        correlationId: '',
        message: 'Preprocess unexpected error',
        context: {'error': error.toString()},
      );
      _state = _state.copyWith(
        stage: PreProcessCardStage.error,
        message: 'Error: ${error.toString()}',
      );
    }

    notifyListeners();
  }

  Future<void> retry() async {
    final payload = _lastPayload;
    if (payload == null) {
      _state = const PreProcessCardState.initial();
      notifyListeners();
      return;
    }

    await preprocessImage(payload);
  }

  void reset() {
    _lastPayload = null;
    _state = const PreProcessCardState.initial();
    notifyListeners();
  }
}
