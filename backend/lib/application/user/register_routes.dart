import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../domain/user/register/register_logic.dart';
import '../http_helpers.dart';

Router buildRegisterRoutes(RegisterLogic registerLogic) {
  final router = Router();

  router.post('/register', (Request request) async {
    final payload = await readJson(request);
    final email = (payload['email'] ?? '').toString();
    final username = (payload['username'] ?? '').toString();
    final password = (payload['password'] ?? '').toString();
    final country = (payload['country'] ?? '').toString();
    final language = (payload['language'] ?? '').toString();
    final acceptedDisclosure = payload['acceptedDisclosure'] == true;

    try {
      final session = await registerLogic.register(
        email: email,
        username: username,
        password: password,
        country: country,
        language: language,
        acceptedDisclosure: acceptedDisclosure,
      );

      return jsonResponse(
        201,
        {
          'status': 'pending_confirmation',
          'message': 'Confirmation token sent to the provided email address.',
          'email': session.email,
          'username': session.username,
          'expires_at': session.expiresAt.toIso8601String(),
        },
      );
    } on RegisterLogicException catch (error) {
      return jsonResponse(
        registerStatusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error) {
      return jsonResponse(
        502,
        {
          'status': 'error',
          'error': 'email_delivery_failed',
          'message': error.toString(),
        },
      );
    }
  });

  router.post('/confirm', (Request request) async {
    final payload = await readJson(request);
    final token = (payload['token'] ?? '').toString();

    try {
      final user = await registerLogic.confirm(token: token);
      return jsonResponse(
        200,
        {
          'status': 'active',
          'message': 'Account confirmed successfully.',
          'user': {
            'id': user.id,
            'email': user.email,
            'username': user.username,
          },
        },
      );
    } on RegisterLogicException catch (error) {
      return jsonResponse(
        registerStatusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error) {
      return jsonResponse(
        502,
        {
          'status': 'error',
          'error': 'confirmation_failed',
          'message': error.toString(),
        },
      );
    }
  });

  return router;
}
