import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

import 'confirmation_email_sender.dart';

/// Sends confirmation tokens using Resend API (https://resend.com).
class ResendConfirmationEmailSender implements ConfirmationEmailSender {
  final String apiKey;
  final String fromEmail;
  final String fromName;
  final Logger _log = Logger('PokéGrading.Auth.ResendEmailSender');

  ResendConfirmationEmailSender({
    required this.apiKey,
    required this.fromEmail,
    required this.fromName,
  });

  @override
  Future<void> sendToken({
    required String email,
    required String username,
    required String token,
    required DateTime expiresAt,
  }) async {
    final uri = Uri.parse('https://api.resend.com/emails');
    final subject = 'PokéGrading: confirma tu registro';
    final html = _htmlBody(username, token, expiresAt);

    final body = {
      'from': '$fromName <$fromEmail>',
      'to': [email],
      'subject': subject,
      'html': html,
    };

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      _log.severe('Resend API error: ${resp.statusCode} ${resp.body}');
      throw Exception(
        'Failed to send confirmation email via Resend: ${resp.statusCode} ${resp.body}',
      );
    }

    _log.info('Confirmation email sent via Resend to $email (status=${resp.statusCode})');
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
