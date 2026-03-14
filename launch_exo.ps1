#!/usr/bin/env powershell
# Script de lancement EXO Assistant
# Utilisation: .\launch_exo.ps1

Write-Host "Lancement d'EXO Assistant..." -ForegroundColor Cyan

# Verifier que l'executable existe
$exePath = "C:\Users\aalou\Exo\build\Debug\RaspberryAssistant.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "Erreur: Executable non trouve a $exePath" -ForegroundColor Red
    Write-Host "Compilez d'abord avec: cmake --build . --config Debug" -ForegroundColor Yellow
    exit 1
}

# S'assurer que Qt est dans le PATH
$qtPath = "C:\Qt\6.9.3\msvc2022_64\bin"
if ($env:PATH -notlike "*$qtPath*") {
    Write-Host "Ajout du PATH Qt: $qtPath" -ForegroundColor Yellow
    $env:PATH += ";$qtPath"
}

# Charger les variables d'environnement depuis .env
$envFile = "C:\Users\aalou\Exo\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
        }
    }
    Write-Host "Variables d'environnement chargees depuis .env" -ForegroundColor Green
} else {
    Write-Host "Attention: fichier .env non trouve. Copiez .env.example en .env" -ForegroundColor Yellow
}

# Lancer EXO
Write-Host "Demarrage d'EXO..." -ForegroundColor Green
Set-Location "C:\Users\aalou\Exo\build\Debug"
& .\RaspberryAssistant.exe

Write-Host "EXO ferme." -ForegroundColor Cyan