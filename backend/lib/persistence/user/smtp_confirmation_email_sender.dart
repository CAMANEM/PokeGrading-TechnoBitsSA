/*
 SMTP-based implementation of `ConfirmationEmailSender`.

 Uses the `mailer` package to deliver both plain-text and HTML emails.
 Configuration is provided via `EmailConfig` and the sender logs a report
 when delivery is attempted.
*/
import 'package:logging/logging.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../../core/config/app_config.dart';
import 'confirmation_email_sender.dart';

class SmtpConfirmationEmailSender implements ConfirmationEmailSender {
  final EmailConfig config;
  final Logger _log = Logger('PokéGrading.Auth.SmtpEmailSender');

  SmtpConfirmationEmailSender(this.config);

  @override
  Future<void> sendToken({
    required String email,
    required String username,
    required String token,
    required DateTime expiresAt,
  }) async {
    final smtpServer = SmtpServer(
      config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      ssl: config.useSsl,
    );

    final message = Message()
      ..from = Address(config.fromEmail, config.fromName)
      ..recipients.add(email)
      ..subject = 'PokéGrading: confirma tu registro'
      ..text = _plainTextBody(username, token, expiresAt)
      ..html = _htmlBody(username, token, expiresAt);

    final sendReport = await send(message, smtpServer);
    _log.info(
      'Confirmation email sent to $email for username=$username report=$sendReport',
    );
  }

  String _plainTextBody(String username, String token, DateTime expiresAt) {
    return '''
Hola $username,

Tu token de confirmación es: $token

Expira el: ${expiresAt.toUtc().toIso8601String()}

Si no solicitaste este registro, puedes ignorar este mensaje.
''';
  }

  String _htmlBody(String username, String token, DateTime expiresAt) {
    return '''
<html>
  <body style="font-family:Arial,sans-serif;line-height:1.6;color:#1a1a2e;">
    <h2>PokéGrading</h2>
    <p>Hola <strong>$username</strong>,</p>
    <p>Tu token de confirmación es:</p>
    <p style="font-size:24px;font-weight:bold;letter-spacing:4px;">$token</p>
    <p>Expira el: ${expiresAt.toUtc().toIso8601String()}</p>
    <p>Si no solicitaste este registro, puedes ignorar este mensaje.</p>
  </body>
</html>
''';
  }
}
