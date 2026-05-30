import '../user.dart';
import '../user_repository.dart';
import '../user_validators.dart';
import '../../../persistence/user/confirmation_email_sender.dart';

class RegisterLogicException implements Exception {
  final String code;
  final String message;

  const RegisterLogicException({required this.code, required this.message});

  @override
  String toString() => 'RegisterLogicException($code): $message';
}

class RegisterSession {
  final String email;
  final String username;
  final DateTime expiresAt;

  const RegisterSession({
    required this.email,
    required this.username,
    required this.expiresAt,
  });
}

class ConfirmedUser {
  final String id;
  final String email;
  final String username;

  const ConfirmedUser({
    required this.id,
    required this.email,
    required this.username,
  });

  factory ConfirmedUser.fromUser(User user) {
    return ConfirmedUser(
      id: user.id,
      email: user.email,
      username: user.username,
    );
  }
}

class RegisterLogic {
  final UserRepository repository;
  final ConfirmationEmailSender emailSender;

  const RegisterLogic({
    required this.repository,
    required this.emailSender,
  });

  Future<RegisterSession> register({
    required String email,
    required String username,
    required String password,
    required String country,
    required String language,
    required bool acceptedDisclosure,
  }) async {
    final emailError = UserValidators.validateEmail(email);
    if (emailError != null) {
      throw RegisterLogicException(code: 'invalid_email', message: emailError);
    }

    final usernameError = UserValidators.validateUsername(username);
    if (usernameError != null) {
      throw RegisterLogicException(
        code: 'invalid_username',
        message: usernameError,
      );
    }

    final passwordError = UserValidators.validatePassword(password);
    if (passwordError != null) {
      throw RegisterLogicException(
        code: 'invalid_password',
        message: passwordError,
      );
    }

    final countryError = UserValidators.validateCountry(country);
    if (countryError != null) {
      throw RegisterLogicException(
        code: 'invalid_country',
        message: countryError,
      );
    }

    final languageError = UserValidators.validateLanguage(language);
    if (languageError != null) {
      throw RegisterLogicException(
        code: 'invalid_language',
        message: languageError,
      );
    }

    final disclosureError = UserValidators.validateDisclosure(acceptedDisclosure);
    if (disclosureError != null) {
      throw RegisterLogicException(
        code: 'disclosure_required',
        message: disclosureError,
      );
    }

    final blockedDomainError = UserValidators.validateEmailDomain(email);
    if (blockedDomainError != null) {
      throw RegisterLogicException(
        code: 'blocked_email_domain',
        message: blockedDomainError,
      );
    }

    if (await repository.emailExists(email)) {
      throw RegisterLogicException(
        code: 'email_exists',
        message: 'Email is already registered or pending confirmation',
      );
    }

    if (await repository.usernameExists(username)) {
      throw RegisterLogicException(
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

    return RegisterSession(
      email: pending.email,
      username: pending.username,
      expiresAt: pending.expiresAt,
    );
  }

  Future<ConfirmedUser> confirm({required String token}) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw RegisterLogicException(
        code: 'invalid_token',
        message: 'Token is required',
      );
    }

    try {
      final user = await repository.confirmRegistration(token: normalizedToken);
      return ConfirmedUser.fromUser(user);
    } on StateError {
      throw const RegisterLogicException(
        code: 'invalid_token',
        message: 'Token is invalid or expired',
      );
    }
  }
}
