# Cómo Hacer Test - Grading System

## Descripción

Este documento explica cómo probar el sistema de grading completo de PokéGrading, incluyendo:
- Detección de whitening en esquinas (con detección de bordes blancos)
- Detección de defectos en bordes (con detección de bordes blancos)
- Detección de rayas en superficie
- Análisis de calidad mejorado (Tenengrad + Entropía)
- Cálculo de grade final ponderado (pesos BGS estándar)
- Regla de coherencia (final ≤ subgrado más bajo + 0.5)
- Banda de incertidumbre
- Baselines calibrados por (set, finish)
- Idempotencia en el endpoint de grading
- Endpoint de calibración

## Prerequisitos

1. Tener el backend corriendo
2. Tener una imagen de una carta Pokémon en formato base64 o URL

## Endpoints Disponibles

### 1. Endpoint de Grading Completo

**URL:** `POST /api/v1/scoring/grade`

**Descripción:** Realiza preprocessing + grading completo de una carta. Acepta identidad de carta (set, finish) para seleccionar baseline calibrado.

**Request Body:**
```json
{
  "image_data": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
  "set_name": "SVP",
  "finish": "holo",
  "idempotency_key": "optional-client-key"
}
```

Campos opcionales:
- `set_name`: Nombre del set de la carta (para selección de baseline calibrado)
- `finish`: Tipo de acabado (holo, reverse, normal, etc.)
- `idempotency_key`: Clave de idempotencia del cliente (opcional)

**Response Exitoso (200):**
```json
{
  "success": true,
  "grading": {
    "centering_grade": 8.22,
    "corners": {
      "corners": [
        {"position": "top_left", "whitening_score": 0.0, "whitening_percentage": 0.0, "passes": true},
        {"position": "top_right", "whitening_score": 0.0, "whitening_percentage": 0.0, "passes": true},
        {"position": "bottom_left", "whitening_score": 0.0, "whitening_percentage": 0.0, "passes": true},
        {"position": "bottom_right", "whitening_score": 0.0, "whitening_percentage": 0.0, "passes": true}
      ],
      "grade": 10.0,
      "average_whitening": 0.0,
      "passed_count": 4
    },
    "edges": {
      "edges": [
        {"position": "top", "whitening_score": 0.05, "straightness_score": 0.95, "quality_score": 0.92, "whitening_percentage": 0.5, "passes": true},
        {"position": "bottom", "whitening_score": 0.1, "straightness_score": 0.9, "quality_score": 0.88, "whitening_percentage": 0.8, "passes": true},
        {"position": "left", "whitening_score": 0.0, "straightness_score": 0.98, "quality_score": 0.98, "whitening_percentage": 0.2, "passes": true},
        {"position": "right", "whitening_score": 0.02, "straightness_score": 0.97, "quality_score": 0.97, "whitening_percentage": 0.3, "passes": true}
      ],
      "grade": 8.47,
      "average_quality": 0.84,
      "passed_count": 4
    },
    "surface": {
      "scratch_score": 0.85,
      "print_line_score": 0.92,
      "uniformity_score": 0.88,
      "grade": 8.75,
      "quality_score": 0.87,
      "scratch_count": 2,
      "passes": true
    },
    "final_grade": 8.72,
    "confidence": 0.92,
    "explanation": "Carta en excelente estado. Grade estimado: 8.7/10",
    "baseline_version": "global_v1.0",
    "baseline_is_calibrated": false,
    "baseline_set": null,
    "baseline_finish": null,
    "baseline_reference_card_count": 0,
    "grade_lower_bound": 8.22,
    "grade_upper_bound": 9.22,
    "coherence_rule_applied": true,
    "lowest_subgrade": 8.22
  },
  "quality": {
    "score": 78.5,
    "laplacian_sharpness": 0.85,
    "tenengrad_sharpness": 0.82,
    "brightness": 0.95,
    "entropy": 0.78,
    "contrast": 0.88,
    "passes": true,
    "rejection_reasons": []
  },
  "metadata": {
    "preprocessing_ms": 450,
    "grading_ms": 120,
    "algorithm_version": "1.0.0"
  },
  "correlation_id": "abc-123"
}
```

