#!/usr/bin/env bash
# ===============================================================================
# PokeGrading - Database bootstrap (Linux / macOS)
# ===============================================================================
# Usage:
#   chmod +x scripts/db.sh
#   ./scripts/db.sh
# ===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if ! command -v docker &>/dev/null; then
  echo "Docker is not installed or not in PATH."
  echo "Install Docker Desktop and run this script again."
  exit 1
fi

if ! docker info &>/dev/null; then
  echo "Docker is not running. Start Docker Desktop and run this script again."
  exit 1
fi

echo "Starting PostgreSQL, MongoDB and pgAdmin..."
cd "$PROJECT_ROOT"
docker compose up -d postgres mongodb pgadmin

echo "PostgreSQL available at localhost:5432"
echo "MongoDB available at localhost:27017"
echo "pgAdmin available at http://localhost:5050"
echo ""
echo "On first run, schemas are created from backend/db/init/ and backend/db/mongodb/."
echo "To reset from scratch: docker compose down -v"
