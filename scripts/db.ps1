# ===============================================================================
# PokéGrading - PostgreSQL bootstrap (Windows - PowerShell)
# ===============================================================================
# Uso:
#   .\scripts\db.ps1
#
# Levanta PostgreSQL 16 y pgAdmin usando docker compose.
# La migración inicial se aplica automáticamente cuando el volumen de datos está vacío.
# ===============================================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

function Write-Header {
  Write-Host ""
  Write-Host "======================================================" -ForegroundColor Blue
  Write-Host "  PokéGrading - Database Bootstrap (PowerShell)" -ForegroundColor Cyan
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
  Write-Warn "Docker no está instalado o no está en PATH."
  Write-Host "Instala Docker Desktop y vuelve a ejecutar este script." -ForegroundColor Yellow
  exit 1
}

try {
  docker info 2>&1 | Out-Null
} catch {
  Write-Warn "Docker no está corriendo. Inicia Docker Desktop y vuelve a ejecutar el script."
  exit 1
}

Write-Step "Levantando PostgreSQL y pgAdmin..."
Set-Location $PROJECT_ROOT
docker compose up -d postgres pgadmin

Write-Ok "PostgreSQL iniciado en localhost:5432"
Write-Ok "pgAdmin disponible en http://localhost:5050"
Write-Host ""
Write-Host "Si es la primera vez, el esquema se crea automáticamente desde backend/db/migrations." -ForegroundColor Gray
Write-Host "Si quieres reinicializarlo desde cero, usa: docker compose down -v" -ForegroundColor Gray
Write-Host ""
