# ==============================================================================
# PokeGrading - Script de instalacion y configuracion (Windows - PowerShell)
# ==============================================================================
# Uso (PowerShell como Administrador):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\setup.ps1
#
# Prerrequisitos:
#   - Windows 10/11 64-bit
#   - PowerShell 5.1 o superior
#   - Conexion a internet
#   - Docker Desktop instalado (recomendado)
# ==============================================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# --- Configuracion ------------------------------------------------------------
$FLUTTER_VERSION = "3.22.0"
$FLUTTER_INSTALL_DIR = "$env:USERPROFILE\flutter"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

# --- Colores / Helpers --------------------------------------------------------
function Write-Header {
  Write-Host ""
  Write-Host "======================================================" -ForegroundColor Blue
  Write-Host "  PokeGrading - Setup Script (Windows PowerShell)" -ForegroundColor Cyan
  Write-Host "======================================================" -ForegroundColor Blue
  Write-Host ""
}

function Write-Step($msg) {
  Write-Host "`n> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
  Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
  Write-Host "  [WARN] $msg" -ForegroundColor Yellow
}

function Write-Err($msg) {
  Write-Host "  [ERROR] $msg" -ForegroundColor Red
}

function Test-CommandExists($cmd) {
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Add-ToUserPath($newPath) {
  $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
  if ($currentPath -notlike "*$newPath*") {
    [Environment]::SetEnvironmentVariable(
      "PATH",
      "$currentPath;$newPath",
      "User"
    )
    $env:PATH = "$env:PATH;$newPath"
    Write-Ok "PATH actualizado: $newPath"
  } else {
    Write-Ok "PATH ya contiene: $newPath"
  }
}

# --- 1. Cabecera --------------------------------------------------------------
Write-Header

# --- 2. Verificar permisos de administrador -----------------------------------
Write-Step "Verificando permisos..."
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
  Write-Warn "No se esta ejecutando como Administrador."
  Write-Warn "Algunas operaciones podrian fallar."
  Write-Warn "Para evitar problemas, ejecuta PowerShell como Administrador."
} else {
  Write-Ok "Ejecutando con permisos de Administrador"
}

# --- 3. Verificar Git ---------------------------------------------------------
Write-Step "Verificando Git..."
if (Test-CommandExists "git") {
  $gitVersion = git --version 2>$null
  Write-Ok "$gitVersion"
} else {
  Write-Warn "Git no encontrado. Instalando con winget..."
  try {
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    Write-Ok "Git instalado"
    $env:PATH = "$env:PATH;C:\Program Files\Git\cmd"
  } catch {
    Write-Err "No se pudo instalar Git automaticamente."
    Write-Host "  Descargalo desde: https://git-scm.com/download/win" -ForegroundColor Yellow
    Read-Host "  Instalalo y presiona ENTER para continuar"
  }
}

# --- 4. Verificar Visual Studio Build Tools (C++ workload) -------------------
Write-Step "Verificando Visual Studio Build Tools (C++ workload)..."

# Verificar si ya esta instalado
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$buildToolsInstalled = $false

if (Test-Path $vsWhere) {
  $installPath = & $vsWhere -latest -property installationPath 2>$null
  if ($installPath) {
    # Verificar que el workload de C++ este instalado
    $vsWhereProducts = & $vsWhere -products * -requires Microsoft.VisualStudio.Workload.VCTools -property installationPath 2>$null
    if ($vsWhereProducts) {
      $buildToolsInstalled = $true
      Write-Ok "Visual Studio Build Tools con workload C++ encontrado"
    }
  }
}

if (-not $buildToolsInstalled) {
  Write-Warn "Visual Studio Build Tools no encontrado o sin workload C++."
  Write-Host "  Instalando VS Build Tools con C++ workload (~5-10 GB)..." -ForegroundColor Yellow
  Write-Host "  Esto puede tardar varios minutos..." -ForegroundColor Yellow

  try {
    # Descargar el instalador de Build Tools
    $vsBuildToolsUrl = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
    $vsBuildToolsInstaller = "$env:TEMP\vs_BuildTools.exe"

    Write-Host "  Descargando instalador..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $vsBuildToolsUrl -OutFile $vsBuildToolsInstaller -UseBasicParsing

    Write-Host "  Instalando con workload C++ desktop..." -ForegroundColor Gray

    # Ejecutar el instalador con los componentes necesarios
    # Componentes clave para dartcv4/OpenCV:
    #   Microsoft.VisualStudio.Workload.VCTools - Workload de herramientas C++
    #   Microsoft.VisualStudio.Component.VC.Tools.x86.x64 - Compilador MSVC
    #   Microsoft.VisualStudio.Component.Windows11SDK.22621 - Windows SDK
    Start-Process -FilePath $vsBuildToolsInstaller -ArgumentList @(
      "--quiet",
      "--wait",
      "--norestart",
      "--nocache",
      "--add", "Microsoft.VisualStudio.Workload.VCTools",
      "--includeRecommended"
    ) -Wait -NoNewWindow

    # Limpiar instalador
    Remove-Item $vsBuildToolsInstaller -Force -ErrorAction SilentlyContinue

    # Verificar que se instalo
    if (Test-Path $vsWhere) {
      $vsWhereProducts = & $vsWhere -products * -requires Microsoft.VisualStudio.Workload.VCTools -property installationPath 2>$null
      if ($vsWhereProducts) {
        Write-Ok "VS Build Tools con workload C++ instalado exitosamente"
      } else {
        Write-Warn "VS Build Tools se instalo pero no se pudo verificar el workload C++"
        Write-Host "  Puede que necesites reiniciar la terminal" -ForegroundColor Yellow
      }
    } else {
      Write-Warn "VS Build Tools instalado, pero vswhere no encontrado para verificar"
    }
  } catch {
    Write-Err "Error instalando VS Build Tools: $_"
    Write-Host "  Descargalo manualmente desde:" -ForegroundColor Yellow
    Write-Host "  https://visualstudio.microsoft.com/visual-cpp-build-tools/" -ForegroundColor Cyan
    Write-Host ""
    $response = Read-Host "  Deseas continuar sin VS Build Tools? (s/N)"
    if ($response -notmatch "^[sS]$") {
      exit 1
    }
  }
}

