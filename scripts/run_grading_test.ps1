# run_grading_test.ps1
# Ejecuta el test de grading sobre todas las cartas en preprocess_output

$ErrorActionPreference = "Stop"
$BackendDir = Join-Path $PSScriptRoot "..\backend"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PokeGrading - Test de Grading" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que existe la carpeta de imagenes
$ImagesDir = Join-Path $PSScriptRoot "..\preprocess_output"
if (-not (Test-Path $ImagesDir)) {
    Write-Host "ERROR: No se encontro la carpeta preprocess_output" -ForegroundColor Red
    exit 1
}

# Listar imagenes disponibles
$Images = Get-ChildItem -Path $ImagesDir -Filter "Imagen*.txt" | Select-Object -ExpandProperty Name
if ($Images.Count -eq 0) {
    Write-Host "ERROR: No se encontraron imagenes (Imagen*.txt) en preprocess_output" -ForegroundColor Red
    exit 1
}

Write-Host "Cartas encontradas:" -ForegroundColor Green
foreach ($img in $Images) {
    Write-Host "  - $img"
}
Write-Host ""

# Ejecutar el test de grading
Write-Host "Ejecutando grading..." -ForegroundColor Yellow
Write-Host ""

Set-Location $BackendDir
dart run bin/test_grading.dart

$ExitCode = $LASTEXITCODE
if ($ExitCode -ne 0) {
    Write-Host ""
    Write-Host "ERROR: El test fallo con codigo $ExitCode" -ForegroundColor Red
    exit $ExitCode
}

Write-Host ""
Write-Host "Test completado." -ForegroundColor Green
