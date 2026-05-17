// ============================================================
// PokéGrading Backend — Entry Point
// HTTP Server using Dart + Shelf
// ============================================================
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import '../lib/core/config/app_config.dart';
import '../lib/core/logging/app_logger.dart';
import '../lib/core/middleware/correlation_middleware.dart';

/// Entry point of the PokéGrading Backend server.
/// Initializes configuration, logging, middlewares, and base routes.
void main() async {
  // 1. Load environment variables from .env (also searching in parent directory)
  final env = DotEnv(includePlatformEnvironment: true);
  if (File('.env').existsSync()) {
    env.load();
  } else if (File('../.env').existsSync()) {
    env.load(['../.env']);
  } else {
    env.load(); // Standard fallback attempt
  }
  final config = AppConfig.fromEnv(env);

  // 2. Initialize logging system
  AppLogger.init(level: config.logLevel);
  final log = Logger('PokéGrading.Server');

  log.info('🎴 Starting PokéGrading Backend v${config.version}');
  log.info('   Environment: ${config.environment}');
  log.info('   Host       : ${config.host}:${config.port}');

  // 3. Define the main router with all routes
  final router = _buildRouter(config, log);

  // 4. Build the middleware pipeline
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // Log HTTP requests
      .addMiddleware(corsHeaders()) // Enable CORS for Flutter Web
      .addMiddleware(correlationMiddleware()) // Inject correlation_id
      .addHandler(router.call);

  // 5. Start the HTTP server
  final server = await shelf_io.serve(
    handler,
    config.host,
    config.port,
  );
  server.autoCompress = true;

  log.info('✅ Server listening on http://${server.address.host}:${server.port}');
  log.info('   Health check: http://${server.address.host}:${server.port}/health');

  // 6. Handle clean shutdown signals (SIGINT, SIGTERM)
  _registerShutdownHandlers(server, log);
}

/// Builds and returns the main router with all registered routes.
Router _buildRouter(AppConfig config, Logger log) {
  final router = Router();

  // --- System Routes ---
  router.get('/', _handleRoot);
  router.get('/health', (Request req) => _handleHealth(req, config));

  // --- Feature Routes (Sprint 1 - Stub) ---
  // Real handlers will be implemented in each feature:
  // router.mount('/api/v1/auth/',    authRouter.call);
  // router.mount('/api/v1/catalog/', catalogRouter.call);

  // --- Fallback 404 ---
  router.all('/<ignored|.*>', _handleNotFound);

  return router;
}

/// GET / — API Welcome Message
Response _handleRoot(Request request) {
  return Response.ok(
    '{"message":"Welcome to PokéGrading API!","docs":"/health"}',
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// GET /health — Service Health Check
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

/// Fallback: any undefined route returns 404
Response _handleNotFound(Request request) {
  return Response.notFound(
    '{"error":"Route not found","path":"${request.url.path}"}',
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Registers handlers for clean server shutdown
void _registerShutdownHandlers(HttpServer server, Logger log) {
  ProcessSignal.sigint.watch().listen((_) async {
    log.info('🛑 SIGINT signal received - Shutting down server...');
    await server.close(force: false);
    log.info('   Server shut down successfully.');
    exit(0);
  });
}
