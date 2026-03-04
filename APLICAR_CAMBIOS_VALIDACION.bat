@echo off
echo ========================================
echo APLICANDO CAMBIOS DE VALIDACION
echo ========================================
echo.
echo Este script reiniciara el backend para aplicar los cambios
echo de validacion de numeros correlativos por carpeta.
echo.
echo Cambios aplicados:
echo - Validacion de duplicados por carpeta (no global)
echo - Mensaje de error mejorado para rango
echo - Optimizacion de consultas a base de datos
echo.
pause

echo.
echo Deteniendo procesos del backend...
taskkill /F /IM dotnet.exe 2>nul
timeout /t 2 >nul

echo.
echo Iniciando backend...
cd backend
start "Backend - Sistema Gestion Documental" dotnet run

echo.
echo ========================================
echo Backend reiniciado correctamente
echo ========================================
echo.
echo Ahora puedes probar:
echo 1. Crear documento con numero 10 en carpeta con rango 10-30
echo 2. Verificar que el mensaje de error sea claro
echo 3. Crear documentos con el mismo numero en diferentes carpetas
echo.
pause
