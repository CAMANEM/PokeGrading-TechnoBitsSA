# ADR-00X: Estrategia de Logging — PokéGrading

- **Status:** accepted
- **Date:** 2026-06-14
- **Related:** [ADR-001-arquitectura.md](ADR-001-arquitectura.md)

---

## Context

PokéGrading requiere trazabilidad end-to-end, auditoría operativa, transparencia del motor de grading y observabilidad compatible con Azure Application Insights, sin almacenar logs en tablas PostgreSQL adicionales.

---

## Decision

Adoptar **logging estructurado centralizado** con dos capas:

| Capa | Destino | Contenido |
|------|---------|-----------|
| **Operacional** | stdout, archivos JSONL rotados, App Insights (opcional) | Errores, métricas, auditoría, grading white-box |
| **Negocio** | `pre_grade.log_id` | `correlation_id` por evaluación (metadato, no log) |

**No** se usan tablas dedicadas de logs en PostgreSQL (`evaluation_trace`, `audit_event`, etc.).

---

## Contrato compartido

Paquete [`packages/pokegrading_logging/`](../../packages/pokegrading_logging/):

- `LogEvent` — esquema JSON canónico
- `CorrelationContext` — propagación de `correlation_id` vía Zone
- `LogRedaction` — passwords, secrets, imágenes base64
- `LogCategory` — `operational`, `audit`, `grading`, `metric`
- `AuditEventTypes` — eventos de auditoría nombrados

Backend: [`AppLogger`](../../backend/lib/core/logging/app_logger.dart) en `core/logging/`.

Frontend: [`ClientLogReporter`](../../frontend/lib/core/logging/client_log_reporter.dart) (errores de cliente).

---

## Esquema JSON

```json
{
  "timestamp": "2026-06-14T12:00:00.000Z",
  "level": "INFO",
  "category": "grading",
  "logger": "PokéGrading.Evaluation",
  "correlation_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Evaluation stage completed",
  "context": { "stage": "iqs_front", "duration_ms": 142 }
}
```

---

## Correlation ID

1. Cliente envía `X-Correlation-ID` (UUID v4) o el backend genera uno.
2. Middleware [`correlation_middleware.dart`](../../backend/lib/core/middleware/correlation_middleware.dart) lo inyecta en Zone y contexto HTTP.
3. Evaluaciones persisten el mismo valor en `pre_grade.log_id`.
4. Respuestas incluyen header y body `correlation_id`.

---

## Eventos de auditoría (category: audit)

| Evento | Origen |
|--------|--------|
| `user.register` | Registro (éxito y fallo) |
| `catalog.propose` | Creación de carta submitter |
| `security.polyglot_detected` | Evaluación — imagen maliciosa |
| `user.login`, `catalog.validate`, `config.change`, `b2b.api_key.revoke` | Pendientes cuando existan esos flujos |

---

## Grading white-box (category: grading)

Cada etapa del pipeline emite logs con `stage`, `duration_ms`, `inputs`/`outputs` (sin bytes de imagen).

Etapas: `iqs_front`, `iqs_back`, `polyglot_front`, `polyglot_back`, `persist_pre_grade`.

---

## Métricas (category: metric)

- `stage.latency` — evaluación y búsqueda de catálogo
- `evaluation.retry_exceeded`, `circuit_breaker.state_change` — cuando existan esas funcionalidades

---

## Retención en disco

| Variable | Default | Descripción |
|----------|---------|-------------|
| `LOG_DIR` | `./logs` (dev) / `/var/log/pokegrading` (prod) | Directorio de archivos |
| `LOG_FILE_ENABLED` | `false` | Activar FileSink |
| `LOG_FORMAT` | `json` | `json` o `pretty` |
| `LOG_RETENTION_DAYS` | `30` | Retención local post-compresión |

Rotación: [`scripts/logrotate/pokegrading`](../../scripts/logrotate/pokegrading) (daily, gzip, 30 días).

Backup a Azure Blob: **pendiente** (Phase 3).

---

## Azure Application Insights

Activar con:

```bash
APPINSIGHTS_ENABLED=true
APPINSIGHTS_CONNECTION_STRING=InstrumentationKey=...;IngestionEndpoint=https://...
```

Sink: [`app_insights_sink.dart`](../../backend/lib/core/logging/sinks/app_insights_sink.dart) — POST al endpoint `/v2/track`.

---

## Privacidad

Nunca loguear: passwords, JWT, API keys completas, SMTP secrets, payloads de imagen raw.

---

## Regla de uso

Todas las capas del backend deben usar `AppLogger` (o `Logger` de `package:logging` que pasa por el handler JSON). No usar `print()` en código de producción.
