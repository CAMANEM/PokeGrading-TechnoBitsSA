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
import 'auth_models.dart';
import 'auth_validators.dart';

import '../../persistence/user_data_provider/auth_repository.dart';
import '../../shared/exception_service/exception_handler.dart';

Never _throwRegisterError(String code, String err) {
  throw LogicException(
    feature: 'register-user',
    code: code,
    message: err,
  );
}

/*
 Value object returned after successful registration.
*/

/// @brief ConfirmedUser
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

/// @brief RegisterLogic
class RegisterLogic {
  final UserRepository repository;
  static const String emailExistsMessage = 'Emaail is already registered';
  static const String usernameExistsMessage = 'Username is already registered';

  const RegisterLogic({required this.repository});

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
      _throwRegisterError('invalid_email', emailError);
    }

    final usernameError = UserValidators.validateUsername(username);
    if (usernameError != null) {
      _throwRegisterError('invalid_username', usernameError);
    }

    final passwordError = UserValidators.validatePassword(password);
    if (passwordError != null) {
      _throwRegisterError('invalid_password', passwordError);
    }

    final countryError = UserValidators.validateCountry(country);
    if (countryError != null) {
      _throwRegisterError('invalid_country', countryError);
    }

    final languageError = UserValidators.validateLanguage(language);
    if (languageError != null) {
      _throwRegisterError('invalid_language', languageError);
    }

    final disclosureError =
        UserValidators.validateDisclosure(acceptedDisclosure);
    if (disclosureError != null) {
      _throwRegisterError('disclosure_required', disclosureError);
    }

    final blockedDomainError = UserValidators.validateEmailDomain(email);
    if (blockedDomainError != null) {
      _throwRegisterError('blocked_email_domain', blockedDomainError);
    }

    if (await repository.emailExists(email)) {
      _throwRegisterError('email_exists', emailExistsMessage);
    }

    if (await repository.usernameExists(username)) {
      _throwRegisterError('username_exists', usernameExistsMessage);
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
