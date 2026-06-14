/// @file
/// @brief

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_helpers.dart';
import '../../domain/authentication/register_logic.dart';
import '../../shared/exception_service/exception_handler.dart';
import 'package:pokegrading_logging/pokegrading_logging.dart';
import '../http_helpers.dart';

Router buildAuthRoutes(RegisterLogic registerLogic) {
  final router = Router();

  router.post('/register', (Request request) async {
    final payload = await readJson(request);
    final email = (payload['email'] ?? '').toString();
    final username = (payload['username'] ?? '').toString();
    final password = (payload['password'] ?? '').toString();
    final country = (payload['country'] ?? '').toString();
    final language = (payload['language'] ?? '').toString();
    final acceptedDisclosure = payload['acceptedDisclosure'] == true;

    final requestContext = httpLogContext(request: request, body: payload);

    try {
      final user = await registerLogic.register(
        email: email,
        username: username,
        password: password,
        country: country,
        language: language,
        acceptedDisclosure: acceptedDisclosure,
      );

      AppLogger.audit(
        'PokéGrading.Routes.Register',
        AuditEventTypes.userRegister,
        result: 'success',
        context: {
          ...requestContext,
          'actor_id': user.id,
          'email': user.email,
          'username': user.username,
        },
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
    } on LogicException catch (error) {
      AppLogger.audit(
        'PokéGrading.Routes.Register',
        AuditEventTypes.userRegister,
        result: 'failure',
        context: {
          ...requestContext,
          'error_code': error.code,
          'error_message': error.message,
        },
      );
      return jsonResponse(
        registerStatusCodeFor(error.code),
        {
          'status': 'error',
          'error': error.code,
          'message': error.message,
        },
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Routes.Register',
        'Registration failed',
        context: requestContext,
        error: error,
        stackTrace: stack,
      );
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
