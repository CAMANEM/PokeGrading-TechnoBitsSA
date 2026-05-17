# ADR-001: Arquitectura del Sistema PokéGrading

| Campo       | Valor                                |
|-------------|--------------------------------------|
| **Número**  | ADR-001                              |
| **Título**  | Arquitectura en Capas Feature-Based  |
| **Estado**  | ✅ Aceptado                          |
| **Fecha**   | 2026-05-01                           |
| **Autores** | Equipo TechnoBits SA                 |

---

## Contexto

El proyecto PokéGrading requiere un sistema escalable que soporte múltiples roles de usuario, flujos de validación complejos y la integración futura con modelos de análisis de imagen para grading automático de cartas Pokémon.

Se necesita una arquitectura que:
- Permita crecer sin refactorizaciones masivas
- Mantenga el código testeable y mantenible
- Separe claramente las responsabilidades
- Soporte al equipo de desarrollo con distintas especialidades

## Decisión

Se adopta una **Arquitectura en Capas (Layered Architecture) técnicamente particionada**, organizada mediante un enfoque **Feature-Based (por funcionalidades)**.

### Estructura de Capas por Feature

Cada feature contiene las siguientes capas:

```
features/<nombre>/
├── presentation/    # Capa de Presentación
├── application/     # Capa de Aplicación
├── domain/          # Capa de Dominio
└── infrastructure/  # Capa de Infraestructura
```

### Responsabilidades por Capa

| Capa | Responsabilidad | Ejemplos |
|------|-----------------|---------|
| **Presentation** | UI Widgets / Route Handlers HTTP | Screens, Forms, API endpoints |
| **Application** | Orquestación y casos de uso | Services, Providers (Riverpod), BLoC |
| **Domain** | Modelos y reglas de negocio puras | Entidades, Interfaces (contratos), Validators |
| **Infrastructure** | Implementaciones externas | Repositorios PostgreSQL, clientes HTTP |

### Reglas de Dependencia (Dependency Rule)

```
Presentation → Application → Domain ← Infrastructure
```

- **Domain** no depende de NINGUNA otra capa (es el núcleo)
- **Infrastructure** implementa las interfaces definidas en Domain
- **Application** coordina Domain e Infrastructure
- **Presentation** solo consume Application

### Stack Tecnológico

| Componente | Tecnología | Justificación |
|------------|------------|---------------|
| Frontend | Flutter Web | Multiplataforma, rendimiento, Dart unificado |
| Estado (Frontend) | Riverpod | Tipado, testeable, sin boilerplate excesivo |
| Backend | Dart + Shelf | Mismo lenguaje que frontend, bajo overhead |
| Base de Datos | PostgreSQL 16 | ACID, soporte JSON, extensible |
| Contenerización | Docker Compose | Reproducibilidad local |

## Consecuencias

### ✅ Positivas
- **Alta cohesión**: cada feature encapsula toda su lógica
- **Bajo acoplamiento**: interfaces definen contratos, no implementaciones
- **Testabilidad**: Domain es puro Dart, fácil de unit-testear
- **Escalabilidad del equipo**: distintos desarrolladores trabajan en distintas features sin conflictos
- **Evolutividad**: cambiar PostgreSQL por otro motor solo requiere tocar Infrastructure

### ⚠️ Trade-offs
- Más archivos iniciales vs. una arquitectura plana
- Curva de aprendizaje para el equipo si no conoce Layered Architecture
- Posible over-engineering para features muy simples (aceptable dado el alcance del proyecto)

## Alternativas Consideradas

| Alternativa | Razón de rechazo |
|-------------|-----------------|
| MVC plano | No escala bien, mezcla responsabilidades |
| Clean Architecture estricta | Demasiado ceremonial para el tamaño del equipo |
| Monolito sin capas | Dificulta testing y mantenimiento |
| Microservicios | Complejidad operacional innecesaria en Sprint 1 |

## Principios de Calidad Aplicados

- **[SP1] Seguridad por defecto**: JWT, hashing bcrypt, CORS configurado
- **[SP2] Consultas parametrizadas**: Evitar SQL injection en todos los repositorios
- **[SP3] Validación de entrada**: Tamaño y tipo de archivos validados en Application layer
- **[S1] Configuración < 20 min**: Scripts de setup automatizado para Linux y Windows
- **[CBS-1.2.1] Doble verificación Admin**: Flujo implementado en Application layer
- **[CBS-1.2.3] API Key B2B**: Generación en Domain layer, persistencia en Infrastructure

---
