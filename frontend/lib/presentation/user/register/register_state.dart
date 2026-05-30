enum RegisterStage {
  idle,
  submitting,
  awaitingToken,
  confirming,
  success,
  error,
}

class PendingRegistrationData {
  final String email;
  final String username;
  final DateTime expiresAt;

  const PendingRegistrationData({
    required this.email,
    required this.username,
    required this.expiresAt,
  });
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
  final PendingRegistrationData? pendingRegistration;
  final ConfirmedUserData? confirmedUser;
  final String? message;

  const RegisterState({
    required this.stage,
    this.pendingRegistration,
    this.confirmedUser,
    this.message,
  });

  const RegisterState.initial()
      : stage = RegisterStage.idle,
        pendingRegistration = null,
        confirmedUser = null,
        message = null;

  RegisterState copyWith({
    RegisterStage? stage,
    PendingRegistrationData? pendingRegistration,
    ConfirmedUserData? confirmedUser,
    String? message,
  }) {
    return RegisterState(
      stage: stage ?? this.stage,
      pendingRegistration: pendingRegistration ?? this.pendingRegistration,
      confirmedUser: confirmedUser ?? this.confirmedUser,
      message: message,
    );
  }
}
