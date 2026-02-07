# Cierra el backend si esta en ejecucion (para poder volver a compilar)
$proc = Get-Process -Name "SistemaGestionDocumental" -ErrorAction SilentlyContinue
if ($proc) {
    $proc | Stop-Process -Force
    Write-Host "Backend cerrado. Ya puedes ejecutar 'dotnet run' de nuevo."
} else {
    Write-Host "No hay ningun proceso SistemaGestionDocumental en ejecucion."
}
