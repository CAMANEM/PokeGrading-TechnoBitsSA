#!/usr/bin/env bash
# ===============================================================================
# PokéGrading - PostgreSQL bootstrap (Linux / macOS)
# ===============================================================================
# Uso:
#   chmod +x scripts/db.sh
#   ./scripts/db.sh
# ===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if ! command -v docker &>/dev/null; then
  echo "Docker no está instalado o no está en PATH."
  echo "Instala Docker Desktop y vuelve a ejecutar este script."
  exit 1
fi

if ! docker info &>/dev/null; then
  echo "Docker no está corriendo. Inicia Docker Desktop y vuelve a ejecutar el script."
  exit 1
fi

echo "Levantando PostgreSQL y pgAdmin..."
cd "$PROJECT_ROOT"
docker compose up -d postgres pgadmin

echo "PostgreSQL iniciado en localhost:5432"
echo "pgAdmin disponible en http://localhost:5050"
echo ""
echo "Si es la primera vez, el esquema se crea automáticamente desde backend/db/migrations."
echo "Si quieres reinicializarlo desde cero, usa: docker compose down -v"
