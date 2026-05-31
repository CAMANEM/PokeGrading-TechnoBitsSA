/*
 Domain logic for user registration and confirmation.

 This module implements the `RegisterLogic` use-case which performs input
 validation, coordinates with the `UserRepository` to create pending
 registrations, and sends confirmation tokens through a `ConfirmationEmailSender`.

 Public API:
 - `RegisterLogic.register(...)` : starts a registration and sends a token
 - `RegisterLogic.confirm(...)` : confirms a registration using a token
 - `RegisterSession` : DTO returned when registration is started
 - `ConfirmedUser` : DTO returned after a successful confirmation

 Errors are represented by `RegisterLogicException` using short `code`
 identifiers suitable for mapping to HTTP response codes and bodies.
*/
import '../user.dart';
import '../user_repository.dart';
import '../user_validators.dart';
import '../../../persistence/user/confirmation_email_sender.dart';

/*
 Represents an error raised by `RegisterLogic`.

 `code` is a short machine-friendly identifier (e.g. `invalid_email`,
 `email_exists`, `invalid_token`) and `message` provides a human-readable
 explanation for logs and client error messages.
*/
class RegisterLogicException implements Exception {
  final String code;
  final String message;

  const RegisterLogicException({required this.code, required this.message});

  @override
  String toString() => 'RegisterLogicException($code): $message';
}

/*
 DTO returned when a registration has been initiated.

 `email` and `username` reflect the pending registration details and
 `expiresAt` indicates when the confirmation token will expire.
*/
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

/*
 Value object returned after successful confirmation.

 Contains the persisted user's `id`, `email` and `username`.
*/
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

/*
 Core registration use-case.

 `register(...)` validates inputs, ensures uniqueness of email/username,
 creates a pending registration and sends a confirmation token via the
 configured `ConfirmationEmailSender`.

 `confirm(...)` completes a pending registration when provided with a
 valid token and returns a `ConfirmedUser`.
*/
class RegisterLogic {
  final UserRepository repository;
  final ConfirmationEmailSender emailSender;

  const RegisterLogic({
    required this.repository,
    required this.emailSender,
  });

  /*
   Starts a registration flow.

   Parameters:
   - `email`: user email address.
   - `username`: desired username.
   - `password`: plaintext password (will be hashed by repository).
   - `country`: ISO country code.
   - `language`: preferred language code.
   - `acceptedDisclosure`: whether the user accepted required disclosures.

   Returns:
   - A `RegisterSession` describing the pending registration and token
     expiry.

   Throws:
   - `RegisterLogicException` when validation fails or the identity is
     already registered/pending.
  */
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

  /*
   Confirms a pending registration using the provided token.

   Parameters:
   - `token`: confirmation token previously sent to the user's email.

   Returns:
   - `ConfirmedUser` for the persisted user on success.

   Throws:
   - `RegisterLogicException` with `code: 'invalid_token'` when the token
     is empty, invalid or expired.
  */
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