Campos nuevos en la respuesta:
- `baseline_version`: Versión del baseline utilizado
- `baseline_is_calibrated`: true si se usó un baseline calibrado para el (set, finish)
- `grade_lower_bound` / `grade_upper_bound`: Banda de incertidumbre del grade
- `coherence_rule_applied`: true si la regla de coherencia ajustó el grade
- `lowest_subgrade`: El subgrado más bajo (referencia para la regla de coherencia)

### 2. Endpoint de Calibración

**URL:** `POST /api/v1/scoring/calibrate`

**Descripción:** Calibra un baseline para un (set, finish) específico usando un dataset de cartas con grades de PSA confirmados. Requiere mínimo 15 cartas para activar el baseline calibrado.

**Request Body:**
```json
{
  "set_name": "Base Set",
  "finish": "holo",
  "description": "Calibración con 25 cartas Charizard PSA",
  "cards": [
    {
      "psa_grade": 10.0,
      "features": {
        "centering_symmetry": 0.95,
        "corner_whitening_percentages": [0.0, 0.0, 0.0, 0.0],
        "edge_whitening_percentages": [0.0, 0.0, 0.0, 0.0],
        "edge_straightness_cvs": [0.05, 0.05, 0.05, 0.05],
        "surface_scratch_density": 0.0,
        "surface_uniformity_cv": 0.2
      }
    },
    {
      "psa_grade": 8.0,
      "features": {
        "centering_symmetry": 0.85,
        "corner_whitening_percentages": [0.5, 0.3, 0.2, 0.4],
        "edge_whitening_percentages": [0.1, 0.2, 0.1, 0.15],
        "edge_straightness_cvs": [0.1, 0.12, 0.08, 0.1],
        "surface_scratch_density": 0.01,
        "surface_uniformity_cv": 0.35
      }
    }
  ]
}
```

**Response Exitoso (200):**
```json
{
  "success": true,
  "calibration": {
    "set_name": "Base Set",
    "finish": "holo",
    "baseline_version": "base_set_holo_v1.0",
    "card_count": 25,
    "has_sufficient_ground_truth": true,
    "average_psa_grade": 8.2,
    "psa_grade_std_dev": 1.5,
    "quality_score": 0.85,
    "warnings": [],
    "registered": true
  },
  "correlation_id": "abc-123"
}
```

### 3. Endpoint de Preprocessing (solo)

**URL:** `POST /api/v1/scoring/preprocess`

**Descripción:** Solo realiza preprocessing (detección de contorno + corrección de perspectiva + normalización de color + extracción de ROIs).

**Request Body:**
```json
{
  "image_data": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
}
```

## Cómo Probar con curl

### Prueba Rápida (Windows PowerShell)

```powershell
# 1. Guarda tu imagen como test_card.jpg

# 2. Convierte a base64
$base64Image = [Convert]::ToBase64String([IO.File]::ReadAllBytes("test_card.jpg"))

# 3. Envía request de grading
$body = @{
    image_data = "data:image/jpeg;base64,$base64Image"
    set_name = "SVP"
    finish = "holo"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/v1/scoring/grade" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

### Prueba de Idempotencia

```powershell
# Enviar el mismo request con idempotency_key
$body = @{
    image_data = "data:image/jpeg;base64,$base64Image"
    idempotency_key = "my-unique-request-123"
} | ConvertTo-Json

# Primer request - ejecuta el grading completo
$resp1 = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/scoring/grade" `
    -Method POST -ContentType "application/json" -Body $body

# Segundo request - retorna la respuesta cacheada (idempotent_replay: true)
$resp2 = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/scoring/grade" `
    -Method POST -ContentType "application/json" -Body $body

