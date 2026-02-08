@echo off
REM Script simple para arrancar backend y frontend
REM Ejecutar desde la raiz del proyecto

cd /d "%~dp0"

echo.
echo ================================================
echo   ARRANCAR BACKEND Y FRONTEND - VERSION SIMPLE
echo ================================================
echo.

echo [1/4] Cerrando backends anteriores...
tasklist /FI "IMAGENAME eq SistemaGestionDocumental.exe" 2>NUL | find /I /N "SistemaGestionDocumental.exe">NUL
if "%ERRORLEVEL%"=="0" (
    taskkill /F /IM SistemaGestionDocumental.exe >NUL 2>&1
    echo   Backend anterior cerrado.
    timeout /t 2 /nobreak >NUL
) else (
    echo   No hay backend anterior.
)

echo.
echo [2/4] Limpiando compilacion anterior...
cd backend
dotnet clean >NUL 2>&1
cd ..
echo   Limpieza completada.

echo.
echo [3/4] Iniciando BACKEND en nueva ventana...
echo   Espera a ver "Now listening on: http://localhost:5000"
start "Backend - SSUT" cmd /k "cd /d "%~dp0backend" && dotnet run"
timeout /t 12 /nobreak >NUL

echo.
echo [4/4] Iniciando FRONTEND en nueva ventana...
echo   Chrome se abrira automaticamente
start "Frontend - SSUT" cmd /k "cd /d "%~dp0frontend" && flutter run -d chrome"

echo.
echo ================================================
echo   ARRANQUE COMPLETADO
echo ================================================
echo.
echo Se abrieron DOS ventanas:
echo   1. Backend - SSUT (puerto 5000)
echo   2. Frontend - SSUT (abrira Chrome)
echo.
echo NO CIERRES la ventana del Backend.
echo.
echo Si ves error CORS:
echo   1. Asegurate de haber hecho: git pull origin main
echo   2. Cierra TODAS las ventanas y ejecuta este .bat de nuevo
echo.
pause