# --- 5. Verificar Docker ------------------------------------------------------
Write-Step "Verificando Docker..."
if (Test-CommandExists "docker") {
  $dockerVersion = docker --version 2>$null
  Write-Ok "$dockerVersion"

  # Verificar que el daemon este corriendo
  try {
    docker info 2>&1 | Out-Null
    Write-Ok "Docker daemon activo"
  } catch {
    Write-Warn "Docker no esta corriendo. Intentando iniciar Docker Desktop..."
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -ErrorAction SilentlyContinue
    Write-Host "  Esperando que Docker inicie (45 segundos)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 45
  }
} else {
  Write-Warn "Docker no esta instalado."
  Write-Host "  Intentando instalar Docker Desktop automaticamente con winget..." -ForegroundColor Yellow
  try {
    winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements
    Write-Ok "Docker Desktop instalado exitosamente!"
    Write-Host "  Iniciando Docker Desktop..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -ErrorAction SilentlyContinue
    Write-Host "  Esperando que Docker inicialice (45 segundos)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 45
  } catch {
    Write-Err "No se pudo instalar Docker Desktop automaticamente."
    Write-Host "  Puedes descargarlo e instalarlo manualmente desde:" -ForegroundColor Yellow
    Write-Host "  https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
    Write-Host ""
    $response = Read-Host "  ¿Deseas continuar el setup sin Docker por ahora? (s/N)"
    if ($response -notmatch "^[sS]$") {
      exit 1
    }
  }
}

# --- 6. Instalar Flutter SDK --------------------------------------------------
Write-Step "Verificando Flutter SDK..."

$FLUTTER_EXE = ""

