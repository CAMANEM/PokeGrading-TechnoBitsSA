US: Realizar búsqueda rápida de carta.

Description: Yo como Submitter quiero que el sistema identifique automáticamente mi carta con una búsqueda rápida para entonces no tener que ingresar manualmente sus atributos.

Acceptance Criteria: 
- Búsqueda rápida sobre el catálogo a partir de las imágenes capturadas. 
- Devuelve los 3 mejores candidatos con su nivel de confianza. 
- Si el candidato top supera :umbral configurado, se acepta automáticamente y avanza al siguiente paso. Alternos: 
- Sin candidatos sobre el umbral, escala a búsqueda especializada. 
- Si la imagen no permite identificación visual, deriva al flujo de búsqueda manual.

Tasks:

- Diseñar flujo de identificación rápida: Definir flujo funcional y estados de búsqueda automática, especializada y manual.
- Preparar catálogo indexado para búsqueda rápida: Construir estructura optimizada para matching visual inicial.
- Implementar extracción de features visuales: Obtener embeddings o métricas visuales para comparación contra catálogo.
- Implementar algoritmo de búsqueda rápida: Comparar imágenes contra catálogo y generar ranking de candidatos.
- Implementar cálculo de confidence score: Calcular nivel de confianza para cada candidato encontrado.
- Implementar respuesta Top-3 candidatos: Retornar los 3 candidatos con nombre, set y confianza.
- Configurar umbral de aceptación automática: Parametrizar threshold configurable para auto-aceptación.
- Implementar transición automática al siguiente paso: Avanzar automáticamente cuando el top candidate supere el umbral.
- Implementar escalamiento a búsqueda especializada: Redirigir automáticamente cuando no existan candidatos suficientemente confiables.
- Implementar derivación a búsqueda manual: Redirigir al flujo manual cuando la imagen no permita identificación visual.
- Implementar logging y trazabilidad de búsqueda: Registrar candidatos generados, scores y decisiones automáticas.