#!/usr/bin/env bash
# ==============================================================================
# PokéGrading — Script de instalación y configuración (Linux / macOS)
# ==============================================================================
# Uso:
#   chmod +x scripts/setup.sh
#   ./scripts/setup.sh
#
# Prerrequisitos:
#   - curl, git, unzip (instalados por el script si faltan)
#   - Docker Desktop (debe estar instalado manualmente)
# ==============================================================================

set -euo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Constantes ───────────────────────────────────────────────────────────────
FLUTTER_VERSION="3.22.0"
FLUTTER_INSTALL_DIR="$HOME/flutter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ─── Helpers ──────────────────────────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${BLUE}${BOLD}══════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}${BOLD}  🎴 PokéGrading — Setup Script (Linux/macOS)${NC}"
  echo -e "${BLUE}${BOLD}══════════════════════════════════════════════════════${NC}"
  echo ""
}

print_step() {
  echo -e "\n${CYAN}${BOLD}▶ $1${NC}"
}

print_ok() {
  echo -e "  ${GREEN}✓ $1${NC}"
}

print_warn() {
  echo -e "  ${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "  ${RED}✗ ERROR: $1${NC}"
}

command_exists() {
  command -v "$1" &>/dev/null
}

# ─── 1. Cabecera ──────────────────────────────────────────────────────────────
print_header

# ─── 2. Verificar dependencias del sistema ────────────────────────────────────
print_step "Verificando dependencias del sistema..."

MISSING_DEPS=()

for dep in curl git unzip; do
  if command_exists "$dep"; then
    print_ok "$dep encontrado"
  else
    print_warn "$dep no encontrado — se intentará instalar"
    MISSING_DEPS+=("$dep")
  fi
done

# Instalar dependencias faltantes
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
  if command_exists apt-get; then
    echo "  Instalando con apt-get..."
    sudo apt-get update -qq
    sudo apt-get install -y "${MISSING_DEPS[@]}" -qq
  elif command_exists brew; then
    echo "  Instalando con Homebrew..."
    brew install "${MISSING_DEPS[@]}"
  else
    print_error "No se pudo instalar automáticamente: ${MISSING_DEPS[*]}"
    print_error "Instálalos manualmente y vuelve a ejecutar el script."
    exit 1
  fi
fi

# ─── 3. Verificar Docker ──────────────────────────────────────────────────────
print_step "Verificando Docker..."

if command_exists docker; then
  DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
  print_ok "Docker $DOCKER_VERSION encontrado"

  if docker info &>/dev/null; then
    print_ok "Docker daemon activo"
  else
    print_warn "Docker no está corriendo. Iniciando..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      open -a Docker
      echo "  Esperando que Docker inicie (30s)..."
      sleep 30
    else
      sudo systemctl start docker 2>/dev/null || true
      sleep 5
    fi
  fi
else
  print_warn "Docker no está instalado."
  echo ""
  echo "  Instala Docker Desktop desde:"
  echo "  https://www.docker.com/products/docker-desktop/"
  echo ""
  echo "  El backend y PostgreSQL no estarán disponibles sin Docker."
  echo "  Puedes continuar para instalar Flutter y Dart."
  echo ""
  read -r -p "  ¿Continuar sin Docker? [s/N] " response
  if [[ ! "$response" =~ ^[sS]$ ]]; then
    exit 1
  fi
fi

# ─── 4. Instalar Flutter SDK ──────────────────────────────────────────────────
print_step "Verificando Flutter SDK..."

FLUTTER_CMD=""

# Buscar flutter en PATH o en directorio de instalación
if command_exists flutter; then
  FLUTTER_CMD="flutter"
  CURRENT_VERSION=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')
  print_ok "Flutter $CURRENT_VERSION encontrado en PATH"
elif [ -d "$FLUTTER_INSTALL_DIR" ] && [ -f "$FLUTTER_INSTALL_DIR/bin/flutter" ]; then
  FLUTTER_CMD="$FLUTTER_INSTALL_DIR/bin/flutter"
  CURRENT_VERSION=$($FLUTTER_CMD --version 2>/dev/null | head -1 | awk '{print $2}')
  print_ok "Flutter $CURRENT_VERSION encontrado en $FLUTTER_INSTALL_DIR"
