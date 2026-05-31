/*
 Interface for confirmation email delivery.

 Implementations are responsible for sending the confirmation `token`
 to `email` and may use SMTP, a third-party email API (Resend) or a mock
 that logs the token for development. `expiresAt` is provided for message
 content and auditing.
*/
abstract class ConfirmationEmailSender {
  Future<void> sendToken({
    required String email,
    required String username,
    required String token,
    required DateTime expiresAt,
  });
}
