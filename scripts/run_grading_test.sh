#!/bin/bash
# run_grading_test.sh
# Ejecuta el test de grading sobre todas las cartas en preprocess_output

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/../backend"
IMAGES_DIR="$SCRIPT_DIR/../preprocess_output"

echo ""
echo "============================================"
echo "  PokeGrading - Test de Grading"
echo "============================================"
echo ""

# Verificar que existe la carpeta de imagenes
if [ ! -d "$IMAGES_DIR" ]; then
    echo "ERROR: No se encontro la carpeta preprocess_output"
    exit 1
fi

# Listar imagenes disponibles
echo "Cartas encontradas:"
for f in "$IMAGES_DIR"/Imagen*.txt; do
    if [ -f "$f" ]; then
        echo "  - $(basename "$f")"
    fi
done
echo ""

# Ejecutar el test de grading
echo "Ejecutando grading..."
echo ""

cd "$BACKEND_DIR"
dart run bin/test_grading.dart

echo ""
echo "Test completado."
