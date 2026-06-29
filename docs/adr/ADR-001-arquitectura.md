# ADR-001: Arquitectura del Sistema PokéGrading


- **Status:** accepted
- **Deciders:** Equipo de Desarrollo (4 integrantes)
- **Date:** 2026-05-16

**Technical Story:** Definición de la arquitectura base para el sistema PokéGrading.

---

## Context and Problem Statement

El sistema **PokéGrading** requiere una arquitectura que permita desarrollar un servicio de pre-grading asistido para cartas Pokémon, soportando procesamiento de imágenes, versionado de scoring, auditoría y comunicación con servicios externos.

La solución debe operar bajo una restricción presupuestaria de **$800 mensuales**, permitiendo además escalabilidad futura y mantenibilidad para un equipo reducido de desarrollo. El equipo está constituído por tan solo 4 desarrolladores y se afrontarán sprints agresivos y cortos.

---

## Decision Drivers

- Mantener costos operativos por debajo de $800/mes.
- Reducir complejidad operativa para un equipo de 4 personas.
- Garantizar mantenibilidad y velocidad de desarrollo.
- Permitir escalabilidad futura sin rediseño completo.
- Facilitar integración con APIs externas y procesamiento de imágenes.
- Garantizar trazabilidad e integridad de evaluaciones históricas.

---

## Considered Options

- Arquitectura en Capas (Layered Architecture)
- Microservicios
- Arquitectura Basada en Eventos (EDA)

---

## Decision Outcome

Chosen option: **"Arquitectura en Capas (Layered Architecture)"**, porque ofrece el mejor balance entre simplicidad, mantenibilidad, velocidad de desarrollo y costos operativos para la etapa inicial del proyecto.

La arquitectura se organiza en capas de:

- Presentación
- Lógica de negocio
- Acceso a datos
- Infraestructura

### Folder Structure (layer → module → flow)

Since Sprint 1 refactor, the codebase follows [refactorDiagramProposal.md](refactorDiagramProposal.md):

| Layer | Frontend | Backend |
|-------|----------|---------|
| Presentation | `presentation/` (screen, ChangeNotifier provider, API client, go_router) | — |
| Application | — | `application/` (HTTP routes, light orchestration) |
| Domain | — | `domain/` (entities, validators, `*_logic.dart`) |
| Persistence | — | `persistence/` (repositories, SQL, external adapters) |

**Modules:** `user`, `submitter_catalog`, `reference_catalog` (scaffold only).

**Frontend is thin:** no separate `application/`, `domain/`, or `persistence/` folders — flow state and HTTP clients are colocated under each feature folder inside `presentation/`.

**Backend dependency rule:** `application → domain ← persistence`. Shared gateway code lives in `core/`.

### Acceso a Datos

La base de datos es fundacional, con su respectiva capa de acceso a datos, implementando buenas prácticas de programación como Views y Store Procedures.

### Positive Consequences

- Menor complejidad técnica y operativa.
- Despliegue simplificado en Azure.
- Desarrollo más rápido para el Sprint 1.
- Facilita mantenimiento por parte de un equipo pequeño.
- Reduce costos de infraestructura y monitoreo.

### Negative Consequences

- Posible over-engineering para features muy simples.
- Mayor acoplamiento entre módulos si no se mantienen interfaces claras.
- Escalabilidad limitada comparada con microservicios.

---

## Pros and Cons of the Options

### Arquitectura en Capas (Seleccionada)

Arquitectura organizada por responsabilidades técnicas.

#### Pros

- Fácil implementación inicial.
- Menor costo operativo.
- Menor curva de aprendizaje.
- Simplifica testing y debugging.

#### Cons

- Puede generar fuerte acoplamiento entre capas.
- Riesgo de crecimiento monolítico.
- Escalabilidad funcional limitada.

---

### Microservicios

Arquitectura distribuida basada en servicios independientes.

#### Pros

- Alta escalabilidad.
- Aislamiento de fallos.
- Despliegues independientes.

#### Cons

- Mayor complejidad operativa.
- Incremento significativo en costos cloud.
- Mayor esfuerzo en observabilidad y CI/CD.

---

### Arquitectura Basada en Eventos (EDA)

Arquitectura orientada a eventos y procesamiento asíncrono.

#### Pros

- Alto desacoplamiento.
- Excelente manejo de procesos asíncronos.
- Buena resiliencia ante fallos.

#### Cons

- Mayor complejidad arquitectónica.
- Curva de aprendizaje elevada.
- Más difícil de depurar y monitorear.