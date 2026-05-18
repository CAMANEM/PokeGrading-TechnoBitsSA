import 'dart:math';

import 'package:uuid/uuid.dart';

import '../domain/auth_repository.dart';
import '../domain/user.dart';

class MemoryAuthRepository implements AuthRepository {
  final Map<String, User> _usersById = {};
  final Map<String, AuthPendingRegistration> _pendingByToken = {};
  final Uuid _uuid;
  final Random _random;

  MemoryAuthRepository({Uuid? uuid, Random? random})
      : _uuid = uuid ?? const Uuid(),
        _random = random ?? Random.secure();

  @override
  Future<bool> emailExists(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final userExists = _usersById.values.any(
      (user) => user.email.trim().toLowerCase() == normalizedEmail,
    );

    final pendingExists = _pendingByToken.values.any(
      (pending) => pending.email.trim().toLowerCase() == normalizedEmail,
    );

    return userExists || pendingExists;
  }

  @override
  Future<bool> usernameExists(String username) async {
    final normalizedUsername = username.trim().toLowerCase();
    final userExists = _usersById.values.any(
      (user) => user.username.trim().toLowerCase() == normalizedUsername,
    );

    final pendingExists = _pendingByToken.values.any(
      (pending) => pending.username.trim().toLowerCase() == normalizedUsername,
    );

    return userExists || pendingExists;
  }

  @override
  Future<AuthPendingRegistration> startRegistration({
    required String email,
    required String username,
    required String password,
  }) async {
    final token = _generateToken();
    final pending = AuthPendingRegistration(
      email: email.trim(),
      username: username.trim(),
      password: password,
      token: token,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );

    _pendingByToken[token] = pending;
    return pending;
  }

  @override
  Future<User> confirmRegistration({required String token}) async {
    final pending = _pendingByToken.remove(token);
    if (pending == null) {
      throw StateError('Invalid or expired token');
    }

    if (pending.expiresAt.isBefore(DateTime.now().toUtc())) {
      throw StateError('Invalid or expired token');
    }

    final user = User(
      id: _uuid.v4(),
      email: pending.email,
      username: pending.username,
      password: pending.password,
      status: UserRegistrationStatus.active,
      createdAt: DateTime.now().toUtc(),
    );

    _usersById[user.id] = user;
    return user;
  }

  String _generateToken() {
    final value = _random.nextInt(1000000).toString().padLeft(6, '0');
    return value;
  }
}