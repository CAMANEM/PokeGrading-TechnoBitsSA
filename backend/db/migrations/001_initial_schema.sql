-- ================================================================================
-- PokéGrading — DB Inicial (Sprint 2)
-- PostgreSQL compatible schema.
-- ================================================================================

CREATE TABLE "IMAGEN" (
  "id_imagen" integer PRIMARY KEY,
  "ruta_cloud" varchar(255) NOT NULL,
  "hash_visual" varchar(255),
  "calidad_score" numeric,
  "fecha_subida" timestamp NOT NULL DEFAULT now()
);

CREATE TABLE "USUARIO" (
  "id_usuario" integer PRIMARY KEY,
  "username" varchar(255) UNIQUE NOT NULL,
  "password_hash" varchar(255) NOT NULL,
  "email" varchar(255) UNIQUE NOT NULL,
  "rol" varchar(255) NOT NULL,
  "pais_residencia" varchar(255),
  "idioma" varchar(255),
  "api_key" varchar(255) UNIQUE,
  "cuota_mensual" integer,
  "cuota_consumida" integer,
  "sla_plan" varchar(255),
  "fecha_creacion" timestamp NOT NULL DEFAULT now()
);

CREATE TABLE "CARTA" (
  "id_carta" integer PRIMARY KEY,
  "tipo" varchar(255) NOT NULL,
  "nombre_display" varchar(255) NOT NULL,
  "set_code" varchar(255) NOT NULL,
  "numero_carta" varchar(255) NOT NULL,
  "edicion" varchar(255) NOT NULL,
  "idioma" varchar(255) NOT NULL,
  "acabado" varchar(255) NOT NULL,
  "anio" integer,
  "rareza" varchar(255),
  "ilustrador" varchar(255),
  "id_imagen_derecho" integer NOT NULL,
  "id_imagen_reves" integer NOT NULL,
  "estado_aprobacion" varchar(255) NOT NULL DEFAULT 'pendiente',
  "id_creador" integer NOT NULL,
  "id_validador" integer,
  "fecha_registro" timestamp NOT NULL DEFAULT now(),
  CONSTRAINT "fk_carta_imagen_derecho"
    FOREIGN KEY ("id_imagen_derecho") REFERENCES "IMAGEN" ("id_imagen"),
  CONSTRAINT "fk_carta_imagen_reves"
    FOREIGN KEY ("id_imagen_reves") REFERENCES "IMAGEN" ("id_imagen"),
  CONSTRAINT "fk_carta_creador"
    FOREIGN KEY ("id_creador") REFERENCES "USUARIO" ("id_usuario"),
  CONSTRAINT "fk_carta_validador"
    FOREIGN KEY ("id_validador") REFERENCES "USUARIO" ("id_usuario")
);

CREATE TABLE "SOLICITUD_EVALUACION" (
  "id_solicitud" integer PRIMARY KEY,
  "id_usuario" integer NOT NULL,
  "correlation_id" varchar(255) UNIQUE NOT NULL,
  "estado_proceso" varchar(255) NOT NULL,
  "fecha_solicitud" timestamp NOT NULL DEFAULT now(),
  CONSTRAINT "fk_solicitud_usuario"
    FOREIGN KEY ("id_usuario") REFERENCES "USUARIO" ("id_usuario")
);

CREATE TABLE "CARTA_REFERENCIA" (
  "id_carta" integer PRIMARY KEY,
  CONSTRAINT "fk_carta_referencia_carta"
    FOREIGN KEY ("id_carta") REFERENCES "CARTA" ("id_carta")
);

CREATE TABLE "CARTA_SUBMITTER" (
  "id_carta" integer PRIMARY KEY,
  "id_solicitud" integer NOT NULL,
  "id_carta_ref" integer NOT NULL,
  CONSTRAINT "fk_carta_submitter_carta"
    FOREIGN KEY ("id_carta") REFERENCES "CARTA" ("id_carta"),
  CONSTRAINT "fk_carta_submitter_solicitud"
    FOREIGN KEY ("id_solicitud") REFERENCES "SOLICITUD_EVALUACION" ("id_solicitud"),
  CONSTRAINT "fk_carta_submitter_carta_ref"
    FOREIGN KEY ("id_carta_ref") REFERENCES "CARTA_REFERENCIA" ("id_carta")
);

