# Script para verificar CORS y arrancar backend/frontend correctamente
# Ejecutar desde la raíz del proyecto

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VERIFICACIÓN Y ARRANQUE - SSUT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar que estamos en la carpeta correcta
if (-not (Test-Path "backend\Program.cs")) {
    Write-Host "ERROR: No se encuentra backend\Program.cs" -ForegroundColor Red
    Write-Host "Ejecuta este script desde la raíz del proyecto (donde están las carpetas backend y frontend)" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "[1/7] Verificando código CORS en Program.cs..." -ForegroundColor Green
$programCs = Get-Content "backend\Program.cs" -Raw
if ($programCs -match "AllowFlutterApp" -and $programCs -match "UseCors") {
    Write-Host "  ✓ Configuración CORS encontrada en Program.cs" -ForegroundColor Green
} else {
    Write-Host "  ✗ FALTA configuración CORS en Program.cs!" -ForegroundColor Red
    Write-Host "  Necesitas hacer 'git pull' para actualizar el código" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host ""
Write-Host "[2/7] Cerrando backends anteriores..." -ForegroundColor Green
$proc = Get-Process -Name "SistemaGestionDocumental" -ErrorAction SilentlyContinue
if ($proc) {
    $proc | Stop-Process -Force
    Write-Host "  ✓ Backend anterior cerrado" -ForegroundColor Green
    Start-Sleep -Seconds 2
} else {
    Write-Host "  ✓ No hay backend anterior en ejecución" -ForegroundColor Green
}

Write-Host ""
Write-Host "[3/7] Limpiando compilación anterior..." -ForegroundColor Green
Push-Location backend
dotnet clean | Out-Null
Write-Host "  ✓ Limpieza completada" -ForegroundColor Green
Pop-Location

Write-Host ""
Write-Host "[4/7] Verificando conexión a base de datos..." -ForegroundColor Green
Write-Host "  (Si falla, verifica que PostgreSQL esté corriendo)" -ForegroundColor Yellow

Write-Host ""
Write-Host "[5/7] Iniciando Backend en nueva ventana..." -ForegroundColor Green
$backendPath = Join-Path $PWD "backend"
Start-Process cmd -ArgumentList "/k", "cd /d `"$backendPath`" && title Backend - SSUT && dotnet run"
Write-Host "  ✓ Backend iniciando..." -ForegroundColor Green

Write-Host ""
Write-Host "[6/7] Esperando 12 segundos para que el backend arranque..." -ForegroundColor Green
for ($i = 12; $i -gt 0; $i--) {
    Write-Host "  $i..." -NoNewline
    Start-Sleep -Seconds 1
}
Write-Host ""
Write-Host "  ✓ Espera completada" -ForegroundColor Green

Write-Host ""
Write-Host "[7/7] Iniciando Frontend en nueva ventana..." -ForegroundColor Green
$frontendPath = Join-Path $PWD "frontend"
Start-Process cmd -ArgumentList "/k", "cd /d `"$frontendPath`" && title Frontend - SSUT && flutter run -d chrome"
Write-Host "  ✓ Frontend iniciando..." -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VERIFICACIÓN COMPLETADA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se abrieron DOS ventanas:" -ForegroundColor White
Write-Host "  1. Backend - SSUT (puerto 5000)" -ForegroundColor Yellow
Write-Host "  2. Frontend - SSUT (abrirá Chrome)" -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANTE:" -ForegroundColor Red
Write-Host "  - NO cierres la ventana del Backend" -ForegroundColor White
Write-Host "  - Espera a que Chrome abra automáticamente" -ForegroundColor White
Write-Host "  - Si ves error CORS, el backend NO se actualizó:" -ForegroundColor White
Write-Host "    Haz 'git pull' y ejecuta este script de nuevo" -ForegroundColor White
Write-Host ""
Write-Host "Prueba el login con: doc_admin / admin" -ForegroundColor Green
Write-Host ""
pause
