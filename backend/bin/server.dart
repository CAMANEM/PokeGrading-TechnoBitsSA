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
import '../lib/persistence/user/memory_user_repository.dart';
import '../lib/persistence/user/postgres_user_repository.dart';

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
  PostgresUserRepository? postgresRepository;

  if (config.useMockRepositories) {
    userRepository = MemoryUserRepository();
    log.info(
        'Using in-memory user repository because USE_MOCK_REPOSITORIES=true.');
  } else {
    postgresRepository = await PostgresUserRepository.connect(config.database);
    userRepository = postgresRepository;
    log.info('Using PostgreSQL user repository.');
  }

  final router = buildAppRouter(env, config, log, userRepository);

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

  _registerShutdownHandlers(server, log, postgresRepository);
}

void _registerShutdownHandlers(
    HttpServer server, Logger log, PostgresUserRepository? postgresRepository) {
  ProcessSignal.sigint.watch().listen((_) async {
    log.info('🛑 SIGINT signal received - Shutting down server...');
    await server.close(force: false);
    if (postgresRepository != null) {
      await postgresRepository.close();
      log.info('   PostgreSQL connection closed.');
    }
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
