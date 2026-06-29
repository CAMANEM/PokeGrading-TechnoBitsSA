/// @file
/// @brief

import 'package:flutter/foundation.dart';

import '../../../core/logging/client_log_reporter.dart';
import 'create_card_api.dart';
import 'create_card_state.dart';

/*
 Provider for the create-card flow. Exposes simple methods to advance the
 multi-step UI (identity -> image -> submitting) and delegates network
 operations to `CreateCardApi`.

 It updates `CreateCardState` and notifies listeners for UI updates.
*/

/// @brief CreateCardProvider
class CreateCardProvider extends ChangeNotifier {
  CreateCardProvider(this._api);

  final CreateCardApi _api;
  CreateCardState _state = const CreateCardState.initial();

  CreateCardState get state => _state;

  void submitIdentity(CardIdentityInput identity) {
    _state = _state.copyWith(
      identity: identity,
      stage: CreateCardStage.image,
      message: null,
    );
    notifyListeners();
  }

  Future<void> submitImage(String imageData) async {
    final identity = _state.identity;
    if (identity == null) {
      _state = _state.copyWith(
        stage: CreateCardStage.error,
        message: 'Complete card identity first',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(stage: CreateCardStage.submitting, message: null);
    notifyListeners();

    try {
      final result = await _api.addCard(
        CreateCardPayload(
          identity: identity,
          displayName: _state.displayName,
          imageData: imageData,
        ),
      );

      _state = _state.copyWith(
        stage: CreateCardStage.success,
        result: result,
        message: 'Card added successfully',
      );
    } on CreateCardApiException catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.CreateCardProvider',
        correlationId: '',
        message: 'Submit image failed',
        context: {'api_error': error.message},
      );
      _state = _state.copyWith(
        stage: CreateCardStage.error,
        message: error.message,
      );
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.CreateCardProvider',
        correlationId: '',
        message: 'Submit image unexpected error',
        context: {'error': error.toString()},
      );
      _state = _state.copyWith(
        stage: CreateCardStage.error,
        message: 'Error: ${error.toString()}',
      );
    }

    notifyListeners();
  }

  Future<void> submitImagePayload(CreateCardPayload payload) async {
    _state = _state.copyWith(stage: CreateCardStage.submitting, message: null);
    notifyListeners();

    try {
      final result = await _api.addCard(payload);

      _state = _state.copyWith(
        stage: CreateCardStage.success,
        result: result,
        message: 'Card added successfully',
      );
    } on CreateCardApiException catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.CreateCardProvider',
        correlationId: '',
        message: 'Submit image payload failed',
        context: {'api_error': error.message},
      );
      _state = _state.copyWith(
        stage: CreateCardStage.error,
        message: error.message,
      );
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.CreateCardProvider',
        correlationId: '',
        message: 'Submit image payload unexpected error',
        context: {'error': error.toString()},
      );
      _state = _state.copyWith(
        stage: CreateCardStage.error,
        message: 'Error: ${error.toString()}',
      );
    }

    notifyListeners();
  }

  void reset() {
    _state = const CreateCardState.initial();
    notifyListeners();
  }

  void retryFromImage() {
    _state = _state.copyWith(
      stage: CreateCardStage.image,
      message: null,
    );
    notifyListeners();
  }

  void backToIdentity() {
    _state = _state.copyWith(
      stage: CreateCardStage.identity,
      message: null,
    );
    notifyListeners();
  }
}
