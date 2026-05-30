import 'package:logging/logging.dart';

import 'confirmation_email_sender.dart';

class MockConfirmationEmailSender implements ConfirmationEmailSender {
  final Logger _log = Logger('PokéGrading.Auth.MockEmailSender');

  @override
  Future<void> sendToken({
    required String email,
    required String username,
    required String token,
    required DateTime expiresAt,
  }) async {
    _log.warning(
      'SMTP is not configured. Confirmation token NOT sent to $email '
      'for username=$username token=$token expiresAt=${expiresAt.toUtc().toIso8601String()}',
    );
  }
}
