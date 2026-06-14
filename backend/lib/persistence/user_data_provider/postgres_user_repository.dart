/// @file
/// @brief

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../domain/authentication/auth_models.dart';
import '../lookup/lookup_resolver.dart';
import 'auth_repository.dart';

/// @brief PostgresUserRepository
class PostgresUserRepository implements UserRepository {
  final Connection _connection;
  final LookupResolver _lookups;

  PostgresUserRepository._(this._connection, this._lookups);

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

    return PostgresUserRepository._(connection, LookupResolver(connection));
  }

  @override
  Future<bool> emailExists(String email) async {
    final result = await _connection.execute(
      'SELECT COUNT(1) FROM submitter WHERE LOWER(email) = LOWER(\$1)',
      parameters: [email.trim()],
    );
    return (result.first.first as int) > 0;
  }

  @override
  Future<bool> usernameExists(String username) async {
    final result = await _connection.execute(
      'SELECT COUNT(1) FROM submitter WHERE LOWER(username) = LOWER(\$1)',
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
    final countryId =
        await _lookups.resolveCountryId(country, insertIfMissing: true);
    final languageId =
        await _lookups.resolveLanguageId(language, insertIfMissing: true);

    final id = await _connection.runTx<int>((tx) async {
      final lookups = LookupResolver(tx);
      final resolvedCountryId = countryId ??
          await lookups.resolveCountryId(country, insertIfMissing: true);
      final resolvedLanguageId = languageId ??
          await lookups.resolveLanguageId(language, insertIfMissing: true);

      final result = await tx.execute(
        '''
        INSERT INTO submitter (
          username, password_hash, email, country_id, language_id, registration_date
        ) VALUES (\$1, \$2, \$3, \$4, \$5, \$6)
        RETURNING id
        ''',
        parameters: [
          username.trim(),
          passwordHash,
          email.trim(),
          resolvedCountryId,
          resolvedLanguageId,
          createdAt,
        ],
      );

      return result.first.first as int;
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