else
  print_warn "Flutter no encontrado. Instalando Flutter $FLUTTER_VERSION..."

  # Detectar arquitectura y OS
  OS_TYPE="linux"
  ARCH="x64"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
    if [[ "$(uname -m)" == "arm64" ]]; then
      ARCH="arm64"
    fi
  fi

  FLUTTER_ARCHIVE="flutter_${OS_TYPE}_${FLUTTER_VERSION}-stable.tar.xz"
  FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/${OS_TYPE}/${FLUTTER_ARCHIVE}"

  echo "  Descargando Flutter desde:"
  echo "  $FLUTTER_URL"
  echo "  (esto puede tardar varios minutos según tu conexión...)"

  mkdir -p "$(dirname "$FLUTTER_INSTALL_DIR")"
  curl -L --progress-bar "$FLUTTER_URL" -o "/tmp/$FLUTTER_ARCHIVE"
  tar xf "/tmp/$FLUTTER_ARCHIVE" -C "$(dirname "$FLUTTER_INSTALL_DIR")"
  rm "/tmp/$FLUTTER_ARCHIVE"

  FLUTTER_CMD="$FLUTTER_INSTALL_DIR/bin/flutter"
  print_ok "Flutter instalado en $FLUTTER_INSTALL_DIR"

  # Agregar al PATH del perfil de shell
  SHELL_PROFILE=""
  if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_PROFILE="$HOME/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_PROFILE="$HOME/.bashrc"
  elif [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_PROFILE="$HOME/.bash_profile"
  fi

  if [[ -n "$SHELL_PROFILE" ]]; then
    FLUTTER_BIN_PATH="$FLUTTER_INSTALL_DIR/bin"
    if ! grep -q "flutter/bin" "$SHELL_PROFILE" 2>/dev/null; then
      echo "" >> "$SHELL_PROFILE"
      echo "# Flutter SDK" >> "$SHELL_PROFILE"
      echo "export PATH=\"\$PATH:$FLUTTER_BIN_PATH\"" >> "$SHELL_PROFILE"
      print_ok "PATH actualizado en $SHELL_PROFILE"
      print_warn "Ejecuta 'source $SHELL_PROFILE' o abre una nueva terminal después del setup."
    fi
  fi
fi

# Agregar dart al PATH de la sesión actual
DART_BIN_DIR="$(dirname $FLUTTER_CMD)/../cache/dart-sdk/bin"
if [ -d "$DART_BIN_DIR" ]; then
  export PATH="$PATH:$DART_BIN_DIR"
fi
export PATH="$PATH:$(dirname $FLUTTER_CMD)"

DART_CMD="dart"
if ! command_exists dart; then
  DART_CMD="$(dirname $FLUTTER_CMD)/dart"
fi

# ─── 5. Flutter Doctor ────────────────────────────────────────────────────────
print_step "Ejecutando flutter doctor..."
$FLUTTER_CMD doctor --no-version-check 2>/dev/null | head -20 || true

# ─── 6. Configurar .env ───────────────────────────────────────────────────────
print_step "Configurando variables de entorno..."

if [ ! -f "$PROJECT_ROOT/.env" ]; then
  cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
  print_ok ".env creado a partir de .env.example"
else
  print_ok ".env ya existe (no se sobreescribe)"
fi

# ─── 7. Instalar dependencias del Backend ────────────────────────────────────
print_step "Instalando dependencias del Backend (Dart)..."

cd "$PROJECT_ROOT/backend"
$DART_CMD pub get
print_ok "Dependencias del backend instaladas"

# ─── 8. Instalar dependencias del Frontend ───────────────────────────────────
print_step "Instalando dependencias del Frontend (Flutter)..."

cd "$PROJECT_ROOT/frontend"
$FLUTTER_CMD pub get
print_ok "Dependencias del frontend instaladas"

# ─── 9. Habilitar Flutter Web ─────────────────────────────────────────────────
print_step "Verificando soporte de Flutter Web..."
$FLUTTER_CMD config --enable-web &>/dev/null || true
print_ok "Flutter Web habilitado"

# ─── 10. Levantar PostgreSQL con Docker ───────────────────────────────────────
if command_exists docker && docker info &>/dev/null; then
  print_step "Levantando PostgreSQL con Docker Compose..."
  cd "$PROJECT_ROOT"
  docker compose up -d postgres
  print_ok "PostgreSQL iniciado en localhost:5432"
  print_ok "pgAdmin disponible en http://localhost:5050"
fi

# ─── 11. Resumen Final ────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ Setup completado exitosamente!${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Para iniciar el proyecto:${NC}"
echo ""
echo -e "  ${CYAN}# Terminal 1 — Backend:${NC}"
echo "  cd backend"
echo "  dart run bin/server.dart"
echo ""
echo -e "  ${CYAN}# Terminal 2 — Frontend:${NC}"
echo "  cd frontend"
echo "  flutter run -d chrome --web-port 3000"
echo ""
echo -e "  ${CYAN}# URLs:${NC}"
echo "  Backend:  http://localhost:8080"
echo "  Frontend: http://localhost:3000"
echo "  pgAdmin:  http://localhost:5050"
echo ""
echo -e "${YELLOW}${BOLD}Nota:${NC} Si instalaste Flutter en esta sesión, ejecuta:"
echo -e "  ${CYAN}source ~/.zshrc${NC}  (o ~/.bashrc)"
echo "  para actualizar el PATH en tu terminal actual."
echo ""
