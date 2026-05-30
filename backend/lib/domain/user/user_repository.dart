import 'user.dart';

class PendingRegistration {
  final String email;
  final String username;
  final String password;

  final String country;
  final String language;

  final bool acceptedDisclosure;

  final String token;
  final DateTime expiresAt;

  const PendingRegistration({
    required this.email,
    required this.username,
    required this.password,
    required this.country,
    required this.language,
    required this.acceptedDisclosure,
    required this.token,
    required this.expiresAt,
  });
}

abstract class UserRepository {
  Future<bool> emailExists(String email);
  Future<bool> usernameExists(String username);
  Future<PendingRegistration> startRegistration({
    required String email,
    required String username,
    required String password,
    required String country,
    required String language,
    required bool acceptedDisclosure,
  });
  Future<User> confirmRegistration({
    required String token,
  });
}
