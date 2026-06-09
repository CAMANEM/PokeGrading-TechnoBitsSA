/*
 In-memory `UserRepository` implementation used for development and tests.

 Notes:
 - Stores users in process memory; data is lost when the process exits.
 - Creates active user accounts directly without email confirmation.
 - Do not use this implementation in production.
*/
import 'package:uuid/uuid.dart';

import '../../domain/authentication/auth_models.dart';
import '../user_data_provider/auth_repository.dart';

/// @brief MemoryUserRepository
class MemoryUserRepository implements UserRepository {
  final Map<String, User> _usersById = {};
  final Uuid _uuid;

  MemoryUserRepository({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  Future<bool> emailExists(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    return _usersById.values.any(
      (user) => user.email.trim().toLowerCase() == normalizedEmail,
    );
  }

  @override
  Future<bool> usernameExists(String username) async {
    final normalizedUsername = username.trim().toLowerCase();
    return _usersById.values.any(
      (user) => user.username.trim().toLowerCase() == normalizedUsername,
    );
  }

  @override
  Future<User> createUser({
    required String email,
    required String username,
    required String password,
    required String country,
    required String language,
    required bool acceptedDisclosure,
  }) async {
    final user = User(
      id: _uuid.v4(),
      email: email.trim(),
      username: username.trim(),
      password: password,
      country: country.trim(),
      language: language.trim(),
      acceptedDisclosure: acceptedDisclosure,
      role: UserRole.submitter,
      status: UserRegistrationStatus.active,
      lastLoginAt: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
    );

    _usersById[user.id] = user;
    return user;
  }
}
