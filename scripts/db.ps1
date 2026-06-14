# ===============================================================================
# PokeGrading - Database bootstrap (Windows - PowerShell)
# ===============================================================================
# Usage:
#   .\scripts\db.ps1
#
# Starts PostgreSQL 16, MongoDB 7 and pgAdmin via docker compose.
# Schemas are applied automatically when data volumes are empty.
# ===============================================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

function Write-Header {
  Write-Host ""
  Write-Host "======================================================" -ForegroundColor Blue
  Write-Host "  PokeGrading - Database Bootstrap (PowerShell)" -ForegroundColor Cyan
  Write-Host "======================================================" -ForegroundColor Blue
  Write-Host ""
}

function Write-Step($msg) {
  Write-Host "> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
  Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
  Write-Host "  [WARN] $msg" -ForegroundColor Yellow
}

function Test-CommandExists($cmd) {
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

Write-Header

if (-not (Test-CommandExists "docker")) {
  Write-Warn "Docker is not installed or not in PATH."
  Write-Host "Install Docker Desktop and run this script again." -ForegroundColor Yellow
  exit 1
}

try {
  docker info 2>&1 | Out-Null
} catch {
  Write-Warn "Docker is not running. Start Docker Desktop and run this script again."
  exit 1
}

Write-Step "Starting PostgreSQL, MongoDB and pgAdmin..."
Set-Location $PROJECT_ROOT
docker compose up -d postgres mongodb pgadmin

Write-Ok "PostgreSQL available at localhost:5432"
Write-Ok "MongoDB available at localhost:27017"
Write-Ok "pgAdmin available at http://localhost:5050"
Write-Host ""
Write-Host "On first run, schemas are created from backend/db/init/ and backend/db/mongodb/." -ForegroundColor Gray
Write-Host "To reset from scratch: docker compose down -v" -ForegroundColor Gray
Write-Host ""
