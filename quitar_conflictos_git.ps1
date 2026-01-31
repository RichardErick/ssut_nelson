# Copia este archivo a la raiz del proyecto (ej: "sistema seguro") y ejecuta:
#   .\quitar_conflictos_git.ps1

$ErrorActionPreference = "Stop"

$base = "frontend"
if (-not (Test-Path "$base\lib\screens\home_screen.dart")) {
    Write-Host "No se encontro $base\lib\screens. Ejecuta desde la carpeta del proyecto (donde esta la carpeta frontend)."
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
Write-Host "Listo. Luego ejecuta (desde la raiz del proyecto):"
Write-Host "  git add frontend/lib/screens/home_screen.dart frontend/lib/screens/notifications_screen.dart frontend/lib/screens/documentos/documentos_list_screen.dart"
Write-Host "  git commit -m \"Resueltos conflictos de merge\""
