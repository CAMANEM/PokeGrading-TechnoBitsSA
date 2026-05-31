import 'package:flutter/foundation.dart';

import 'register_api.dart';
import 'register_state.dart';

/*
 Provider (ChangeNotifier) responsible for the registration UI flow.

 Orchestrates calls to `RegisterApi`, updates `RegisterState` accordingly
 and notifies listeners. UI code should listen to this provider to reflect
 progress, errors and success states.
*/
class RegisterProvider extends ChangeNotifier {
  RegisterProvider(this._api);

  final RegisterApi _api;
  RegisterState _state = const RegisterState.initial();

  RegisterState get state => _state;

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String country,
    required String language,
    required bool acceptedDisclosure,
  }) async {
    _state = _state.copyWith(stage: RegisterStage.submitting, message: null);
    notifyListeners();

    try {
      final pending = await _api.register(
        email: email,
        username: username,
        password: password,
        country: country,
        language: language,
        acceptedDisclosure: acceptedDisclosure,
      );

      _state = _state.copyWith(
        stage: RegisterStage.awaitingToken,
        pendingRegistration: pending,
        message: 'Check your email to confirm registration.',
      );
    } on RegisterApiException catch (error) {
      _state = _state.copyWith(
        stage: RegisterStage.error,
        message: error.message,
      );
    }

    notifyListeners();
  }

  Future<void> confirm({required String token}) async {
    _state = _state.copyWith(stage: RegisterStage.confirming, message: null);
    notifyListeners();

    try {
      final confirmed = await _api.confirm(token: token);
      _state = _state.copyWith(
        stage: RegisterStage.success,
        confirmedUser: confirmed,
        message: 'Account confirmed and registered successfully.',
      );
    } on RegisterApiException catch (error) {
      _state = _state.copyWith(
        stage: RegisterStage.error,
        message: error.message,
      );
    }

    notifyListeners();
  }

  void reset() {
    _state = const RegisterState.initial();
    notifyListeners();
  }
}
