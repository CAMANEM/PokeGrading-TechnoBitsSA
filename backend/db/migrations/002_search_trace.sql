-- ================================================================================
-- PokéGrading — Search Trace Table
-- Stores image search traces for observability and debugging.
-- ================================================================================

CREATE TABLE "BUSQUEDA_TRACE" (
  "id_trace" varchar(255) PRIMARY KEY,
  "metodo" varchar(50) NOT NULL,
  "caracteristicas_query" json,
  "metadata_query" json,
  "candidatos" json NOT NULL,
  "decision" varchar(50) NOT NULL,
  "razon_decision" text,
  "fecha_creacion" timestamp NOT NULL DEFAULT now()
);

COMMENT ON COLUMN "BUSQUEDA_TRACE"."metodo" IS 'image | manual';
COMMENT ON COLUMN "BUSQUEDA_TRACE"."decision" IS 'auto_accept | multiple_candidates | not_found | manual_search_required | fuzzy_fallback';

-- Security audit log for polyglot detection and other security events
CREATE TABLE "AUDITORIA_SEGURIDAD" (
  "id_evento" serial PRIMARY KEY,
  "tipo_evento" varchar(100) NOT NULL,
  "detalles" text,
  "fecha_evento" timestamp NOT NULL DEFAULT now()
);

COMMENT ON COLUMN "AUDITORIA_SEGURIDAD"."tipo_evento" IS 'polyglot_detected | unauthorized_access | etc';
