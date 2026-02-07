# Ejecutar backend (cierra el proceso si esta en marcha, limpia y arranca)
# Usar desde PowerShell dentro de la carpeta backend.

$proc = Get-Process -Name "SistemaGestionDocumental" -ErrorAction SilentlyContinue
if ($proc) {
    $proc | Stop-Process -Force
    Write-Host "Backend cerrado. Esperando 2 segundos..."
    Start-Sleep -Seconds 2
}
Write-Host "Limpiando proyecto..."
dotnet clean
Write-Host "Iniciando backend..."
dotnet run
