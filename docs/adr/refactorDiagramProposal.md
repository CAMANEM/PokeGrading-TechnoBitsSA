# Folder Structure Proposal (refactor)

> Base layout: **layer → module → flow**. The `.dart` files listed are examples, not all required on day one.

## General rules

```
<env>/lib/
└── <layer>/
    └── <module>/          # user, submitter_catalog, reference_catalog
        └── <feature>/     # login, register, create_card, …
```

**Backend dependencies:** `application → domain ← persistence`  
**Cross-cutting gateway:** `core/` (config, logging, middleware)

**Logical layers (not always present in every repo):**

| Layer        | Frontend                         | Backend                    |
|--------------|----------------------------------|----------------------------|
| Presentation | `presentation/` (UI, state, API, go_router) | —              |
| Application  | —                                | `application/` (HTTP routes + light orchestration) |
| Domain       | —                                | `domain/`                  |
| Persistence  | —                                | `persistence/`             |

---

## Frontend (thin)

Only **Presentation** as the main layer. Non-screen code is **colocated** in the same flow folder (Option A).

```text
frontend/lib/
├── core/                          # theme, config, utils
└── presentation/
    ├── app_router.dart            # global go_router (mounts all module routes)
    ├── home/
    │   ├── home_screen.dart
    │   └── home_api.dart
    ├── user/
    │   ├── login/                 # future
    │   │   ├── login_screen.dart
    │   │   ├── login_provider.dart
    │   │   └── login_api.dart
    │   └── register/
    │       ├── register_screen.dart
    │       ├── register_provider.dart   # ChangeNotifier, not Riverpod
    │       └── register_api.dart
    ├── submitter_catalog/
    │   ├── create_card/
    │   │   ├── create_card_screen.dart
    │   │   ├── create_card_provider.dart
    │   │   └── create_card_api.dart
    │   ├── edit_card/             # future
    │   └── grading/               # future
    └── reference_catalog/         # scaffold for future implementation
```

**FE convention (Option A):** everything under `presentation/` — screen, provider, API, and navigation (`app_router.dart` at the root of `presentation/`). No `application/`, `domain/`, or `persistence/` folders on the frontend.

---

## Backend

```text
backend/lib/
├── core/                          # config, logging, middleware (Gateway)
│
├── application/                   # Routing + API mounting
│   ├── app_router.dart            # mounts /api/v1, /health, DI
│   ├── user/
│   │   ├── login_routes.dart      # future
│   │   └── register_routes.dart
│   └── submitter_catalog/
│       └── create_card_routes.dart
│
├── domain/                        # Business logic
│   ├── user/
│   │   ├── user.dart              # shared module entity
│   │   ├── user_repository.dart   # contract (interface)
│   │   ├── user_validators.dart
│   │   └── register/
│   │       └── register_logic.dart
│   └── submitter_catalog/
│       └── create_card/
│           └── create_card_logic.dart
│
└── persistence/                   # Data access
    ├── user/
    │   ├── postgres_user_repository.dart   # implements user_repository
    │   ├── memory_user_repository.dart     # dev / tests
    │   └── smtp_confirmation_sender.dart   # external adapter (email)
    ├── submitter_catalog/
    │   ├── mock_catalog_repository.dart
    │   └── id_generator.dart
    └── reference_catalog/         # scaffold for future implementation
```

---

## Naming in `persistence/`

| Pattern | When to use |
|---------|-------------|
| `postgres_<module>_repository.dart` | Implementation of the contract defined in `domain/` |
| `memory_<module>_repository.dart` | Mocks / dev without PostgreSQL |
| `<module>_sql.dart` | SQL strings or helpers **for the module** (e.g. `user_sql.dart`) |
| `login_sql.dart` | Only when login SQL is **not** shared with register/setup |

Routes call `*_logic.dart` (domain); logic uses the **repository**, never imports `*_sql.dart` directly from `application/`.

---

## Example flow (register)

```text
presentation/user/register/register_screen.dart
    → register_provider.dart (ChangeNotifier)
        → register_api.dart  ──HTTP──►  application/user/register_routes.dart
                                            → domain/user/register/register_logic.dart
                                                → domain/user/user_repository.dart
                                                    ← persistence/user/memory_user_repository.dart
```

---

## Overall structure (summary)

```
<env>/lib/
├── layer/              # presentation | application | domain | persistence
│   └── module/         # user | submitter_catalog | reference_catalog
│       └── feature/    # login | register | create_card | …
```

**Frontend:** `core/` + `presentation/` only (includes `app_router.dart`).  
**Backend:** `core/` + `application/`, `domain/`, `persistence/`.
