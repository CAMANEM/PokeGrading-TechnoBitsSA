---
name: pokegrading-architecture
description: Enforces PokéGrading's layered architecture (Presentación/Aplicación/Dominio/Persistencia), module/feature organization, shared packages, and coding conventions for new implementations.
---

# PokéGrading Architecture & Conventions

## 1. Layered Architecture

The project follows a strict layered architecture with five concerns:

| Layer                     | Directory                          | Responsibility                                    |
|---------------------------|------------------------------------|---------------------------------------------------|
| **Presentación**          | `frontend/lib/presentation/`       | Screens, providers, API clients                   |
| **Aplicación**            | `backend/lib/application/`         | HTTP routes, DI wiring, middleware                |
| **Dominio**               | `backend/lib/domain/`              | Entities, business logic, validation rules        |
| **Persistencia**          | `backend/lib/persistence/`         | Repositories, SQL, external adapters, mocks       |
| **Shared Packages**       | `packages/`                        | Reusable Dart libs (frontend + backend)           |

## 2. Module / Feature Organization

Within each layer, code is organized by `module/feature/`:

```
layer/
└── <module>/          # e.g. user, submitter_catalog, reference_catalog, b2b
    └── <feature>/     # e.g. register, create_card, login, consult
```

### Frontend Convention (`presentation/`)

```
presentation/
└── <module>/
    └── <feature>/
        ├── <feature>_screen.dart      # UI widgets (no business logic)
        ├── <feature>_state.dart       # Screen state model
        ├── <feature>_provider.dart    # ChangeNotifier with presentation logic
        └── <feature>_api.dart         # HTTP client for this feature
```

### Backend Convention (`application/`)

```
application/
├── app_router.dart                    # Global router + middleware composition
├── <module>/<module>_routes.dart      # Maps endpoints -> domain logic
└── <module>/<module>_dependencies.dart # DI wiring for the module
```

### Backend Convention (`domain/`)

```
domain/
└── <module>/
    ├── <entity>.dart                  # Domain entity
    ├── <entity>_repository.dart       # Abstract repository interface
    └── <feature>/<feature>_logic.dart # Use case / business rules
```

### Backend Convention (`persistence/`)

```
persistence/
└── <module>/                          # Concrete implementations (mock, sql, memory, smtp, etc.)
```

## 3. Shared Packages (`packages/`)

- Modules compiled for **both frontend and backend** must live in `packages/`.
- Packages are referenced in `pubspec.yaml` via `path: ../packages/<name>`.
- Keep framework/UI dependencies OUT of packages.
- Naming: `pokegrading_<concern>` (e.g. `pokegrading_logging`, `pokegrading_exceptions`).

## 4. Cross-cutting Rules

### Dependency Direction
- `presentation/` → `*_api.dart` → backend HTTP endpoints
- `application/` → `domain/` → `persistence/`
- `core/` is cross-cutting (config, logging, middleware)
- **No layer skips:** application never calls persistence directly; domain never imports application/http types.
- Shared packages (`packages/`) can be imported by any layer in both frontend and backend.

### Core (`core/`)
- Exists in both `frontend/lib/core/` and `backend/lib/core/`
- Contains: config, logging, theme (frontend), middleware (backend), security (backend)
- No business logic; no knowledge of domain entities

### File Naming
- Dart files: `snake_case.dart`
- Screen files: `<feature>_screen.dart`
- State files: `<feature>_state.dart`
- Provider files: `<feature>_provider.dart`
- API files: `<feature>_api.dart`
- Route files: `<module>_routes.dart` (backend)
- Logic files: `<feature>_logic.dart` (backend)

### State Management (Frontend)
- Always use `ChangeNotifier` + `ChangeNotifierProvider` (via `provider` package)
- State is a separate model class (`*_state.dart`)
- Provider exposes `state` getter and mutates via `notifyListeners()`

### Exception Handling
- Use `LogicException` from `package:pokegrading_exceptions/logic_exception.dart`
- Domain logic throws `LogicException`; application layer catches and maps to HTTP responses
- Frontend API clients catch HTTP errors and rethrow as typed exceptions

### Logging
- Use structured logging via `package:pokegrading_logging`
- Log categories in `LogCategory` (from `log_categories.dart`)
- Correlation context via `CorrelationContext` for request tracing

### Testing
- Backend tests: `backend/test/<module>_test.dart`
- Frontend tests: `frontend/test/presentation/<module>/<feature>_test.dart`
- Mock repositories in `backend/lib/persistence/mocks/` for unit tests

## 5. New Feature Checklist

When adding a new feature, verify:

- [ ] **Backend:** `application/<module>/` routes → `domain/<module>/<feature>/` logic → `persistence/<module>/` adapter. Persistance should never implement logic, it should be focused on SQL queries and retrieve data to domain, where the logic can be implemented.
- [ ] **Frontend:** `presentation/<module>/<feature>/` with screen, state, provider, api
- [ ] **Shared logic** belongs in `packages/pokegrading_<name>/` if used by both frontend and backend
- [ ] **No layer violations:** proper import direction
- [ ] **Tests** in corresponding `test/` directory
- [ ] **pubspec.yaml** dependency paths for local packages use `path: ../packages/<name>`
