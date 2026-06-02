/*
 Models and DTOs for the registration UI flow.

 - `RegisterStage`: small enum describing the current UI step.
 - `ConfirmedUserData`: user information returned after successful registration.
 - `RegisterState`: immutable state object used by `RegisterProvider`.
*/

enum RegisterStage {
  idle,
  submitting,
  success,
  error,
}

class ConfirmedUserData {
  final String id;
  final String email;
  final String username;

  const ConfirmedUserData({
    required this.id,
    required this.email,
    required this.username,
  });
}

class RegisterState {
  final RegisterStage stage;
  final ConfirmedUserData? confirmedUser;
  final String? message;

  const RegisterState({
    required this.stage,
    this.confirmedUser,
    this.message,
  });

  const RegisterState.initial()
      : stage = RegisterStage.idle,
        confirmedUser = null,
        message = null;

  RegisterState copyWith({
    RegisterStage? stage,
    ConfirmedUserData? confirmedUser,
    String? message,
  }) {
    return RegisterState(
      stage: stage ?? this.stage,
      confirmedUser: confirmedUser ?? this.confirmedUser,
      message: message,
    );
  }
}
