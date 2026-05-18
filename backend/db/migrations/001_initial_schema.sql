-- ==============================================================================
-- PokéGrading — Migración Inicial (Sprint 0 / Hello World)
-- Se ejecuta automáticamente al iniciar PostgreSQL con Docker Compose.
-- ==============================================================================

-- Extensión para UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- Tabla: schema_migrations
-- Registro de migraciones aplicadas (control de versiones del esquema)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS schema_migrations (
  version     VARCHAR(20) PRIMARY KEY,
  applied_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  description TEXT
);

-- Registrar esta migración
INSERT INTO schema_migrations (version, description)
VALUES ('001', 'Migración inicial — Tablas base Sprint 0')
ON CONFLICT (version) DO NOTHING;

-- ==============================================================================
-- Tabla: users (Sprint 1 — estructura base, sin datos)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email           VARCHAR(255) NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  role            VARCHAR(50)  NOT NULL CHECK (role IN ('submitter', 'reviewer', 'admin', 'b2b')),
  display_name    VARCHAR(255),
  api_key         VARCHAR(255) UNIQUE,         -- Solo para rol b2b
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role  ON users(role);

-- ==============================================================================
-- Tabla: pokemon_cards (Sprint 1 — estructura base)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS pokemon_cards (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Atributos de identidad
  card_set        VARCHAR(255) NOT NULL,
  card_number     VARCHAR(50)  NOT NULL,
  edition         VARCHAR(100) NOT NULL,
  language        VARCHAR(10)  NOT NULL,
  finish          VARCHAR(50)  NOT NULL,   -- holo, reverse_holo, normal, etc.
  -- Estado y flujo de validación dual
  status          VARCHAR(50)  NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected')),
  created_by      UUID NOT NULL REFERENCES users(id),
  validated_by    UUID REFERENCES users(id),
  validated_at    TIMESTAMP WITH TIME ZONE,
  -- Inmutabilidad (versionado)
  version         INTEGER NOT NULL DEFAULT 1,
  is_current      BOOLEAN NOT NULL DEFAULT TRUE,
  -- Timestamps
  created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cards_status     ON pokemon_cards(status);
CREATE INDEX IF NOT EXISTS idx_cards_created_by ON pokemon_cards(created_by);

-- Restricción de unicidad para la combinación de atributos de identidad
CREATE UNIQUE INDEX IF NOT EXISTS idx_cards_identity
  ON pokemon_cards(card_set, card_number, edition, language, finish)
  WHERE is_current = TRUE;

-- ==============================================================================
-- Trigger: Actualizar updated_at automáticamente
-- ==============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_cards_updated_at
  BEFORE UPDATE ON pokemon_cards
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ==============================================================================
-- Datos de ejemplo para verificar el Hello World
-- ==============================================================================
-- (Comentados en producción — solo para desarrollo)
-- INSERT INTO users (email, password_hash, role, display_name, is_verified)
-- VALUES ('admin@pokegrading.local', 'hash_placeholder', 'admin', 'Admin PokéGrading', TRUE);
