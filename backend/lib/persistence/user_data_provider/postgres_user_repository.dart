/// @file
/// @brief

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
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
    AppLogger.info(
      'PokéGrading.Persistence.UserRepository',
      'Connecting to PostgreSQL user database',
      context: {'host': config.host, 'database': config.name},
    );

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

    try {
      final connection = await Connection.open(
        endpoint,
        settings: settings,
      );

      AppLogger.info(
        'PokéGrading.Persistence.UserRepository',
        'PostgreSQL user repository connected',
      );

      return PostgresUserRepository._(connection, LookupResolver(connection));
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.UserRepository',
        'Failed to connect to PostgreSQL user database',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<bool> emailExists(String email) async {
    try {
      final result = await _connection.execute(
        'SELECT COUNT(1) FROM submitter WHERE LOWER(email) = LOWER(\$1)',
        parameters: [email.trim()],
      );
      final exists = (result.first.first as int) > 0;
      AppLogger.info(
        'PokéGrading.Persistence.UserRepository',
        'Email existence check',
        context: {'email': email, 'exists': exists},
      );
      return exists;
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.UserRepository',
        'Email existence check failed',
        context: {'email': email},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<bool> usernameExists(String username) async {
    try {
      final result = await _connection.execute(
        'SELECT COUNT(1) FROM submitter WHERE LOWER(username) = LOWER(\$1)',
        parameters: [username.trim()],
      );
      final exists = (result.first.first as int) > 0;
      AppLogger.info(
        'PokéGrading.Persistence.UserRepository',
        'Username existence check',
        context: {'username': username, 'exists': exists},
      );
      return exists;
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.UserRepository',
        'Username existence check failed',
        context: {'username': username},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
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
    AppLogger.info(
      'PokéGrading.Persistence.UserRepository',
      'Creating user',
      context: {'email': email, 'username': username},
    );

    final passwordHash = _hashPassword(password);
    final createdAt = DateTime.now().toUtc();

    try {
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

      AppLogger.info(
        'PokéGrading.Persistence.UserRepository',
        'User created successfully',
        context: {'user_id': id.toString(), 'email': email},
      );

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
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.UserRepository',
        'User creation failed',
        context: {'email': email, 'username': username},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
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