# Verificar que es una replay
Write-Host "Replay: $($resp2.idempotent_replay)"  # True
```

### Prueba de Calibración

```powershell
$body = @{
    set_name = "Base Set"
    finish = "holo"
    description = "Calibración de prueba"
    cards = @(
        @{
            psa_grade = 10.0
            features = @{
                centering_symmetry = 0.95
                corner_whitening_percentages = @(0, 0, 0, 0)
                edge_whitening_percentages = @(0, 0, 0, 0)
                edge_straightness_cvs = @(0.05, 0.05, 0.05, 0.05)
                surface_scratch_density = 0
                surface_uniformity_cv = 0.2
            }
        }
    )
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "http://localhost:8080/api/v1/scoring/calibrate" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

### Prueba con curl (Linux/Mac)

```bash
# 1. Guarda tu imagen como test_card.jpg

# 2. Convierte a base64
BASE64_IMAGE=$(base64 -i test_card.jpg)

# 3. Envía request de grading
curl -X POST http://localhost:8080/api/v1/scoring/grade \
  -H "Content-Type: application/json" \
  -d "{\"image_data\": \"data:image/jpeg;base64,$BASE64_IMAGE\"}" | jq .
```

## Métricas Explicadas

### 1. Centering (40% del grade final)
- **Métrica:** Simetría de bordes (detección de varianza)
- **Escala:** 1.0 (muy desalineado) a 10.0 (perfectamente centrado)
- **Método:** Escaneo de bordes buscando transiciones artwork/border

### 2. Corners (20% del grade final)
- **Métrica:** Whitening (blanqueamiento)
- **Escala:** 0.0 (perfecto) a 1.0 (severe whitening)
- **Método:** Detección de bordes blancos + análisis de brillo
- **Protección:** Las cartas con bordes blancos son NORMALES — se detecta y omite automáticamente

### 3. Edges (20% del grade final)
- **Métrica:** Whitening + Rectitud
- **Escala:** 0.0 (defectuoso) a 1.0 (perfecto)
- **Método:** Combinación de detección de whitening + análisis de rectitud con Sobel
- **Ponderación:** 60% whitening, 40% rectitud

### 4. Surface (20% del grade final)
- **Métrica:** Rayas + Líneas de impresión + Uniformidad
- **Escala:** 0.0 (muchos defectos) a 1.0 (sin defectos)
- **Método:** Análisis de gradiente + perfiles de proyección + varianza local
- **Ponderación:** 50% rayas, 25% líneas impresión, 25% uniformidad

### 5. Regla de Coherencia (BGS Estándar)
El grade final no puede exceder el subgrado más bajo + 0.5. Esto asegura que una carta no obtenga un grade alto si alguna dimensión está muy dañada.

### 6. Banda de Incertidumbre
Calculada a partir de la consistencia entre subgrades y el rango de los subgrades. Valores típicos: ±0.5 (alta consistencia) a ±2.0 (baja consistencia).

### 7. Baselines Calibrados
- **Global (global_v1.0):** Baseline por defecto con umbrales de PSA estándar
- **Calibrado:** Baseline específico para un (set, finish) con mínimo 15 cartas de referencia
- Si no hay suficiente ground truth, se usa el baseline global como fallback

### 8. Enhanced Quality (IQS mejorado)
- **Laplacian Sharpness:** Nitidez basada en Laplaciano
- **Tenengrad Sharpness:** Nitidez basada en Sobel (complementaria)
- **Brightness:** Usando ITU-R BT.709
- **Entropy:** Contenido de información (máximo 8.0 para 8-bit)
- **Contrast:** Contraste RMS

## Interpretación de Resultados

### Grade Final
| Grade | Significado |
|-------|-------------|
| 9.5-10.0 | Gem Mint (perfecto) |
| 9.0-9.4 | Mint |
| 8.0-8.9 | NM-MT (Near Mint to Mint) |
| 7.0-7.9 | NM (Near Mint) |
| 6.0-6.9 | EX-MT (Excellent to Near Mint) |
| 5.0-5.9 | EX (Excellent) |
| 4.0-4.9 | VG-EX (Very Good to Excellent) |
| 3.0-3.9 | VG (Very Good) |
| 2.0-2.9 | G (Good) |
| 1.0-1.9 | PR (Poor) |

### Confidence Score
- **0.9-1.0:** Alta confianza (consistencia entre sub-grades)
- **0.7-0.9:** Confianza media
- **0.5-0.7:** Baja confianza (graduaciones inconsistentes)
- **< 0.5:** Muy baja confianza (revisar manualmente)

### Baseline Info
- `baseline_is_calibrated: false` → Se usó el baseline global (PSA estándar)
- `baseline_is_calibrated: true` → Se usó un baseline calibrado para el (set, finish)
- `baseline_reference_card_count` → Número de cartas de referencia usadas para calibración

## Resultados de Prueba (Imágenes de Ejemplo)

### Charizard (SVP, holo)
- **Grade Final:** 8.72 (coherence ajustado desde 8.85)
- **Subgrades:** Centering 8.22, Corners 10.0, Edges 8.47, Surface 8.75
- **Confianza:** 0.92
- **Banda de Incertidumbre:** 8.22 - 9.22
- **Regla de Coherencia:** Aplicada (8.22 + 0.5 = 8.72)

### Pikachu Snowman (SVP, holo)
- **Grade Final:** 8.00 (coherence ajustado desde 8.29)
- **Subgrades:** Centering 6.97, Corners 10.0, Edges 8.74, Surface 7.75
- **Confianza:** 0.78
- **Banda de Incertidumbre:** 7.50 - 8.50

### Pikachu Gordo (SVP, holo)
- **Grade Final:** 7.76 (coherence ajustado desde 7.76)
- **Subgrades:** Centering 6.86, Corners 10.0, Edges 8.20, Surface 6.89
- **Confianza:** 0.75
- **Banda de Incertidumbre:** 7.26 - 8.26

## Archivos Relacionados

### Core de Grading
- `backend/lib/domain/scoring/grading/grading_orchestrator.dart` - Orquestador principal (pesos BGS, regla de coherencia, banda de incertidumbre)
- `backend/lib/domain/scoring/grading/pregrading.dart` - Centering (detección de varianza)
- `backend/lib/domain/scoring/grading/baseline_config.dart` - Modelo de configuración de baseline
- `backend/lib/domain/scoring/grading/baseline_registry.dart` - Registro de baselines por (set, finish)
- `backend/lib/domain/scoring/grading/baseline_calibrator.dart` - Calibración desde datasets

### Detección de Defectos
- `backend/lib/domain/image_services/grading/corner_whitening_detector.dart` - Detección esquinas (con bordes blancos)
- `backend/lib/domain/image_services/grading/edge_whitening_detector.dart` - Detección bordes (con bordes blancos)
- `backend/lib/domain/image_services/grading/surface_scratch_detector.dart` - Detección superficie
- `backend/lib/domain/image_services/grading/enhanced_quality_service.dart` - IQS mejorado

### Endpoints HTTP
- `backend/lib/application/routes/evaluation_routes.dart` - Endpoints de grading y calibración
- `backend/lib/application/app_router.dart` - Router principal con DI

### Persistencia
- `backend/lib/persistence/card_data_provider/calibrated_baseline_repository.dart` - Interfaz de repositorio
- `backend/lib/persistence/card_data_provider/postgres_calibrated_baseline_repository.dart` - Implementación PostgreSQL
- `backend/lib/persistence/mocks/mock_calibrated_baseline_repository.dart` - Mock para testing

### Base de Datos
- `backend/db/init/005_baseline_schema.sql` - Schema de tabla calibrated_baseline
