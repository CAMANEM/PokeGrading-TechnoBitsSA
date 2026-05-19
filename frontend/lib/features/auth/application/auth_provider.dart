import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_models.dart';
import '../infrastructure/auth_api_client.dart';

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  return AuthApiClient();
});

final authRegistrationControllerProvider = StateNotifierProvider<
    AuthRegistrationController, AuthRegistrationState>((ref) {
  return AuthRegistrationController(ref.read(authApiClientProvider));
});

class AuthRegistrationController extends StateNotifier<AuthRegistrationState> {
  final AuthApiClient _apiClient;

  AuthRegistrationController(this._apiClient)
      : super(const AuthRegistrationState.initial());

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String country,
    required String language,
  }) async {
    state = state.copyWith(stage: AuthFlowStage.submitting, message: null);

    try {
      final pending = await _apiClient.register(
        email: email,
        username: username,
        password: password,
        country: country,
        language: language
      );

      state = state.copyWith(
        stage: AuthFlowStage.awaitingToken,
        pendingRegistration: pending,
        message: 'Revisa tu correo para confirmar el registro.',
      );
    } on AuthApiException catch (error) {
      state = state.copyWith(
        stage: AuthFlowStage.error,
        message: error.message,
      );
    }
  }

  Future<void> confirm({required String token}) async {
    state = state.copyWith(stage: AuthFlowStage.confirming, message: null);

    try {
      final confirmed = await _apiClient.confirm(token: token);
      state = state.copyWith(
        stage: AuthFlowStage.success,
        confirmedUser: confirmed,
        message: 'Cuenta confirmada y registrada correctamente.',
      );
    } on AuthApiException catch (error) {
      state = state.copyWith(
        stage: AuthFlowStage.error,
        message: error.message,
      );
    }
  }

  void reset() {
    state = const AuthRegistrationState.initial();
  }
}