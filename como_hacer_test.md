# Cómo Hacer Test - Grading System

## Descripción

Este documento explica cómo probar el sistema de grading completo de PokéGrading, incluyendo:
- Detección de whitening en esquinas
- Detección de defectos en bordes
- Detección de rayas en superficie
- Análisis de calidad mejorado (Tenengrad + Entropía)
- Cálculo de grade final ponderado

## Prerequisitos

1. Tener el backend corriendo
2. Tener una imagen de una carta Pokémon en formato base64 o URL

## Endpoints Disponibles

### 1. Endpoint de Grading Completo

**URL:** `POST /api/v1/scoring/grade`

**Descripción:** Realiza preprocessing + grading completo de una carta.

**Request Body:**
```json
{
  "image_data": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
}
```

**Response Exitoso (200):**
```json
{
  "success": true,
  "grading": {
    "centering_grade": 8.5,
    "corners": {
      "corners": [
        {"position": "top_left", "whitening_score": 0.1, "whitening_percentage": 0.8, "passes": true},
        {"position": "top_right", "whitening_score": 0.0, "whitening_percentage": 0.3, "passes": true},
        {"position": "bottom_left", "whitening_score": 0.2, "whitening_percentage": 1.2, "passes": true},
        {"position": "bottom_right", "whitening_score": 0.3, "whitening_percentage": 1.8, "passes": true}
      ],
      "grade": 9.2,
      "average_whitening": 0.15,
      "passed_count": 4
    },
    "edges": {
      "edges": [
        {"position": "top", "whitening_score": 0.05, "straightness_score": 0.95, "quality_score": 0.92, "whitening_percentage": 0.5, "passes": true},
        {"position": "bottom", "whitening_score": 0.1, "straightness_score": 0.9, "quality_score": 0.88, "whitening_percentage": 0.8, "passes": true},
        {"position": "left", "whitening_score": 0.0, "straightness_score": 0.98, "quality_score": 0.98, "whitening_percentage": 0.2, "passes": true},
        {"position": "right", "whitening_score": 0.02, "straightness_score": 0.97, "quality_score": 0.97, "whitening_percentage": 0.3, "passes": true}
      ],
      "grade": 9.5,
      "average_quality": 0.94,
      "passed_count": 4
    },
    "surface": {
      "scratch_score": 0.85,
      "print_line_score": 0.92,
      "uniformity_score": 0.88,
      "grade": 8.7,
      "quality_score": 0.87,
      "scratch_count": 2,
      "passes": true
    },
    "final_grade": 8.9,
    "confidence": 0.92,
    "explanation": "Carta en excelente estado. Grade estimado: 8.9/10"
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

### 2. Endpoint de Preprocessing (solo)

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
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/v1/scoring/grade" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

### Prueba con Imagen Pequeña (para testing rápido)

```powershell
# Usando una imagen de ejemplo muy pequeña
$body = @{
    image_data = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEQMRAD8AKwA//9k="
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/v1/scoring/grade" `
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
- **Métrica:** Simetría de bordes
- **Escala:** 1.0 (muy desalineado) a 10.0 (perfectamente centrado)
- **Método:** Detección de bordes con Sobel + escaneo de márgenes

### 2. Corners (20% del grade final)
- **Métrica:** Whitening (blanqueamiento)
- **Escala:** 0.0 (perfecto) a 1.0 (severe whitening)
- **Método:** Análisis de brillo + saturación en espacio LAB-like
- **Umbrales:**
  - Perfecto: < 0.5% píxeles blanqueados
  - Fail: > 2.0% píxeles blanqueados

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

### 5. Enhanced Quality (IQS mejorado)
- **Laplacian Sharpness:** Nitidez basada en Laplaciano
- **Tenengrad Sharpness:** Nitidez basada en Sobel (complementaria)
- **Brightness:** BrilloUsing ITU-R BT.709
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

## Troubleshooting

### Error: "image_data is required"
- Asegúrate de enviar el campo `image_data` en el body

### Error: "Could not decode image data"
- Verifica que la imagen esté en formato válido (JPEG, PNG)
- Asegúrate de que el base64 esté correctamente codificado

### Error: "Card contour not detected"
- La imagen debe mostrar claramente la carta completa
- Fondo contrastante con la carta
- Buena iluminación

### Grade muy bajo o muy alto
- Verifica que la imagen no esté borrosa (IQS > 60)
- Asegúrate de que la carta esté recta en la imagen

## Archivos Relacionados

- `backend/lib/domain/scoring/grading/grading_orchestrator.dart` - Orquestador principal
- `backend/lib/domain/image_services/grading/corner_whitening_detector.dart` - Detección esquinas
- `backend/lib/domain/image_services/grading/edge_whitening_detector.dart` - Detección bordes
- `backend/lib/domain/image_services/grading/surface_scratch_detector.dart` - Detección superficie
- `backend/lib/domain/image_services/grading/enhanced_quality_service.dart` - IQS mejorado
- `backend/lib/application/routes/evaluation_routes.dart` - Endpoints HTTP
