/*
 Application router and dependency wiring.

 This module constructs the root `Router` instance for the backend, mounts
 sub-routers for versioned API groups and performs lightweight dependency
 wiring for demo/mock implementations. Production wiring (SQL repositories,
 real SMTP) can replace the in-memory and mock providers used here.
*/
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/config/app_config.dart';
import '../domain/user/register/register_logic.dart';
import '../domain/user/user_repository.dart';
import '../domain/submitter_catalog/create_card/create_card_logic.dart';
import '../domain/submitter_catalog/submit_evaluation/image_quality_service.dart';
import '../domain/submitter_catalog/submit_evaluation/polyglot_detection.dart';
import '../domain/submitter_catalog/submit_evaluation/evaluation_logic.dart';
import '../persistence/submitter_catalog/mock_catalog_repository.dart';
import '../persistence/submitter_catalog/mock_evaluation_repository.dart';
import 'submitter_catalog/create_card_routes.dart';
import 'user/register_routes.dart';
import 'submitter_catalog/submit_evaluation_routes.dart';

/*
 Builds and returns the main router with all registered routes and DI wiring.

 Parameters:
 - `env`: DotEnv with environment variables (used to detect Resend API key).
 - `config`: application configuration (controls mock vs real repos, versioning).
 - `log`: logger used for startup messages.

 Returns:
 - A `Router` with mounted routes: root, health, auth and catalog sub-routers.
*/
Router buildAppRouter(
    DotEnv env, AppConfig config, Logger log, UserRepository userRepository) {
  final router = Router();

  final registerLogic = RegisterLogic(
    repository: userRepository,
  );
  final registerRouter = buildRegisterRoutes(registerLogic);

  final catalogRepository = MockCatalogRepository();
  final createCardLogic = CreateCardLogic(repository: catalogRepository);
  final createCardRouter = buildCreateCardRoutes(createCardLogic);

  final evaluationRepository = MockEvaluationRepository();
  final imageQualityService = ImageQualityService();
  final polyglotDetector = PolyglotDetector();
  final evaluationLogic = SubmitEvaluationLogic(
      repository: evaluationRepository,
      imageQualityService: imageQualityService,
      polyglotDetector: polyglotDetector);
  final evaluationRouter = buildSubmitEvaluationRoutes(evaluationLogic);

  router.get('/', _handleRoot);
  router.get('/health', (Request req) => _handleHealth(req, config));

  router.mount('/api/v1/auth/', registerRouter.call);
  router.mount('/api/v1/catalog/', createCardRouter.call);
  router.mount('/api/v1/', evaluationRouter.call);

  if (!config.useMockRepositories) {
    log.warning(
      'PostgreSQL user repository is not available yet; using in-memory user repository.',
    );
  }

  router.all('/<ignored|.*>', _handleNotFound);

  return router;
}

Response _handleRoot(Request request) {
  return Response.ok(
    '{"message":"Welcome to PokéGrading API!","docs":"/health"}',
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Response _handleHealth(Request request, AppConfig config) {
  final correlationId = request.context['correlation_id'] ?? 'none';
  final body = '''
{
  "status": "ok",
  "service": "pokegrading-backend",
  "version": "${config.version}",
  "environment": "${config.environment}",
  "correlation_id": "$correlationId",
  "timestamp": "${DateTime.now().toUtc().toIso8601String()}"
}''';

  return Response.ok(
    body,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Response _handleNotFound(Request request) {
  return Response.notFound(
    '{"error":"Route not found","path":"${request.url.path}"}',
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
