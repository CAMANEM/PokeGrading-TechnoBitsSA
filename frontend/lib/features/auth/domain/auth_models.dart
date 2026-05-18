enum AuthFlowStage {
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

class AuthRegistrationState {
  final AuthFlowStage stage;
  final PendingRegistrationData? pendingRegistration;
  final ConfirmedUserData? confirmedUser;
  final String? message;

  const AuthRegistrationState({
    required this.stage,
    this.pendingRegistration,
    this.confirmedUser,
    this.message,
  });

  const AuthRegistrationState.initial()
      : stage = AuthFlowStage.idle,
        pendingRegistration = null,
        confirmedUser = null,
        message = null;

  AuthRegistrationState copyWith({
    AuthFlowStage? stage,
    PendingRegistrationData? pendingRegistration,
    ConfirmedUserData? confirmedUser,
    String? message,
  }) {
    return AuthRegistrationState(
      stage: stage ?? this.stage,
      pendingRegistration: pendingRegistration ?? this.pendingRegistration,
      confirmedUser: confirmedUser ?? this.confirmedUser,
      message: message ?? this.message,
    );
  }
}