# Buscar flutter en PATH
if (Test-CommandExists "flutter") {
  $FLUTTER_EXE = "flutter"
  $flutterVersion = flutter --version 2>$null | Select-Object -First 1
  Write-Ok "Flutter encontrado en PATH: $flutterVersion"
}
# Buscar en directorio de instalacion por defecto
elseif (Test-Path "$FLUTTER_INSTALL_DIR\bin\flutter.bat") {
  $FLUTTER_EXE = "$FLUTTER_INSTALL_DIR\bin\flutter.bat"
  $flutterVersion = & $FLUTTER_EXE --version 2>$null | Select-Object -First 1
  Write-Ok "Flutter encontrado en $FLUTTER_INSTALL_DIR"
}
else {
  Write-Warn "Flutter no encontrado. Descargando Flutter $FLUTTER_VERSION..."

  $FLUTTER_ZIP = "$env:TEMP\flutter_windows_$FLUTTER_VERSION-stable.zip"
  $FLUTTER_URL = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FLUTTER_VERSION-stable.zip"

  Write-Host "  URL: $FLUTTER_URL" -ForegroundColor Gray
  Write-Host "  Esto puede tardar varios minutos (~500MB)..." -ForegroundColor Yellow

  try {
    # Usar Invoke-WebRequest con progreso
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $FLUTTER_URL -OutFile $FLUTTER_ZIP -UseBasicParsing
    $ProgressPreference = 'Continue'

    Write-Ok "Descarga completada. Extrayendo..."

    # Extraer al directorio de usuario
    $parentDir = Split-Path -Parent $FLUTTER_INSTALL_DIR
    if (-not (Test-Path $parentDir)) {
      New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    Expand-Archive -Path $FLUTTER_ZIP -DestinationPath $parentDir -Force
    Remove-Item $FLUTTER_ZIP -Force

    Write-Ok "Flutter extraido en $FLUTTER_INSTALL_DIR"
  } catch {
    Write-Err "Error descargando Flutter: $_"
    Write-Host "  Descarga manualmente desde: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow
    exit 1
  }

  $FLUTTER_EXE = "$FLUTTER_INSTALL_DIR\bin\flutter.bat"

  # Agregar Flutter al PATH del usuario
  Add-ToUserPath "$FLUTTER_INSTALL_DIR\bin"
}

# Obtener la ruta al ejecutable dart (viene con Flutter)
$DART_EXE = ""
if (Test-CommandExists "dart") {
  $DART_EXE = "dart"
} else {
  # Dart esta incluido dentro del SDK de Flutter
  $flutterDir = Split-Path -Parent (Split-Path -Parent $FLUTTER_EXE)
  $dartPath = "$flutterDir\bin\dart.bat"
  if (Test-Path $dartPath) {
    $DART_EXE = $dartPath
    Add-ToUserPath (Split-Path -Parent $FLUTTER_EXE)
  } else {
    # Buscar en cache
    $dartCachePath = "$FLUTTER_INSTALL_DIR\bin\cache\dart-sdk\bin\dart.exe"
    if (Test-Path $dartCachePath) {
      $DART_EXE = $dartCachePath
    } else {
      # Ejecutar flutter doctor para que descargue el dart SDK
      Write-Host "  Inicializando Flutter (descargando dependencias internas)..." -ForegroundColor Yellow
      & $FLUTTER_EXE doctor --no-version-check 2>&1 | Out-Null
      $DART_EXE = "$FLUTTER_INSTALL_DIR\bin\dart.bat"
    }
  }
}

Write-Ok "Dart encontrado: $DART_EXE"

# --- 7. Flutter Doctor --------------------------------------------------------
Write-Step "Ejecutando flutter doctor..."
try {
  & $FLUTTER_EXE doctor --no-version-check 2>&1 | Select-Object -First 20
} catch {
  Write-Warn "flutter doctor tuvo problemas (normal en primera ejecucion)"
}

# --- 8. Configurar .env -------------------------------------------------------
Write-Step "Configurando variables de entorno..."

$envFile = Join-Path $PROJECT_ROOT ".env"
$envExample = Join-Path $PROJECT_ROOT ".env.example"

if (-not (Test-Path $envFile)) {
  Copy-Item $envExample $envFile
  Write-Ok ".env creado a partir de .env.example"
} else {
  Write-Ok ".env ya existe (no se sobreescribe)"
}

# --- 9. Instalar dependencias del Backend -------------------------------------
Write-Step "Instalando dependencias del Backend (Dart)..."

Set-Location (Join-Path $PROJECT_ROOT "backend")
& $DART_EXE pub get
Write-Ok "Dependencias del backend instaladas"

# --- 10. Instalar dependencias del Frontend ------------------------------------
Write-Step "Instalando dependencias del Frontend (Flutter)..."

Set-Location (Join-Path $PROJECT_ROOT "frontend")
& $FLUTTER_EXE pub get
Write-Ok "Dependencias del frontend instaladas"

# --- 11. Habilitar Flutter Web ------------------------------------------------
Write-Step "Habilitando Flutter Web..."
try {
  & $FLUTTER_EXE config --enable-web 2>&1 | Out-Null
  Write-Ok "Flutter Web habilitado"
} catch {
  Write-Warn "No se pudo habilitar Flutter Web (puede ya estar habilitado)"
}

# --- 12. Levantar PostgreSQL con Docker ---------------------------------------
if (Test-CommandExists "docker") {
  try {
    docker info 2>&1 | Out-Null
    Write-Step "Levantando PostgreSQL con Docker Compose..."
    Set-Location $PROJECT_ROOT
    docker compose up -d postgres
    Write-Ok "PostgreSQL iniciado en localhost:5432"
    Write-Ok "pgAdmin disponible en http://localhost:5050"
  } catch {
    Write-Warn "Docker no esta activo. Salta el inicio de PostgreSQL."
  }
}

# --- 13. Volver al directorio del proyecto ------------------------------------
Set-Location $PROJECT_ROOT

# --- 14. Resumen Final --------------------------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  [SUCCESS] Setup completado exitosamente!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Para iniciar el proyecto:" -ForegroundColor White
Write-Host ""
Write-Host "  # Terminal 1 - Backend:" -ForegroundColor Cyan
Write-Host "  cd backend"
Write-Host "  dart run bin/server.dart"
Write-Host ""
Write-Host "  # Terminal 2 - Frontend:" -ForegroundColor Cyan
Write-Host "  cd frontend"
Write-Host "  flutter run -d chrome --web-port 3000"
Write-Host ""
Write-Host "  URLs:" -ForegroundColor Cyan
Write-Host "  Backend  : http://localhost:8080"
Write-Host "  Frontend : http://localhost:3000"
Write-Host "  pgAdmin  : http://localhost:5050"
Write-Host ""
Write-Host "IMPORTANTE: Abre una nueva terminal para que el PATH" -ForegroundColor Yellow
Write-Host "actualizado de Flutter tome efecto." -ForegroundColor Yellow
Write-Host ""
