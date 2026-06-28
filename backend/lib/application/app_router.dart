/*
  Application router and dependency wiring.

  This module constructs the root `Router` instance for the backend, mounts
  sub-routers for versioned API groups and performs dependency wiring.
*/
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/config/app_config.dart';
import 'routes/catalog_routes.dart';
import 'routes/auth_routes.dart';
import 'routes/evaluation_routes.dart';
import 'routes/observability_routes.dart';
import 'routes/b2b_routes.dart';
import 'b2b_dependencies.dart';
import '../domain/authentication/register_logic.dart';
import '../domain/catalog/create_card_logic.dart';
import '../domain/catalog/search_card_logic.dart';
import '../domain/scoring/evaluation_logic.dart';
import '../domain/b2b/consult/consult_logic.dart';
import '../domain/scoring/grading/baseline_registry.dart';
import '../persistence/b2b_data_provider/api_key_repository.dart';
import '../persistence/b2b_data_provider/b2b_audit_repository.dart';
import '../persistence/b2b_data_provider/idempotency_repository.dart';
import '../persistence/b2b_data_provider/rate_limit_repository.dart';
import '../persistence/b2b_data_provider/reference_catalog_repository.dart';
import '../persistence/user_data_provider/auth_repository.dart';
import '../persistence/card_data_provider/catalog_repository.dart';
import '../persistence/card_data_provider/search_trace_repository.dart';
import '../persistence/card_data_provider/evaluation_repository.dart';
import '../persistence/card_data_provider/calibrated_baseline_repository.dart';

/*
  Builds and returns the main router with all registered routes and DI wiring.

  Parameters:
  - `env`: DotEnv with environment variables.
  - `config`: application configuration.
  - `log`: logger used for startup messages.
  - `userRepository`: repository for user persistence.
  - `catalogRepository`: repository for catalog persistence.
  - `evaluationRepository`: repository for evaluation requests.
  - `searchTraceRepository`: repository for search traces (optional).
  - `b2bDependencies`: B2B API repositories (optional).

  Returns:
  - A `Router` with mounted routes: root, health, auth, catalog, evaluations, and b2b.
*/
Router buildAppRouter(
  DotEnv env,
  AppConfig config,
  Logger log,
  UserRepository userRepository,
  CatalogRepository catalogRepository,
  EvaluationRepository evaluationRepository,
  SearchTraceRepository? searchTraceRepository,
  B2bDependencies? b2bDependencies, {
  BaselineRegistry? baselineRegistry,
  CalibratedBaselineRepository? baselineRepository,
}) {
  final router = Router();

  final registerLogic = RegisterLogic(
    repository: userRepository,
  );
  final registerRouter = buildAuthRoutes(registerLogic);

  final createCardLogic = CreateCardLogic(repository: catalogRepository);
  final searchCardLogic = SearchCardLogic(
    repository: catalogRepository,
    traceRepository: searchTraceRepository,
  );
  final catalogRouter = buildCatalogRoutes(
    createCardLogic,
    searchCardLogic,
    searchTraceRepository: searchTraceRepository,
  );

  final evaluationLogic = EvaluationLogic(repository: evaluationRepository);
  final evaluationRouter = buildEvaluationRoutes(
    evaluationLogic,
    baselineRegistry: baselineRegistry,
    baselineRepository: baselineRepository,
  );

  if (b2bDependencies != null) {
    final consultLogic = ConsultLogic(
      catalogRepository: b2bDependencies.referenceCatalogRepository
          as ReferenceCatalogRepository,
      maxCardsPerRequest: config.b2b.maxCardsPerRequest,
    );
    final b2bRouter = buildB2bRoutes(
      consultLogic: consultLogic,
      apiKeyRepository: b2bDependencies.apiKeyRepository as ApiKeyRepository,
      auditRepository: b2bDependencies.auditRepository as B2bAuditRepository,
      idempotencyRepository:
          b2bDependencies.idempotencyRepository as IdempotencyRepository,
      rateLimitRepository:
          b2bDependencies.rateLimitRepository as RateLimitRepository,
      b2bConfig: config.b2b,
      apiVersion: config.version,
    );
    router.mount('/api/v1/b2b/', b2bRouter.call);
  }

  router.get('/', _handleRoot);
  router.get('/health', (Request req) => _handleHealth(req, config));
  router.get('/docs', _handleDocs);
  router.get('/openapi.json', _handleOpenApi);

  router.mount('/api/v1/auth/', registerRouter.call);
  router.mount('/api/v1/catalog/', catalogRouter.call);
  router.mount('/api/v1/scoring/', evaluationRouter.call);
  router.mount('/api/v1/observability/', buildObservabilityRoutes().call);

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

Response _handleDocs(Request request) {
  final file = File('web/docs.html');

  if (!file.existsSync()) {
    return Response.notFound('docs.html not found');
  }

  return Response.ok(
    file.readAsStringSync(),
    headers: {
      'content-type': 'text/html; charset=utf-8',
    },
  );
}

Response _handleOpenApi(Request request) {
  final file = File('web/openapi.json');

  if (!file.existsSync()) {
    return Response.notFound('openapi.json not found');
  }

  return Response.ok(
    file.readAsStringSync(),
    headers: {
      'content-type': 'application/json; charset=utf-8',
    },
  );
}
