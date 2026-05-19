enum UserRegistrationStatus {
  pendingConfirmation,
  active,
}

enum UserRole {
  submitter,
  reviewer,
  admin,
  b2bServiceAccount
}

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