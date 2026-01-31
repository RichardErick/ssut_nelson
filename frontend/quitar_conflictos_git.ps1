# Ejecuta desde la CARPETA DEL PROYECTO (ej: "sistema seguro") o desde "frontend".
# Ejemplo: cd "C:\Users\Brayan Cortez\Desktop\sistema seguro"
#          .\frontend\quitar_conflictos_git.ps1

$ErrorActionPreference = "Stop"

# Detectar ruta: si estamos en frontend o en la raiz del proyecto
$base = $null
if (Test-Path "lib\screens\home_screen.dart") { $base = "." }
elseif (Test-Path "frontend\lib\screens\home_screen.dart") { $base = "frontend" }
else {
    Write-Host "No se encontro lib/screens. Ejecuta desde la carpeta del proyecto o desde frontend."
    exit 1
}

$files = @(
    "$base\lib\screens\home_screen.dart",
    "$base\lib\screens\notifications_screen.dart",
    "$base\lib\screens\documentos\documentos_list_screen.dart"
)

function Resolve-Conflicts($path) {
    $lines = Get-Content -Path $path
    $out = New-Object System.Collections.ArrayList
    $skip = $false
    foreach ($line in $lines) {
        if ($line -match '^<<<<<<< ') { $skip = $false; continue }
        if ($line -match '^=======$') { $skip = $true; continue }
        if ($line -match '^>>>>>>> ') { $skip = $false; continue }
        if (-not $skip) { [void]$out.Add($line) }
    }
    $out -join "`r`n"
}

foreach ($f in $files) {
    if (-not (Test-Path $f)) { Write-Host "No encontrado: $f"; continue }
    $content = Get-Content -Path $f -Raw
    if ($content -notmatch '<<<<<<< ') { Write-Host "$f : sin conflictos."; continue }
    $resolved = Resolve-Conflicts $f
    Set-Content -Path $f -Value $resolved -NoNewline
    Write-Host "Resuelto: $f"
}
Write-Host "Listo. Marca como resueltos y haz commit:"
Write-Host "  Desde raiz: git add frontend/lib/screens/home_screen.dart frontend/lib/screens/notifications_screen.dart frontend/lib/screens/documentos/documentos_list_screen.dart"
Write-Host "  Desde frontend: git add lib/screens/home_screen.dart lib/screens/notifications_screen.dart lib/screens/documentos/documentos_list_screen.dart"
Write-Host "  git commit -m \"Resueltos conflictos de merge\""
