# Script de compilation simple - Assistant Domotique v2.0
# Version corrigee pour Windows PowerShell

param(
    [string]$BuildType = "Debug"
)

# Configuration
$ErrorActionPreference = "Stop"

Write-Host "🏗️ Assistant Domotique v2.0 - Compilation Windows" -ForegroundColor Cyan
Write-Host "Type de build: $BuildType" -ForegroundColor Yellow
Write-Host ""

# Verification des prerequis
Write-Host "📋 Verification des prerequis..." -ForegroundColor Yellow

if (!(Get-Command "cmake" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ CMake manquant" -ForegroundColor Red
    exit 1
}
Write-Host "✅ CMake disponible" -ForegroundColor Green

if (!(Get-Command "qmake" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Qt qmake manquant" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Qt disponible" -ForegroundColor Green

# Creation du dossier build
if (!(Test-Path "build")) {
    New-Item -ItemType Directory -Name "build" | Out-Null
}
Set-Location "build"

# Configuration CMake
Write-Host "⚙️ Configuration CMake..." -ForegroundColor Yellow

cmake .. `
    -DCMAKE_BUILD_TYPE=$BuildType `
    -DBUILD_TESTS=ON `
    -DEZVIZ_API_ENABLED=ON `
    -DMICROSOFT_TTS_ENABLED=ON `
    -DGOOGLE_SERVICES_ENABLED=ON `
    -DMUSIC_STREAMING_ENABLED=ON `
    -DAI_MEMORY_ENABLED=ON `
    -DROOM_DESIGNER_3D_ENABLED=ON

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur configuration CMake" -ForegroundColor Red
    exit 1
}

# Compilation
Write-Host "🔨 Compilation..." -ForegroundColor Yellow
$startTime = Get-Date

cmake --build . --config $BuildType --parallel

$endTime = Get-Date
$buildTime = [int]($endTime - $startTime).TotalSeconds

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur de compilation" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Compilation terminée en ${buildTime}s" -ForegroundColor Green

# Verification executable
$exePath = if ($BuildType -eq "Debug") { 
    "Debug\RaspberryAssistant.exe" 
} else { 
    "Release\RaspberryAssistant.exe" 
}

if (Test-Path $exePath) {
    Write-Host "✅ Executable créé: $exePath" -ForegroundColor Green
} else {
    Write-Host "❌ Executable non trouvé" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 COMPILATION RÉUSSIE !" -ForegroundColor Green
Write-Host "📁 Executable: $(Get-Location)\$exePath" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 Prochaines etapes:" -ForegroundColor Cyan
Write-Host "1. Tester: .\$exePath --test-mode" -ForegroundColor White
Write-Host "2. Consulter: ..\QUICKSTART.md" -ForegroundColor White