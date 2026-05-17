// ============================================================
// PokéGrading Backend — Entry Point
// Servidor HTTP usando Dart + Shelf
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

/// Entry point del servidor PokéGrading Backend.
/// Inicializa configuración, logging, middlewares y rutas base.
void main() async {
  // 1. Cargar variables de entorno desde .env (si existe)
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final config = AppConfig.fromEnv(env);

  // 2. Inicializar sistema de logging
  AppLogger.init(level: config.logLevel);
  final log = Logger('PokéGrading.Server');

  log.info('🎴 Iniciando PokéGrading Backend v${config.version}');
  log.info('   Entorno  : ${config.environment}');
  log.info('   Host     : ${config.host}:${config.port}');

  // 3. Definir el router principal con todas las rutas
  final router = _buildRouter(config, log);

  // 4. Construir la pipeline de middlewares
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // Log HTTP requests
      .addMiddleware(corsHeaders()) // Habilitar CORS para Flutter Web
      .addMiddleware(correlationMiddleware()) // Inyectar correlation_id
      .addHandler(router.call);

  // 5. Iniciar el servidor HTTP
  final server = await shelf_io.serve(
    handler,
    config.host,
    config.port,
  );
  server.autoCompress = true;

  log.info('✅ Servidor escuchando en http://${server.address.host}:${server.port}');
  log.info('   Health check: http://${server.address.host}:${server.port}/health');

  // 6. Manejar señales de apagado (SIGINT, SIGTERM)
  _registerShutdownHandlers(server, log);
}

/// Construye y devuelve el router principal con todas las rutas registradas.
Router _buildRouter(AppConfig config, Logger log) {
  final router = Router();

  // ─── Rutas del sistema ──────────────────────────────────
  router.get('/', _handleRoot);
  router.get('/health', (Request req) => _handleHealth(req, config));

  // ─── Rutas de Features (Sprint 1 — Stub) ────────────────
  // Los handlers reales se implementarán en cada feature:
  // router.mount('/api/v1/auth/',    authRouter.call);
  // router.mount('/api/v1/catalog/', catalogRouter.call);

  // ─── Fallback 404 ────────────────────────────────────────
  router.all('/<ignored|.*>', _handleNotFound);

  return router;
}

/// GET / — Bienvenida al API
Response _handleRoot(Request request) {
  return Response.ok(
    '{"message":"¡Bienvenido a PokéGrading API!","docs":"/health"}',
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// GET /health — Health check del servicio
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

/// Fallback: cualquier ruta no definida devuelve 404
Response _handleNotFound(Request request) {
  return Response.notFound(
    '{"error":"Ruta no encontrada","path":"${request.url.path}"}',
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Registra handlers para apagado limpio del servidor
void _registerShutdownHandlers(HttpServer server, Logger log) {
  ProcessSignal.sigint.watch().listen((_) async {
    log.info('🛑 Señal SIGINT recibida — Apagando servidor...');
    await server.close(force: false);
    log.info('   Servidor apagado correctamente.');
    exit(0);
  });
}
