/// @file
/// @brief

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../domain/user/user.dart';
import '../../domain/user/user_repository.dart';

/// @brief PostgresUserRepository
class PostgresUserRepository implements UserRepository {
  final Connection _connection;

  PostgresUserRepository._(this._connection);

  /// Creates and opens a PostgreSQL connection using the provided config.
  static Future<PostgresUserRepository> connect(DatabaseConfig config) async {
    final endpoint = Endpoint(
      host: config.host,
      port: config.port,
      database: config.name,
      username: config.user,
      password: config.password,
    );

    final settings = ConnectionSettings(
      connectTimeout: config.connectionTimeout,
      sslMode: SslMode.disable,
    );

    final connection = await Connection.open(
      endpoint,
      settings: settings,
    );

    return PostgresUserRepository._(connection);
  }

  @override
  Future<bool> emailExists(String email) async {
    final result = await _connection.execute(
      'SELECT COUNT(1) FROM "USUARIO" WHERE LOWER("email") = LOWER(\$1)',
      parameters: [email.trim()],
    );
    return (result.first.first as int) > 0;
  }

  @override
  Future<bool> usernameExists(String username) async {
    final result = await _connection.execute(
      'SELECT COUNT(1) FROM "USUARIO" WHERE LOWER("username") = LOWER(\$1)',
      parameters: [username.trim()],
    );
    return (result.first.first as int) > 0;
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
    final passwordHash = _hashPassword(password);
    final createdAt = DateTime.now().toUtc();

    final id = await _connection.runTx<int>((tx) async {
      final result = await tx.execute(
        'SELECT COALESCE(MAX("id_usuario"), 0) + 1 FROM "USUARIO"',
      );
      final nextId = result.first.first as int;

      await tx.execute(
        'INSERT INTO "USUARIO" ('
        '"id_usuario", "username", "password_hash", "email", "rol", '
        '"pais_residencia", "idioma", "fecha_creacion"'
        ') VALUES ('
        '\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8'
        ')',
        parameters: [
          nextId,
          username.trim(),
          passwordHash,
          email.trim(),
          'submitter',
          country.trim(),
          language.trim(),
          createdAt,
        ],
      );

      return nextId;
    });

    return User(
      id: id.toString(),
      email: email.trim(),
      username: username.trim(),
      password: passwordHash,
      country: country.trim(),
      language: language.trim(),
      acceptedDisclosure: acceptedDisclosure,
      role: UserRole.submitter,
      status: UserRegistrationStatus.active,
      lastLoginAt: createdAt,
      createdAt: createdAt,
    );
  }

  Future<void> close() async {
    await _connection.close();
  }

  String _hashPassword(String password) {
    final normalized = password.trim();
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }
}
