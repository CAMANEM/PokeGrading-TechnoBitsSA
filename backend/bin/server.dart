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

import '../lib/features/auth/application/auth_service.dart';
import '../lib/features/auth/infrastructure/memory_auth_repository.dart';
import '../lib/features/auth/infrastructure/mock_confirmation_email_sender.dart';
import '../lib/features/auth/infrastructure/smtp_confirmation_email_sender.dart';
import '../lib/features/auth/infrastructure/resend_confirmation_email_sender.dart';
import '../lib/features/auth/presentation/auth_router.dart';
<<<<<<< HEAD
import '../lib/features/catalog/application/catalog_service.dart';
import '../lib/features/catalog/infrastructure/mock_catalog_repository.dart';
import '../lib/features/catalog/presentation/catalog_router.dart';
=======
>>>>>>> feature/RegisterUser
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
  final router = _buildRouter(env, config, log);

  // 4. Build the middleware pipeline
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // Log HTTP requests
<<<<<<< HEAD
      .addMiddleware(
        corsHeaders(
          // Ensure our client-sent headers are accepted in preflight
          headers: {
            'Access-Control-Allow-Headers':
                'Origin, Content-Type, Accept, X-Correlation-ID',
              'Access-Control-Expose-Headers': 'X-Correlation-ID',
          },
        ),
      ) // Enable CORS for Flutter Web
=======
      .addMiddleware(corsHeaders()) // Enable CORS for Flutter Web
>>>>>>> feature/RegisterUser
      .addMiddleware(correlationMiddleware()) // Inject correlation_id
      .addHandler(router.call);

  // 5. Start the HTTP server
  final server = await shelf_io.serve(
    handler,
    config.host,
    config.port,
  );
  server.autoCompress = true;

  final browserHost = _browserHostFor(config.host, server.address.host);

  log.info('✅ Server listening on http://$browserHost:${server.port}');
  log.info('   Health check: http://$browserHost:${server.port}/health');

  // 6. Handle clean shutdown signals (SIGINT, SIGTERM)
  _registerShutdownHandlers(server, log);
}

/// Builds and returns the main router with all registered routes.
Router _buildRouter(DotEnv env, AppConfig config, Logger log) {
  final router = Router();
  final authRepository = MemoryAuthRepository();
  final emailSender = _buildEmailSender(env, config, log);
  final authService = AuthService(
    repository: authRepository,
    emailSender: emailSender,
  );
  final authRouter = buildAuthRouter(authService);
<<<<<<< HEAD
  final catalogRepository = MockCatalogRepository();
  final catalogService = CatalogService(repository: catalogRepository);
  final catalogRouter = buildCatalogRouter(catalogService);
=======
>>>>>>> feature/RegisterUser

  // --- System Routes ---
  router.get('/', _handleRoot);
  router.get('/health', (Request req) => _handleHealth(req, config));

  // --- Feature Routes ---
  router.mount('/api/v1/auth/', authRouter.call);
<<<<<<< HEAD
  router.mount('/api/v1/catalog/', catalogRouter.call);
=======
>>>>>>> feature/RegisterUser
  if (!config.useMockRepositories) {
    log.warning(
      'PostgreSQL auth repository is not available yet; using in-memory auth repository.',
    );
  }

  // --- Fallback 404 ---
  router.all('/<ignored|.*>', _handleNotFound);

  return router;
}

ConfirmationEmailSender _buildEmailSender(DotEnv env, AppConfig config, Logger log) {
  final resendKey = env['RESEND_API_KEY'] ?? '';
  final resendFrom = env['RESEND_FROM_EMAIL'] ?? config.email.fromEmail;
  final resendFromName = env['RESEND_FROM_NAME'] ?? config.email.fromName;

  if (resendKey.isNotEmpty) {
    log.info('Resend API key found. Using Resend for confirmation emails.');
    return ResendConfirmationEmailSender(
      apiKey: resendKey,
      fromEmail: resendFrom,
      fromName: resendFromName,
    );
  }

  if (config.email.isConfigured) {
    log.info('SMTP email delivery enabled for confirmation tokens.');
    return SmtpConfirmationEmailSender(config.email);
  }

  log.warning(
    'SMTP not configured and no Resend API key found. Falling back to mock email sender, so tokens will not actually be delivered.',
  );
  return MockConfirmationEmailSender();
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

/// Returns a browser-safe host name for log output.
///
/// `0.0.0.0` is a bind address, not a URL users can open directly.
String _browserHostFor(String configuredHost, String boundHost) {
  if (configuredHost == '0.0.0.0' || configuredHost == '::') {
    return 'localhost';
  }

  return boundHost;
}
