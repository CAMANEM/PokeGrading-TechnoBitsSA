import '../domain/auth_repository.dart';
import '../domain/auth_validators.dart';
import '../domain/user.dart';

abstract class ConfirmationEmailSender {
  Future<void> sendToken({
    required String email,
    required String username,
    required String token,
    required DateTime expiresAt,
  });
}

class AuthServiceException implements Exception {
  final String code;
  final String message;

  const AuthServiceException({required this.code, required this.message});

  @override
  String toString() => 'AuthServiceException($code): $message';
}

class AuthRegistrationSession {
  final String email;
  final String username;
  final DateTime expiresAt;

  const AuthRegistrationSession({
    required this.email,
    required this.username,
    required this.expiresAt,
  });
}

class AuthConfirmedUser {
  final String id;
  final String email;
  final String username;

  const AuthConfirmedUser({
    required this.id,
    required this.email,
    required this.username,
  });

  factory AuthConfirmedUser.fromUser(User user) {
    return AuthConfirmedUser(
      id: user.id,
      email: user.email,
      username: user.username,
    );
  }
}

class AuthService {
  final AuthRepository repository;
  final ConfirmationEmailSender emailSender;

  const AuthService({
    required this.repository,
    required this.emailSender,
  });

  Future<AuthRegistrationSession> startRegistration({
    required String email,
    required String username,
    required String password,
    required String country,
    required String language,
    required bool acceptedDisclosure
  }) async {
    final emailError = AuthValidators.validateEmail(email);
    if (emailError != null) {
      throw AuthServiceException(code: 'invalid_email', message: emailError);
    }

    final usernameError = AuthValidators.validateUsername(username);
    if (usernameError != null) {
      throw AuthServiceException(
        code: 'invalid_username',
        message: usernameError,
      );
    }

    final passwordError = AuthValidators.validatePassword(password);
    if (passwordError != null) {
      throw AuthServiceException(
        code: 'invalid_password',
        message: passwordError,
      );
    }

    final countryError = AuthValidators.validateCountry(country);
    if (countryError != null) {
      throw AuthServiceException(
        code: 'invalid_country',
        message: countryError,
      );
    }

    final languageError = AuthValidators.validateLanguage(language);
    if (languageError != null) {
      throw AuthServiceException(
        code: 'invalid_language',
        message: languageError,
      );
    }

    final disclosureError = AuthValidators.validateDisclosure(acceptedDisclosure,);
    if (disclosureError != null) {
      throw AuthServiceException(
        code: 'disclosure_required',
        message: disclosureError,
      );
    }

    final blockedDomainError = AuthValidators.validateEmailDomain(email);
    if (blockedDomainError != null) {
      throw AuthServiceException(
        code: 'blocked_email_domain',
        message: blockedDomainError,
      );
    }

    if (await repository.emailExists(email)) {
      throw AuthServiceException(
        code: 'email_exists',
        message: 'Email is already registered or pending confirmation',
      );
    }

    if (await repository.usernameExists(username)) {
      throw AuthServiceException(
        code: 'username_exists',
        message: 'Username is already registered or pending confirmation',
      );
    }

    final pending = await repository.startRegistration(
      email: email,
      username: username,
      password: password,
      country: country,
      language: language,
      acceptedDisclosure: acceptedDisclosure,
    );

    await emailSender.sendToken(
      email: pending.email,
      username: pending.username,
      token: pending.token,
      expiresAt: pending.expiresAt,
    );

    return AuthRegistrationSession(
      email: pending.email,
      username: pending.username,
      expiresAt: pending.expiresAt,
    );
  }

  Future<AuthConfirmedUser> confirmRegistration({required String token}) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw AuthServiceException(
        code: 'invalid_token',
        message: 'Token is required',
      );
    }

    try {
      final user = await repository.confirmRegistration(token: normalizedToken);
      return AuthConfirmedUser.fromUser(user);
    } on StateError {
      throw const AuthServiceException(
        code: 'invalid_token',
        message: 'Token is invalid or expired',
      );
    }
  }
}