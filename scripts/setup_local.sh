#!/usr/bin/env bash
set -euo pipefail

# Simple local setup helper for PokéGrading
# - creates a .env with sensible defaults if missing
# - brings up the postgres service via docker-compose
# - waits for postgres to accept connections
# - applies the SQL migration to create the schema

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

if [ ! -f .env ]; then
  cat > .env <<EOF
APP_ENV=development
APP_VERSION=0.1.0
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8080
BACKEND_LOG_LEVEL=info

USE_MOCK_REPOSITORIES=false

DB_HOST=postgres
DB_PORT=5432
DB_NAME=pokegrading
DB_USER=pokegrading_user
DB_PASSWORD=pokegrading_secret
DB_MAX_CONNECTIONS=10
DB_CONNECTION_TIMEOUT=30

# SMTP (not required for local dev without email confirmation)
SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_EMAIL=
SMTP_FROM_NAME=PokéGrading
SMTP_USE_SSL=false
EOF
  echo ".env created with defaults (edit if needed)."
else
  echo ".env already exists — leaving it unchanged."
fi

# Export variables from .env for use in this script
set -a
source .env
set +a

echo "Starting PostgreSQL (docker compose)..."
# Detect which docker compose command is available
if command -v docker-compose >/dev/null 2>&1; then
  DC_CMD="docker-compose"
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  DC_CMD="docker compose"
else
  echo "ERROR: neither 'docker-compose' nor 'docker compose' is available in PATH." >&2
  exit 1
fi

${DC_CMD} up -d postgres

echo "Waiting for PostgreSQL to accept connections..."
until ${DC_CMD} exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c 'SELECT 1' >/dev/null 2>&1; do
  sleep 1
done

echo "Applying DB migrations..."
# Pipe migration into psql (stdin forwarded into container)
${DC_CMD} exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" < backend/db/migrations/001_initial_schema.sql

echo "Migration applied."

cat <<EOT
Siguientes pasos:
- Iniciar backend: cd backend && dart run bin/server.dart
- Iniciar frontend: cd frontend && flutter run -d chrome
- O probar registro vía curl:
  curl -X POST http://localhost:8080/api/v1/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"tu@correo.com","username":"tu_usuario","password":"TuPass123!","country":"AR","language":"es","acceptedDisclosure":true}'

EOT

exit 0
