/*
 Domain logic for user registration.

 This module implements the `RegisterLogic` use-case which performs input
 validation, coordinates with the `UserRepository` to create active user
 accounts directly, without email confirmation.

 Public API:
 - `RegisterLogic.register(...)` : validates inputs and creates an active user
 - `ConfirmedUser` : DTO returned after successful registration

 Errors are represented by `RegisterLogicException` using short `code`
 identifiers suitable for mapping to HTTP response codes and bodies.
*/
import '../user.dart';
import '../user_repository.dart';
import '../user_validators.dart';

/*
 Represents an error raised by `RegisterLogic`.

 `code` is a short machine-friendly identifier (e.g. `invalid_email`,
 `email_exists`) and `message` provides a human-readable explanation for
 logs and client error messages.
*/
class RegisterLogicException implements Exception {
  final String code;
  final String message;

  const RegisterLogicException({required this.code, required this.message});

  @override
  String toString() => 'RegisterLogicException($code): $message';
}

/*
 Value object returned after successful registration.
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
 and creates an active user in the repository.
*/
class RegisterLogic {
  final UserRepository repository;

  const RegisterLogic({
    required this.repository,
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
   - A `ConfirmedUser` representing the newly created user.

   Throws:
   - `RegisterLogicException` when validation fails or the identity is
     already registered.
  */
  Future<ConfirmedUser> register({
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

    final disclosureError =
        UserValidators.validateDisclosure(acceptedDisclosure);
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
        message: 'Email is already registered.',
      );
    }

    if (await repository.usernameExists(username)) {
      throw RegisterLogicException(
        code: 'username_exists',
        message: 'Username is already registered.',
      );
    }

    final user = await repository.createUser(
      email: email,
      username: username,
      password: password,
      country: country,
      language: language,
      acceptedDisclosure: acceptedDisclosure,
    );

    return ConfirmedUser.fromUser(user);
  }
}
