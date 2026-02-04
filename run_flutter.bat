@echo off
REM Batch file to run Flutter commands

echo ===================================
echo  Flutter Project Helper Script
echo ===================================

setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "FLUTTER_DIR=%SCRIPT_
DIR%\frontend"

REM Fallback: search for pubspec.yaml if frontend\pubspec.yaml doesn't exist
if not exist "%FLUTTER_DIR%\pubspec.yaml" (
  set "FLUTTER_DIR="
  for /r "%SCRIPT_DIR%" %%F in (pubspec.yaml) do (
    if not defined FLUTTER_DIR set "FLUTTER_DIR=%%~dpF"
  )
)

if not defined FLUTTER_DIR (
  echo(
  echo ERROR: No pubspec.yaml file found under:
  echo   %SCRIPT_DIR%
  echo(
  echo Fix: Ensure your Flutter project exists in a subfolder (e.g. frontend\pubspec.yaml).
  echo(
  pause
  exit /b 1
)

pushd "%FLUTTER_DIR%" >nul

:menu
cls
echo.
echo Flutter project folder:
echo   %CD%
echo.
echo 1. Flutter clean
echo 2. Flutter pub get
echo 3. Run Flutter app
echo 4. Build APK
echo 5. Actualizar y ejecutar (clean + pub get + run) - ver Escaner QR optimizado
echo 6. Exit
echo.
set /p choice=Enter your choice (1-6): 

if "%choice%"=="1" goto clean
if "%choice%"=="2" goto pubget
if "%choice%"=="3" goto run
if "%choice%"=="4" goto build
if "%choice%"=="5" goto actualizar_run
if "%choice%"=="6" goto end

goto menu

:clean
echo(
echo Running 'flutter clean'...
flutter clean
pause
goto menu

:pubget
echo(
echo Running 'flutter pub get'...
flutter pub get
pause
goto menu

:run
echo(
echo Running Flutter app...
flutter run
pause
goto menu

:build
echo(
echo Building APK...
flutter build apk --release
echo(
echo APK built in: build\app\outputs\flutter-apk\app-release.apk
pause
goto menu

:actualizar_run
echo(
echo Actualizando (clean + pub get) y ejecutando...
flutter clean
flutter pub get
flutter run
pause
goto menu

:end
echo(
echo Exiting...
popd >nul
endlocal
pause
exit
