enum UserRegistrationStatus {
  pendingConfirmation,
  active,
}

class User {
  final String id;
  final String email;
  final String username;
  final String password;
  final UserRegistrationStatus status;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.password,
    required this.status,
    required this.createdAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? password,
    UserRegistrationStatus? status,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      password: password ?? this.password,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}