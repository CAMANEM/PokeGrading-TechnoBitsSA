/*
 Domain entity representing an application user.

 This file declares the `User` value object and related enums used across
 the backend. `User` instances are intended to be immutable; use `copyWith`
 to create modified copies. Passwords stored here are expected to be hashed
 by the persistence layer.
*/

/*
 Represents the registration lifecycle of a user.
 - `active`: the user is active and allowed to log in.
*/

/// @brief UserRegistrationStatus
enum UserRegistrationStatus {
  active,
}

/*
 Represents the role assigned to a user. Roles affect authorization checks
 and permitted actions within the system.
*/

/// @brief UserRole
enum UserRole { submitter, reviewer, admin, b2bServiceAccount }

/*
 Immutable value object that models a user account.

 Fields of note:
 - `password`: hashed password (do not log or expose this field).
 - `acceptedDisclosure`: indicates whether the user accepted required terms.
 - `role` and `status` control authorization and registration lifecycle.
*/

/// @brief User
class User {
  final String id;
  final String email;
  final String username;
  final String password;

  final String country;
  final String language;
  final bool acceptedDisclosure;

  final UserRole role;
  final UserRegistrationStatus status;

  final DateTime createdAt;
  final DateTime lastLoginAt;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.password,
    required this.country,
    required this.language,
    required this.acceptedDisclosure,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.lastLoginAt,
  });

  /*
   Returns a copy of the user with the provided fields replaced. Useful for
   updating a subset of fields while keeping immutability.
  */
  User copyWith({
    String? id,
    String? email,
    String? username,
    String? password,
    String? country,
    String? language,
    bool? acceptedDisclosure,
    UserRole? role,
    UserRegistrationStatus? status,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      password: password ?? this.password,
      country: country ?? this.country,
      language: language ?? this.language,
      acceptedDisclosure: acceptedDisclosure ?? this.acceptedDisclosure,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
