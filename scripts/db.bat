@echo off
:: ============================================================================
:: PokéGrading - PostgreSQL bootstrap (Windows - CMD / Git Bash)
:: ============================================================================
:: Uso: scripts\db.bat
:: Este wrapper delega en PowerShell para iniciar PostgreSQL y pgAdmin.
:: ============================================================================

setlocal

set "SCRIPT_DIR=%~dp0"

where powershell >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%db.ps1"
  exit /b %ERRORLEVEL%
)

echo PowerShell no esta disponible. Instala Docker Desktop y ejecuta manualmente:
echo   docker compose up -d postgres pgadmin
exit /b 1
