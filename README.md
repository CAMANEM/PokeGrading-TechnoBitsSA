# 🎴 PokéGrading — Sistema Asistido de Pre-Grading

> Sistema de pre-grading asistido para cartas Pokémon que analiza el estado de la carta y estima el grado profesional más probable.

[![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-Backend-0175C2?logo=dart)](https://dart.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://www.postgresql.org)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docker.com)

---

## 📐 Arquitectura

El proyecto sigue una **Arquitectura en Capas (Layered Architecture)** con organización **Feature-based**:

```
feature/
├── presentation/    # UI Widgets (Flutter) / Route Handlers (Backend)
├── application/     # Servicios de orquestación y casos de uso
├── domain/          # Modelos, reglas de negocio, interfaces (contratos)
└── infrastructure/  # Repositorios, clientes de APIs externas, DB
```

### Stack Tecnológico

| Capa       | Tecnología                              |
|------------|-----------------------------------------|
| Frontend   | Flutter Web + Riverpod                  |
| Backend    | Dart + Shelf                            |
| Base Datos | PostgreSQL 16 (Single Database)         |
| Infra      | Docker Compose                          |

---

## ⚡ Inicio Rápido (< 20 minutos)

### Pre-requisitos
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y ejecutándose
- Conexión a internet para descargar Flutter SDK (~700MB)

### 🐧 Linux / macOS

```bash
# Clonar el repositorio (si aún no lo has hecho)
git clone https://github.com/TechnoBitsSA/PokeGrading-TechnoBitsSA.git
cd PokeGrading-TechnoBitsSA

# Dar permisos y ejecutar el script de instalación
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### 🪟 Windows (PowerShell como Administrador)

```powershell
# En PowerShell como Administrador
cd PokeGrading-TechnoBitsSA
.\scripts\setup.ps1
```

### 🪟 Windows (CMD / Git Bash)

```bat
scripts\setup.bat
```

---

## 🚀 Levantar el Proyecto (Una vez instalado)

> Antes de iniciar el backend por primera vez, ejecuta `dart pub get` dentro de `backend/` para descargar las dependencias de Dart.

### Opción A: Sin Docker (Recomendado para pruebas rápidas / Sin base de datos local)
Asegúrate de tener `USE_MOCK_REPOSITORIES=true` en tu archivo `.env` (ya configurado por defecto).

```bash
# 1. Iniciar el Backend (Dart/Shelf) en Terminal 1
cd backend
dart run bin/server.dart

# 2. Iniciar el Frontend (Flutter Web) en Terminal 2
cd frontend
flutter run -d chrome --web-port 3000
```

### Opción B: Con Docker (PostgreSQL real)
Asegúrate de tener `USE_MOCK_REPOSITORIES=false` en tu archivo `.env`.

```bash
# 1. Levantar PostgreSQL y pgAdmin
docker compose up -d

# 2. Iniciar el Backend (Dart/Shelf)
cd backend
dart run bin/server.dart

# 3. Iniciar el Frontend (Flutter Web)
cd frontend
flutter run -d chrome --web-port 3000
```

> El backend estará disponible en: http://localhost:8080  
> El frontend estará disponible en: http://localhost:3000  
> Health check: http://localhost:8080/health

---

## 📂 Estructura de Directorios

```
PokeGrading-TechnoBitsSA/
├── backend/                        # Servidor Dart + Shelf
│   ├── bin/
│   │   └── server.dart             # Entry point del servidor
│   ├── lib/
│   │   ├── core/                   # Núcleo compartido del backend
│   │   │   ├── config/             # Configuración (env vars)
│   │   │   ├── logging/            # Logger con correlation_id
│   │   │   └── middleware/         # Middlewares HTTP (CORS, auth, logging)
│   │   └── features/
│   │       ├── auth/               # Feature: Autenticación y usuarios
│   │       │   ├── presentation/   # Route handlers HTTP
│   │       │   ├── application/    # Servicios y casos de uso
│   │       │   ├── domain/         # Modelos, interfaces, reglas de negocio
│   │       │   └── infrastructure/ # Repositorios PostgreSQL
│   │       └── catalog/            # Feature: Catálogo de cartas
│   │           ├── presentation/
│   │           ├── application/
│   │           ├── domain/
│   │           └── infrastructure/
│   └── pubspec.yaml
│
├── frontend/                       # Aplicación Flutter Web
│   ├── lib/
│   │   ├── core/                   # Núcleo compartido del frontend
│   │   │   ├── config/             # URLs de API, constantes
│   │   │   ├── theme/              # Design System (colores, tipografía)
│   │   │   └── utils/              # Helpers, formatters
│   │   ├── features/
│   │   │   ├── auth/               # Feature: Autenticación
│   │   │   │   ├── presentation/   # Screens y Widgets
│   │   │   │   ├── application/    # Providers/BLoC + casos de uso
│   │   │   │   ├── domain/         # Modelos de dominio
│   │   │   │   └── infrastructure/ # Clientes HTTP (API calls)
│   │   │   └── catalog/            # Feature: Catálogo de cartas
│   │   │       ├── presentation/
│   │   │       ├── application/
│   │   │       ├── domain/
│   │   │       └── infrastructure/
│   │   └── main.dart               # Entry point
│   ├── web/
│   └── pubspec.yaml
│
├── docs/
│   └── adr/
│       └── ADR-001-arquitectura.md # Architecture Decision Record
│
├── scripts/
│   ├── setup.sh                    # Script de instalación Linux/macOS
│   ├── setup.ps1                   # Script de instalación Windows (PowerShell)
│   └── setup.bat                   # Script de instalación Windows (CMD)
│
├── docker-compose.yml              # PostgreSQL + pgAdmin
├── .env.example                    # Variables de entorno de ejemplo
└── README.md
```

---

## 🧪 Verificar que funciona

```bash
# Health check del backend
curl http://localhost:8080/health

# Respuesta esperada:
# {"status":"ok","service":"pokegrading-backend","version":"0.1.0"}
```

---

## 🛠️ Roles de Usuario

| Rol                | Descripción                                    |
|--------------------|------------------------------------------------|
| `Submitter`        | Envía cartas para pre-grading                  |
| `Reviewer`         | Revisa y valida cartas y evaluaciones          |
| `Admin`            | Gestión completa + doble verificación          |
| `B2B Service Account` | Acceso programático vía API Key            |

---

## 📋 Variables de Entorno

Copia `.env.example` a `.env` y ajusta los valores:

```bash
cp .env.example .env
```

---

## 🤝 Contribución

Ver [docs/adr/ADR-001-arquitectura.md](docs/adr/ADR-001-arquitectura.md) para los lineamientos de arquitectura.