CREATE TABLE "ALGORITMO" (
  "id_version" integer PRIMARY KEY,
  "nombre_version" varchar(255) NOT NULL,
  "fecha_lanzamiento" timestamp,
  "precision_global_validada" numeric,
  "es_activo" boolean NOT NULL DEFAULT false
);

CREATE TABLE "EVALUACION_RESULTADO" (
  "id_evaluacion" integer PRIMARY KEY,
  "id_solicitud" integer NOT NULL,
  "id_algoritmo" integer NOT NULL,
  "grado_final" numeric,
  "confianza_global" numeric,
  "es_resultado_final" boolean NOT NULL DEFAULT true,
  "fecha_evaluacion" timestamp NOT NULL DEFAULT now(),
  CONSTRAINT "fk_evaluacion_solicitud"
    FOREIGN KEY ("id_solicitud") REFERENCES "SOLICITUD_EVALUACION" ("id_solicitud"),
  CONSTRAINT "fk_evaluacion_algoritmo"
    FOREIGN KEY ("id_algoritmo") REFERENCES "ALGORITMO" ("id_version")
);

CREATE TABLE "SUBGRADE" (
  "id_subgrade" integer PRIMARY KEY,
  "id_evaluacion" integer NOT NULL,
  "criterio" varchar(255) NOT NULL,
  "valor" numeric,
  "confianza_especifica" numeric,
  "metricas_json" json,
  CONSTRAINT "fk_subgrade_evaluacion"
    FOREIGN KEY ("id_evaluacion") REFERENCES "EVALUACION_RESULTADO" ("id_evaluacion")
);

CREATE TABLE "REVISION_HUMANA" (
  "id_revision" integer PRIMARY KEY,
  "id_evaluacion" integer NOT NULL,
  "id_reviewer" integer NOT NULL,
  "motivo" varchar(255) NOT NULL,
  "resultado_grado" numeric,
  "comentarios" text,
  "estado_revision" varchar(255) NOT NULL,
  "fecha_asignacion" timestamp NOT NULL DEFAULT now(),
  "fecha_resolucion" timestamp,
  CONSTRAINT "fk_revision_evaluacion"
    FOREIGN KEY ("id_evaluacion") REFERENCES "EVALUACION_RESULTADO" ("id_evaluacion"),
  CONSTRAINT "fk_revision_reviewer"
    FOREIGN KEY ("id_reviewer") REFERENCES "USUARIO" ("id_usuario")
);

CREATE TABLE "RECOMENDACION" (
  "id_recomendacion" integer PRIMARY KEY,
  "id_evaluacion" integer NOT NULL,
  "accion_sugerida" varchar(255),
  "valor_estimado_raw" numeric,
  "valor_estimado_graded" numeric,
  "ganancia_esperada" numeric,
  "costo_envio_estimado" numeric,
  CONSTRAINT "fk_recomendacion_evaluacion"
    FOREIGN KEY ("id_evaluacion") REFERENCES "EVALUACION_RESULTADO" ("id_evaluacion")
);

COMMENT ON COLUMN "USUARIO"."rol" IS 'Submitter | Reviewer | Admin | B2B';
COMMENT ON COLUMN "USUARIO"."api_key" IS 'Solo para rol B2B';
COMMENT ON COLUMN "USUARIO"."sla_plan" IS 'Basic | Premium';
COMMENT ON COLUMN "CARTA"."tipo" IS 'referencia | submitter';
COMMENT ON COLUMN "CARTA"."edicion" IS '1st Edition | Unlimited';
COMMENT ON COLUMN "CARTA"."acabado" IS 'Holo | Reverse Holo | etc.';
COMMENT ON COLUMN "CARTA"."estado_aprobacion" IS 'pendiente | aprobado | rechazado';
COMMENT ON COLUMN "SOLICITUD_EVALUACION"."estado_proceso" IS 'identificado | validando | completado | revision_humana';
COMMENT ON TABLE "EVALUACION_RESULTADO" IS 'Inmutable: ante una re-evaluación se crea un nuevo registro';
COMMENT ON COLUMN "SUBGRADE"."criterio" IS 'Centering | Corners | Edges | Surface';
COMMENT ON COLUMN "REVISION_HUMANA"."motivo" IS 'baja_confianza | disputa_usuario | fallo_tecnico';
COMMENT ON COLUMN "REVISION_HUMANA"."estado_revision" IS 'pendiente | completada';
COMMENT ON COLUMN "RECOMENDACION"."accion_sugerida" IS 'conservar | graduar_psa | vender';
