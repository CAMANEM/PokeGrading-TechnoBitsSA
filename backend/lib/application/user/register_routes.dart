/// @file
/// @brief

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../domain/user/register/register_logic.dart';
import '../http_helpers.dart';

final _log = Logger('PokéGrading.Routes.Register');

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
      final user = await registerLogic.register(
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
          'status': 'active',
          'message': 'Usuario registrado correctamente.',
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
    } catch (error, stack) {
      _log.severe('Registration failed: $error\n$stack');
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

  return router;
}
