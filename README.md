# 🎴 PokéGrading — Sistema Asistido de Pre-Grading

> Sistema de pre-grading asistido para cartas Pokémon que analiza el estado de la carta y estima el grado profesional más probable.

[![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-Backend-0175C2?logo=dart)](https://dart.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://www.postgresql.org)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docker.com)

---

## 📐 Arquitectura

El proyecto sigue una **Arquitectura en Capas (Layered Architecture)**:

```mermaid
graph TD

    %% CAPAS
    subgraph P_Presentation_Layer["Presentation Layer"]
        direction TB
        P_USER["Submitter UI"]
        P_B2B["B2B UI"]
        P_ADMIN["Administrator UI"]
    end

    subgraph A_Application_Layer["Application Layer"]
        direction TB
        Gateway["API Gateway / Middleware"]
        Orchestrator["Routers / Orchestrators"]
    end

    subgraph D_Domain_Layer["Domain Layer"]
        direction TB
        D_USER["Identity & Access"]
        D_CATALOG["Catalog"]
        Grading_Engine["Scoring Heuristics"]
        D_Auditoria["Audit, Logs & Playbook"]
        Market_Engine["Human Management"]
        Market_Engine2["Economic Management"]
    end

    subgraph Data_Access_Layer["Data Access Layer"]
        direction TB
        CatalogRepo["User Data Provider"]
        EvalRepo["Letter Data Provider"]
        BlobManager["Image Provider"]
        BlobManager2["Audit Data Provider"]
    end

    subgraph Data_Layer["Data Sources / External"]
        direction TB
        DB_Catalog[("Reference Catalog DB")]
    end

    %% RELACIONES
    P_Presentation_Layer --> A_Application_Layer
    Gateway --> Orchestrator
    Orchestrator --> D_Domain_Layer
    D_Domain_Layer --> Data_Access_Layer
    Data_Access_Layer --> Data_Layer

    %% ESTILO SOBRIO BLANCO Y NEGRO
    classDef presentation fill:#ffffff,stroke:#111111,color:#111111,stroke-width:1.5px;
    classDef services fill:#f5f5f5,stroke:#111111,color:#111111,stroke-width:1.5px;
    classDef business fill:#fafafa,stroke:#111111,color:#111111,stroke-width:1.5px;
    classDef dataaccess fill:#f0f0f0,stroke:#111111,color:#111111,stroke-width:1.5px;
    classDef datasource fill:#eaeaea,stroke:#111111,color:#111111,stroke-width:1.5px;

    class P_USER,P_B2B,P_ADMIN presentation;
    class Gateway,Orchestrator services;
    class D_USER,D_CATALOG,Grading_Engine,D_Auditoria,Market_Engine,Market_Engine2 business;
    class CatalogRepo,EvalRepo,BlobManager,BlobManager2 dataaccess;
    class DB_Catalog datasource;

    style P_Presentation_Layer fill:#ffffff,stroke:#222222,stroke-width:2px,color:#111111
    style A_Application_Layer fill:#fcfcfc,stroke:#222222,stroke-width:2px,color:#111111
    style D_Domain_Layer fill:#ffffff,stroke:#222222,stroke-width:2px,color:#111111
    style Data_Access_Layer fill:#fcfcfc,stroke:#222222,stroke-width:2px,color:#111111
    style Data_Layer fill:#ffffff,stroke:#222222,stroke-width:2px,color:#111111

    linkStyle default stroke:#222222,stroke-width:1.5px,color:#222222
```

En la estructura de código se sigue dicha estructura de la siguiente forma:

```
layer/
└── module/          # user, submitter_catalog, reference_catalog
    └── feature/     # register, create_card, login, …
```

- **Frontend (delgado):** solo `core/` + `presentation/` — pantalla, provider (`ChangeNotifier`), API y rutas colocalizados por flujo.
- **Backend:** `core/` + `application/` (HTTP routes) + `domain/` (lógica de negocio) + `persistence/` (repositorios, SQL, adaptadores externos).

Ver [docs/adr/refactorDiagramProposal.md](docs/adr/refactorDiagramProposal.md) para el detalle completo.

### Stack Tecnológico

| Capa       | Tecnología                              |
|------------|-----------------------------------------|
| Frontend   | Flutter Web + go_router + ChangeNotifier |
| Backend    | Dart + Shelf                            |
| Base Datos | PostgreSQL 16 + MongoDB 7               |
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

## 🗄️ Databases (PostgreSQL + MongoDB)

PostgreSQL stores metadata (users, cards, hashes, pre-grades). MongoDB stores image binaries via GridFS.

On first start with an empty Docker volume, PostgreSQL is initialized from [`backend/db/init/`](backend/db/init/) (`001_schema.sql` then `002_seed_lookups.sql`). MongoDB runs [`backend/db/mongodb/create_pokegrading_images.js`](backend/db/mongodb/create_pokegrading_images.js) automatically when its volume is empty.

Legacy schemas under `backend/db/migrations/` are no longer used by Docker init.

### Windows

```powershell
scripts\db.bat
```

### Linux / macOS

```bash
chmod +x scripts/db.sh
./scripts/db.sh
```

To recreate both databases from scratch, stop and remove volumes first:

```bash
docker compose down -v
docker compose up -d
```

Manual MongoDB init (only if the Mongo volume already existed before adding the init script):

```bash
mongosh "mongodb://localhost:27017/pokegrading_images" backend/db/mongodb/create_pokegrading_images.js
```

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

### Opción B: Con Docker (PostgreSQL + MongoDB reales)
Asegúrate de tener `USE_MOCK_REPOSITORIES=false` en tu archivo `.env`.

```bash
# 1. Levantar PostgreSQL, MongoDB y pgAdmin. You need to have Docker opened
docker compose up -d

# 2. Iniciar el Backend (Dart/Shelf)
cd backend
dart pub get
dart run bin/server.dart

# 3. Iniciar el Frontend (Flutter Web)
cd frontend
flutter run -d chrome --web-port 3000
```

> El backend estará disponible en: http://localhost:8080  
> El frontend estará disponible en: http://localhost:3000  
> Health check: http://localhost:8080/health

---

# Consulta a DB desde el directorio principal del repo

**PostgreSQL**

```bash
docker exec -it pokegrading_postgres psql -U pokegrading_user -d pokegrading
```
```bash
SELECT id, username, email, registration_date FROM submitter;
```
```bash
\q
```

**MongoDB**

```bash
docker exec -it pokegrading_mongodb mongosh pokegrading_images --eval "db.submitter_images.find().limit(5)"
```


## 📂 Estructura de Directorios

```
PokeGrading-TechnoBitsSA/
├── backend/                        # Servidor Dart + Shelf
│   ├── bin/
│   │   └── server.dart             # Entry point (bootstrap)
│   ├── lib/
│   │   ├── core/                   # config, logging, middleware
│   │   ├── application/            # HTTP routes + DI wiring
│   │   │   ├── app_router.dart
│   │   │   ├── user/
│   │   │   │   └── register_routes.dart
│   │   │   └── submitter_catalog/
│   │   │       └── create_card_routes.dart
│   │   ├── domain/                 # Business logic
│   │   │   ├── user/
│   │   │   │   ├── register/register_logic.dart
│   │   │   │   ├── user.dart
│   │   │   │   └── user_repository.dart
│   │   │   └── submitter_catalog/
│   │   │       └── create_card/create_card_logic.dart
│   │   └── persistence/            # Repositories, SQL, external adapters
│   │       ├── user/
│   │       └── submitter_catalog/
│   └── pubspec.yaml
│
├── frontend/                       # Aplicación Flutter Web
│   ├── lib/
│   │   ├── core/                   # config, theme
│   │   ├── presentation/
│   │   │   ├── app_router.dart     # go_router global
│   │   │   ├── home/
│   │   │   ├── user/register/      # screen + provider + api
│   │   │   └── submitter_catalog/create_card/
│   │   └── main.dart
│   ├── web/
│   └── pubspec.yaml
│
├── docs/
│   └── adr/
│       ├── ADR-001-arquitectura.md
│       └── refactorDiagramProposal.md
│
├── scripts/
│   ├── setup.sh
│   ├── setup.ps1
│   └── setup.bat
│
├── docker-compose.yml
├── .env.example
└── README.md
```

# Estructura frontend:
```
└── presentation/                 # Business logic
    └── module/
        └── feature
            ├── *_screen.dart      # Pantalla / UI: widgets que renderizan la interfaz y manejan la interacción del usuario.
            ├── *_state.dart       # Estado: modelos que representan el estado de la pantalla (valores, etapa del flujo, resultados).
            ├── *_provider.dart    # Provider: `ChangeNotifier` que contiene la lógica de presentación, orquesta acciones y expone el `state` a la UI.
            └── *_api.dart         # API: clientes HTTP que comunican con el backend; convierten respuestas y lanzan excepciones manejables.
```

# Estructura backend:
```
└── backend/lib/                   # Código del servidor
    ├── core/                      # Configuración y utilidades compartidas (logger, config, middleware)
    ├── application/               # Rutas HTTP, wiring de dependencias y adaptadores de entrada (handlers/controllers)
    │   ├── app_router.dart        # Orquestador de rutas y composición de middlewares
    │   └── <module>/_routes.dart  # Mapea endpoints a la lógica de dominio
    ├── domain/                    # Lógica de negocio: entidades, validadores y casos de uso (use-cases)
    │   └── <module>/              # Ej: `create_card_logic.dart` contiene las reglas de negocio del flujo
    └── persistence/               # Adaptadores de datos: repositorios, SQL y proveedores externos
        └── <module>/              # Implementaciones concretas (mock, memory, SQL, SMTP, etc.)
```



---

# MongoDB proposed structure

Connection between PostgreSQL and MongoDB
There's no foreign key or live link between the two databases — card_submitter.id (and card_reference.id) simply acts as a shared key that the application uses to query both. When the app needs a card's images, it takes that bigint ID and queries MongoDB's submitter_images (or reference_images) collection with { card_submitter_id: <id> }, getting back the front and back documents. It's an application-level join, not a database-enforced one.

MongoDB structure

```
pokegrading_images/
├── submitter_images          → metadata docs: {card_submitter_id, side: "front"/"back", file_id, content_type, ...}
├── reference_images           → same idea, keyed by card_reference_id
├── submitter_fs.files/.chunks  → GridFS binary storage (front/back images)
└── reference_fs.files/.chunks  → GridFS binary storage
```

Each card has two metadata documents (one per side), each pointing via file_id to the actual image bytes stored in GridFS. Splitting by origin (submitter/reference) keeps the high-churn user uploads separate from the curated reference set, while the side field + index lets you query front/back together or separately as needed.

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

For real databases, set `USE_MOCK_REPOSITORIES=false` and configure PostgreSQL (`DB_*`) plus MongoDB (`MONGO_URI`, `MONGO_DB_NAME`).

> Search trace persistence is disabled; `/api/v1/catalog/search-traces` returns an empty list with real repositories.

Para que el token llegue a un correo real, configura también las variables SMTP del backend en `.env`:

```bash
SMTP_HOST=...
SMTP_PORT=587
SMTP_USERNAME=...
SMTP_PASSWORD=...
SMTP_FROM_EMAIL=no-reply@pokegrading.com
SMTP_FROM_NAME=PokéGrading
SMTP_USE_SSL=false
```

Si SMTP no está configurado, el backend arranca igual pero solo registra el intento en logs y no entrega el correo.
---

## 🤝 Contribución

Ver [docs/adr/ADR-001-arquitectura.md](docs/adr/ADR-001-arquitectura.md) para los lineamientos de arquitectura.
