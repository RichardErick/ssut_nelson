@echo off
title Arrancar SSUT - Backend y Frontend
cd /d "%~dp0"

echo.
echo ========================================
echo   SSUT - Sistema de Gestion Documental
echo ========================================
echo.
echo IMPORTANTE: Ejecuta este archivo UNA SOLA VEZ.
echo Si ya hay ventanas del Backend o Frontend abiertas, cierralas
echo antes de ejecutar de nuevo (evita 4 ventanas y errores de conexion).
echo.
pause

echo Abriendo Backend (puerto 5000)...
start "Backend - SSUT" cmd /k "cd /d "%~dp0backend" && title Backend - SSUT && dotnet run"

echo Esperando 10 segundos para que el backend inicie...
timeout /t 10 /nobreak >nul

echo Abriendo Frontend (Flutter web en Chrome)...
start "Frontend - SSUT" cmd /k "cd /d "%~dp0frontend" && title Frontend - SSUT && flutter run -d chrome"

echo.
echo Se abrieron DOS ventanas:
echo   - Backend: dejala abierta (http://localhost:5000)
echo   - Frontend: la app se abrira en Chrome cuando compile
echo.
echo Si ves "ERR_CONNECTION_REFUSED" en Chrome: no cierres la ventana
echo "Frontend - SSUT" hasta que la pagina cargue. Cierra pestañas viejas.
echo.
pause
