import 'user.dart';

class AuthPendingRegistration {
  final String email;
  final String username;
  final String password;
  final String token;
  final DateTime expiresAt;

  const AuthPendingRegistration({
    required this.email,
    required this.username,
    required this.password,
    required this.token,
    required this.expiresAt,
  });
}

abstract class AuthRepository {
  Future<bool> emailExists(String email);
  Future<bool> usernameExists(String username);
  Future<AuthPendingRegistration> startRegistration({
    required String email,
    required String username,
    required String password,
  });
  Future<User> confirmRegistration({
    required String token,
  });
}