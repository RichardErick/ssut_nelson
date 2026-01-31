@echo off
REM Ejecutar desde la carpeta del proyecto (ej: sistema seguro)
REM Doble clic o: quitar_conflictos_git.bat

cd /d "%~dp0"
cd ..
powershell -ExecutionPolicy Bypass -File "frontend\quitar_conflictos_git.ps1"
pause
