abstract class ConfirmationEmailSender {
  Future<void> sendToken({
    required String email,
    required String username,
    required String token,
    required DateTime expiresAt,
  });
}
