import 'user.dart';

/*
 Abstract repository contract for user persistence and registration flows.

 Implementations are expected to handle uniqueness checks and directly create
 user accounts without a confirmation token flow.
*/
abstract class UserRepository {
  Future<bool> emailExists(String email);
  Future<bool> usernameExists(String username);
  Future<User> createUser({
    required String email,
    required String username,
    required String password,
    required String country,
    required String language,
    required bool acceptedDisclosure,
  });
}
