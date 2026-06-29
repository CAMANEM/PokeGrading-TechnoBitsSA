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

  PreProcessCardState _state = const PreProcessCardState.initial();

  PreProcessCardState get state => _state;

  Future<void> preprocessFront(String imageData) async {
    _state = _state.copyWith(
      stage: PreProcessCardStage.preprocessing,
      message: null,
    );

    notifyListeners();

    try {
      final result = await _api.preprocess(
        PreProcessCardPayload(imageData: imageData),
      );

      _state = _state.copyWith(
        stage: PreProcessCardStage.frontSuccess,
        frontResult: result,
        message: 'Imagen frontal pre-procesada correctamente',
      );
    } on PreProcessCardApiException catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.PreProcessCardProvider',
        correlationId: '',
        message: 'Front preprocess failed',
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
        message: 'Front preprocess unexpected error',
        context: {'error': error.toString()},
      );
      _state = _state.copyWith(
        stage: PreProcessCardStage.error,
        message: 'Error: ${error.toString()}',
      );
    }

    notifyListeners();
  }

  Future<void> preprocessBack(String imageData) async {
    _state = _state.copyWith(
      stage: PreProcessCardStage.preprocessingBack,
      message: null,
    );

    notifyListeners();

    try {
      final result = await _api.preprocess(
        PreProcessCardPayload(imageData: imageData),
      );

      _state = _state.copyWith(
        stage: PreProcessCardStage.backSuccess,
        backResult: result,
        message: 'Imagen del reverso pre-procesada correctamente',
      );
    } on PreProcessCardApiException catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.PreProcessCardProvider',
        correlationId: '',
        message: 'Back preprocess failed',
        context: {'api_error': error.message},
      );
      _state = _state.copyWith(
        stage: PreProcessCardStage.frontSuccess,
        message: 'Error al pre-procesar reverso: ${error.message}',
      );
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.PreProcessCardProvider',
        correlationId: '',
        message: 'Back preprocess unexpected error',
        context: {'error': error.toString()},
      );
      _state = _state.copyWith(
        stage: PreProcessCardStage.frontSuccess,
        message: 'Error: ${error.toString()}',
      );
    }

    notifyListeners();
  }

  void reset() {
    _state = const PreProcessCardState.initial();
    notifyListeners();
  }
}
