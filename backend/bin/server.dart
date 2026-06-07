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
import '../lib/core/config/app_config.dart';
import '../lib/core/logging/app_logger.dart';
import '../lib/core/middleware/correlation_middleware.dart';
import '../lib/domain/user/user_repository.dart';
import '../lib/domain/submitter_catalog/catalog_repository.dart';
import '../lib/domain/submitter_catalog/submit_evaluation/evaluation_repository.dart';
import '../lib/domain/submitter_catalog/search_card/search_trace_repository.dart';
import '../lib/persistence/user/memory_user_repository.dart';
import '../lib/persistence/user/postgres_user_repository.dart';
import '../lib/persistence/submitter_catalog/mock_catalog_repository.dart';
import '../lib/persistence/submitter_catalog/postgres_catalog_repository.dart';
import '../lib/persistence/submitter_catalog/mock_evaluation_repository.dart';
import '../lib/persistence/submitter_catalog/postgres_evaluation_repository.dart';
import '../lib/persistence/submitter_catalog/mock_search_trace_repository.dart';
import '../lib/persistence/submitter_catalog/postgres_search_trace_repository.dart';

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

  AppLogger.init(level: config.logLevel);
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

  late final SearchTraceRepository? searchTraceRepository;
  PostgresSearchTraceRepository? postgresSearchTraceRepository;

  if (config.useMockRepositories) {
    userRepository = MemoryUserRepository();
    catalogRepository = MockCatalogRepository();
    evaluationRepository = MockEvaluationRepository();
    searchTraceRepository = MockSearchTraceRepository();
    log.info('Using all in-memory/mock repositories.');
  } else {
    postgresUserRepository =
        await PostgresUserRepository.connect(config.database);
    postgresCatalogRepository =
        await PostgresCatalogRepository.connect(config.database);
    postgresEvaluationRepository =
        await PostgresEvaluationRepository.connect(config.database);
    postgresSearchTraceRepository =
        await PostgresSearchTraceRepository.connect(config.database);

    userRepository = postgresUserRepository;
    catalogRepository = postgresCatalogRepository;
    evaluationRepository = postgresEvaluationRepository;
    searchTraceRepository = postgresSearchTraceRepository;
    log.info('Using PostgreSQL repositories.');
  }

  final router = buildAppRouter(
    env,
    config,
    log,
    userRepository,
    catalogRepository,
    evaluationRepository,
    searchTraceRepository,
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        corsHeaders(
          headers: {
            'Access-Control-Allow-Headers':
                'Origin, Content-Type, Accept, X-Correlation-ID',
            'Access-Control-Expose-Headers': 'X-Correlation-ID',
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
    postgresSearchTraceRepository,
  );
}

void _registerShutdownHandlers(
    HttpServer server,
    Logger log,
    PostgresUserRepository? postgresUserRepo,
    PostgresCatalogRepository? postgresCatalogRepo,
    PostgresEvaluationRepository? postgresEvalRepo,
    PostgresSearchTraceRepository? postgresTraceRepo) {
  ProcessSignal.sigint.watch().listen((_) async {
    log.info('🛑 SIGINT signal received - Shutting down server...');
    await server.close(force: false);
    if (postgresUserRepo != null) await postgresUserRepo.close();
    if (postgresCatalogRepo != null) await postgresCatalogRepo.close();
    if (postgresEvalRepo != null) await postgresEvalRepo.close();
    if (postgresTraceRepo != null) await postgresTraceRepo.close();
    log.info('   All PostgreSQL connections closed.');
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
