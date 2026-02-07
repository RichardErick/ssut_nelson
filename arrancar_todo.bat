@echo off
title Arrancar SSUT - Backend y Frontend
cd /d "%~dp0"

echo.
echo ========================================
echo   SSUT - Sistema de Gestion Documental
echo ========================================
echo.
echo Abriendo Backend (puerto 5000)...
start "Backend - SSUT" cmd /k "cd /d "%~dp0backend" && dotnet run"

echo Esperando 5 segundos para que el backend inicie...
timeout /t 5 /nobreak >nul

echo Abriendo Frontend (Flutter web en Chrome)...
start "Frontend - SSUT" cmd /k "cd /d "%~dp0frontend" && flutter run -d chrome"

echo.
echo Se abrieron dos ventanas:
echo   - Backend: dejala abierta (http://localhost:5000)
echo   - Frontend: la app se abrira en Chrome
echo.
pause
