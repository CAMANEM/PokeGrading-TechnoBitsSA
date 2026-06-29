@echo off
REM run_grading_test.bat
REM Ejecuta el test de grading sobre todas las cartas en preprocess_output

setlocal

set "SCRIPT_DIR=%~dp0"
set "BACKEND_DIR=%SCRIPT_DIR%..\backend"
set "IMAGES_DIR=%SCRIPT_DIR%..\preprocess_output"

echo.
echo ============================================
echo   PokeGrading - Test de Grading
echo ============================================
echo.

REM Verificar que existe la carpeta de imagenes
if not exist "%IMAGES_DIR%" (
    echo ERROR: No se encontro la carpeta preprocess_output
    exit /b 1
)

REM Listar imagenes disponibles
echo Cartas encontradas:
for %%f in ("%IMAGES_DIR%\Imagen*.txt") do (
    echo   - %%~nxf
)
echo.

REM Ejecutar el test de grading
echo Ejecutando grading...
echo.

cd /d "%BACKEND_DIR%"
dart run bin\test_grading.dart

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: El test fallo con codigo %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo.
echo Test completado.
