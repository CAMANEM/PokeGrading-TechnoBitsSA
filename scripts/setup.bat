@echo off
:: ==============================================================================
:: PokeGrading - Script de instalacion (Windows - CMD / Git Bash)
:: ==============================================================================
:: Uso: scripts\setup.bat
:: Este script es un wrapper que detecta el entorno y delega a setup.ps1
:: o ejecuta pasos basicos si PowerShell no esta disponible.
:: ==============================================================================

setlocal enabledelayedexpansion

:: --- Colores (requiere Windows 10+) -----------------------------------------
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[32m"
set "CYAN=%ESC%[36m"
set "YELLOW=%ESC%[33m"
set "RED=%ESC%[31m"
set "RESET=%ESC%[0m"
set "BOLD=%ESC%[1m"

echo.
echo %CYAN%%BOLD%======================================================%RESET%
echo %CYAN%%BOLD%  PokeGrading - Setup Script (Windows CMD)%RESET%
echo %CYAN%%BOLD%======================================================%RESET%
echo.

:: --- Obtener directorio raiz del proyecto ------------------------------------
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."

:: --- Detectar PowerShell -----------------------------------------------------
where powershell >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  echo %CYAN%^> PowerShell detectado - delegando a setup.ps1...%RESET%
  echo.

  :: Ejecutar el script PowerShell con politica de ejecucion Bypass
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup.ps1"

  if %ERRORLEVEL% NEQ 0 (
    echo %RED%[ERROR] El script PowerShell fallo con codigo: %ERRORLEVEL%%RESET%
    echo.
    echo %YELLOW%Intenta ejecutar manualmente en PowerShell como Administrador:%RESET%
    echo   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    echo   .\scripts\setup.ps1
    pause
    exit /b 1
  )
  goto :end
)

:: --- Fallback: Sin PowerShell - pasos manuales basicos -----------------------
echo %YELLOW%[WARN] PowerShell no disponible. Ejecutando pasos basicos...%RESET%
echo.

:: Verificar Git
where git >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  for /f "tokens=*" %%v in ('git --version') do echo %GREEN%[OK] %%v%RESET%
) else (
  echo %RED%[ERROR] Git no encontrado.%RESET%
  echo %YELLOW%  Descarga Git desde: https://git-scm.com/download/win%RESET%
)

:: Verificar Docker
where docker >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  for /f "tokens=*" %%v in ('docker --version') do echo %GREEN%[OK] Docker: %%v%RESET%
) else (
  echo %YELLOW%[WARN] Docker no encontrado.%RESET%
  echo %YELLOW%  Descarga Docker Desktop: https://www.docker.com/products/docker-desktop/%RESET%
)

:: Verificar Flutter
where flutter >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  for /f "tokens=2" %%v in ('flutter --version 2^>nul ^| findstr "Flutter"') do echo %GREEN%[OK] Flutter %%v%RESET%
) else (
  echo %YELLOW%[WARN] Flutter no encontrado en PATH.%RESET%
  echo %YELLOW%  Descarga Flutter desde: https://flutter.dev/docs/get-started/install/windows%RESET%
  echo.
  echo %YELLOW%  Una vez instalado, ejecuta este script nuevamente.%RESET%
  echo.
  pause
  exit /b 1
)

:: Verificar Dart
where dart >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  for /f "tokens=*" %%v in ('dart --version 2^>&1') do echo %GREEN%[OK] %%v%RESET%
)

:: Configurar .env
echo.
echo %CYAN%^> Configurando .env...%RESET%
if not exist "%PROJECT_ROOT%\.env" (
  copy "%PROJECT_ROOT%\.env.example" "%PROJECT_ROOT%\.env" >nul
  echo %GREEN%[OK] .env creado%RESET%
) else (
  echo %GREEN%[OK] .env ya existe%RESET%
)

:: Instalar dependencias del backend
echo.
echo %CYAN%^> Instalando dependencias del Backend...%RESET%
cd /d "%PROJECT_ROOT%\backend"
dart pub get
if %ERRORLEVEL% EQU 0 (
  echo %GREEN%[OK] Dependencias del backend instaladas%RESET%
) else (
  echo %RED%[ERROR] Error instalando dependencias del backend%RESET%
)

:: Instalar dependencias del frontend
echo.
echo %CYAN%^> Instalando dependencias del Frontend...%RESET%
cd /d "%PROJECT_ROOT%\frontend"
flutter pub get
if %ERRORLEVEL% EQU 0 (
  echo %GREEN%[OK] Dependencias del frontend instaladas%RESET%
) else (
  echo %RED%[ERROR] Error instalando dependencias del frontend%RESET%
)

:: Habilitar Flutter Web
flutter config --enable-web >nul 2>&1
echo %GREEN%[OK] Flutter Web habilitado%RESET%

:: Levantar Docker (si esta disponible)
where docker >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  echo.
  echo %CYAN%^> Levantando PostgreSQL con Docker...%RESET%
  cd /d "%PROJECT_ROOT%"
  docker compose up -d postgres
  if %ERRORLEVEL% EQU 0 (
    echo %GREEN%[OK] PostgreSQL iniciado en localhost:5432%RESET%
  )
)

cd /d "%PROJECT_ROOT%"

:end
echo.
echo %GREEN%%BOLD%======================================================%RESET%
echo %GREEN%%BOLD%  [SUCCESS] Setup completado!%RESET%
echo %GREEN%%BOLD%======================================================%RESET%
echo.
echo %BOLD%Para iniciar el proyecto:%RESET%
echo.
echo   %CYAN%# Terminal 1 - Backend:%RESET%
echo   cd backend
echo   dart run bin/server.dart
echo.
echo   %CYAN%# Terminal 2 - Frontend:%RESET%
echo   cd frontend
echo   flutter run -d chrome --web-port 3000
echo.
echo   %CYAN%URLs:%RESET%
echo   Backend  : http://localhost:8080
echo   Frontend : http://localhost:3000
echo   pgAdmin  : http://localhost:5050
echo.

pause
