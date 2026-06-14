/// @file
/// @brief

// PokéGrading Backend — Entry Point
// HTTP Server using Dart + Shelf
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../lib/application/app_router.dart';
import '../lib/application/b2b_dependencies.dart';
import '../lib/core/config/app_config.dart';
import '../lib/core/logging/app_logger.dart';
import '../lib/core/middleware/correlation_middleware.dart';
import '../lib/core/security/api_key_hasher.dart';
import '../lib/persistence/user_data_provider/auth_repository.dart';
import '../lib/persistence/card_data_provider/catalog_repository.dart';
import '../lib/persistence/card_data_provider/evaluation_repository.dart';
import '../lib/persistence/card_data_provider/search_trace_repository.dart';
import '../lib/persistence/mocks/memory_user_repository.dart';
import '../lib/persistence/user_data_provider/postgres_user_repository.dart';
import '../lib/persistence/mocks/mock_catalog_repository.dart';
import '../lib/persistence/card_data_provider/postgres_catalog_repository.dart';
import '../lib/persistence/mocks/mock_evaluation_repository.dart';
import '../lib/persistence/card_data_provider/postgres_evaluation_repository.dart';
import '../lib/persistence/card_data_provider/noop_search_trace_repository.dart';
import '../lib/persistence/image_provider/image_storage_repository.dart';
import '../lib/persistence/image_provider/mongo_image_repository.dart';
import '../lib/persistence/mocks/mock_api_key_repository.dart';
import '../lib/persistence/mocks/mock_b2b_audit_repository.dart';
import '../lib/persistence/mocks/mock_idempotency_repository.dart';
import '../lib/persistence/mocks/mock_rate_limit_repository.dart';
import '../lib/persistence/mocks/mock_reference_catalog_repository.dart';
import '../lib/persistence/b2b_data_provider/postgres_api_key_repository.dart';
import '../lib/persistence/b2b_data_provider/postgres_b2b_audit_repository.dart';
import '../lib/persistence/b2b_data_provider/postgres_idempotency_repository.dart';
import '../lib/persistence/b2b_data_provider/postgres_rate_limit_repository.dart';
import '../lib/persistence/b2b_data_provider/postgres_reference_catalog_repository.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true);
  if (File('.env').existsSync()) {
    env.load();
  } else if (File('../.env').existsSync()) {
    env.load(['../.env']);
  } else {
    env.load();
  }
  final config = AppConfig.fromEnv(env);

  AppLogger.init(level: config.logLevel, config: config.logging);
  final log = Logger('PokéGrading.Server');

  log.info('🎴 Starting PokéGrading Backend v${config.version}');
  log.info('   Environment: ${config.environment}');
  log.info('   Host       : ${config.host}:${config.port}');

  late final UserRepository userRepository;
  PostgresUserRepository? postgresUserRepository;

  late final CatalogRepository catalogRepository;
  PostgresCatalogRepository? postgresCatalogRepository;

  late final EvaluationRepository evaluationRepository;
  PostgresEvaluationRepository? postgresEvaluationRepository;

  late final SearchTraceRepository searchTraceRepository;

  late final B2bDependencies b2bDependencies;
  PostgresApiKeyRepository? postgresApiKeyRepository;
  PostgresReferenceCatalogRepository? postgresReferenceCatalogRepository;
  PostgresB2bAuditRepository? postgresB2bAuditRepository;
  PostgresIdempotencyRepository? postgresIdempotencyRepository;
  PostgresRateLimitRepository? postgresRateLimitRepository;

  ImageStorageRepository? mongoImageRepository;

  final apiKeyHasher = ApiKeyHasher(pepper: config.b2b.apiKeyPepper);

  if (config.useMockRepositories) {
    userRepository = MemoryUserRepository();
    catalogRepository = MockCatalogRepository();
    evaluationRepository = MockEvaluationRepository();
    searchTraceRepository = const NoOpSearchTraceRepository();
    b2bDependencies = B2bDependencies(
      apiKeyRepository: MockApiKeyRepository(
        devApiKey: config.b2b.devApiKey,
      ),
      referenceCatalogRepository: MockReferenceCatalogRepository(),
      auditRepository: MockB2bAuditRepository(),
      idempotencyRepository: MockIdempotencyRepository(),
      rateLimitRepository: MockRateLimitRepository(),
    );
    log.info('Using all in-memory/mock repositories.');
  } else {
    mongoImageRepository = await MongoImageRepository.connect(config.mongo);
    postgresUserRepository =
        await PostgresUserRepository.connect(config.database);
    postgresCatalogRepository = await PostgresCatalogRepository.connect(
      config.database,
      mongoImageRepository,
    );
    postgresEvaluationRepository = await PostgresEvaluationRepository.connect(
      config.database,
      mongoImageRepository,
    );

    userRepository = postgresUserRepository;
    catalogRepository = postgresCatalogRepository;
    evaluationRepository = postgresEvaluationRepository;
    searchTraceRepository = const NoOpSearchTraceRepository();

    postgresApiKeyRepository = await PostgresApiKeyRepository.connect(
      config.database,
      apiKeyHasher,
    );
    postgresReferenceCatalogRepository =
        await PostgresReferenceCatalogRepository.connect(config.database);
    postgresB2bAuditRepository =
        await PostgresB2bAuditRepository.connect(config.database);
    postgresIdempotencyRepository =
        await PostgresIdempotencyRepository.connect(config.database);
    postgresRateLimitRepository =
        await PostgresRateLimitRepository.connect(config.database);

    b2bDependencies = B2bDependencies(
      apiKeyRepository: postgresApiKeyRepository,
      referenceCatalogRepository: postgresReferenceCatalogRepository,
      auditRepository: postgresB2bAuditRepository,
      idempotencyRepository: postgresIdempotencyRepository,
      rateLimitRepository: postgresRateLimitRepository,
    );

    log.info('Using PostgreSQL + MongoDB repositories.');
  }

  final router = buildAppRouter(
    env,
    config,
    log,
    userRepository,
    catalogRepository,
    evaluationRepository,
    searchTraceRepository,
    b2bDependencies,
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        corsHeaders(
          headers: {
            'Access-Control-Allow-Headers':
                'Origin, Content-Type, Accept, Authorization, X-Correlation-ID, X-Request-Id, If-None-Match',
            'Access-Control-Expose-Headers':
                'X-Correlation-ID, ETag, Last-Modified, Retry-After',
          },
        ),
      )
      .addMiddleware(correlationMiddleware())
      .addHandler(router.call);

  final server = await shelf_io.serve(
    handler,
    config.host,
    config.port,
  );
  server.autoCompress = true;

  final browserHost = _browserHostFor(config.host, server.address.host);

  log.info('✅ Server listening on http://$browserHost:${server.port}');
  log.info('   Health check: http://$browserHost:${server.port}/health');

  _registerShutdownHandlers(
    server,
    log,
    postgresUserRepository,
    postgresCatalogRepository,
    postgresEvaluationRepository,
    mongoImageRepository,
    postgresApiKeyRepository,
    postgresReferenceCatalogRepository,
    postgresB2bAuditRepository,
    postgresIdempotencyRepository,
    postgresRateLimitRepository,
  );
}

void _registerShutdownHandlers(
  HttpServer server,
  Logger log,
  PostgresUserRepository? postgresUserRepo,
  PostgresCatalogRepository? postgresCatalogRepo,
  PostgresEvaluationRepository? postgresEvalRepo,
  ImageStorageRepository? mongoImageRepo,
  PostgresApiKeyRepository? postgresApiKeyRepo,
  PostgresReferenceCatalogRepository? postgresReferenceCatalogRepo,
  PostgresB2bAuditRepository? postgresB2bAuditRepo,
  PostgresIdempotencyRepository? postgresIdempotencyRepo,
  PostgresRateLimitRepository? postgresRateLimitRepo,
) {
  ProcessSignal.sigint.watch().listen((_) async {
    log.info('🛑 SIGINT signal received - Shutting down server...');
    await server.close(force: false);
    if (postgresUserRepo != null) await postgresUserRepo.close();
    if (postgresCatalogRepo != null) await postgresCatalogRepo.close();
    if (postgresEvalRepo != null) await postgresEvalRepo.close();
    if (postgresApiKeyRepo != null) await postgresApiKeyRepo.close();
    if (postgresReferenceCatalogRepo != null) {
      await postgresReferenceCatalogRepo.close();
    }
    if (postgresB2bAuditRepo != null) await postgresB2bAuditRepo.close();
    if (postgresIdempotencyRepo != null) await postgresIdempotencyRepo.close();
    if (postgresRateLimitRepo != null) await postgresRateLimitRepo.close();
    if (mongoImageRepo != null) await mongoImageRepo.close();
    log.info('   All database connections closed.');
    log.info('   Server shut down successfully.');
    exit(0);
  });
}

String _browserHostFor(String configuredHost, String boundHost) {
  if (configuredHost == '0.0.0.0' || configuredHost == '::') {
    return 'localhost';
  }

  return boundHost;
}
