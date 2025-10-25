# Script de compilation rapide pour Windows
# Usage: .\build_simple.ps1 [Debug|Release]
param(
    [string]$BuildType = "Debug",
    [int]$Jobs = 4
)

# Couleurs pour les messages
function Write-ColorMessage {
    param([string]$Message, [string]$Color = "White")
    $colorMap = @{
        "Red" = "Red"; "Green" = "Green"; "Yellow" = "Yellow"; 
        "Blue" = "Blue"; "Cyan" = "Cyan"; "White" = "White"
    }
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

$ProjectRoot = Split-Path $PSScriptRoot -Parent
Write-ColorMessage "🚀 Construction Assistant Raspberry Pi 5" "Cyan"
Write-ColorMessage "📁 Projet: $ProjectRoot" "White"
Write-ColorMessage "🔨 Type: $BuildType" "White"

# Vérification des prérequis
Write-ColorMessage "🔍 Vérification des prérequis..." "Yellow"

# CMake
if (Get-Command "cmake" -ErrorAction SilentlyContinue) {
    $cmakeVersion = cmake --version | Select-Object -First 1
    Write-ColorMessage "  ✅ $cmakeVersion" "Green"
} else {
    Write-ColorMessage "  ❌ CMake non trouvé" "Red"
    exit 1
}

# Qt
$qtDir = "C:\Qt\6.9.3\msvc2022_64"
if (Test-Path $qtDir) {
    Write-ColorMessage "  ✅ Qt 6.9.3 MSVC 2022 trouvé" "Green"
    $env:CMAKE_PREFIX_PATH = $qtDir
} else {
    Write-ColorMessage "  ❌ Qt 6.9.3 MSVC non trouvé" "Red"
    exit 1
}

# Compilateur
if (Get-Command "cl.exe" -ErrorAction SilentlyContinue) {
    Write-ColorMessage "  ✅ Compilateur MSVC disponible" "Green"
} else {
    # Tenter d'initialiser l'environnement VS
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vsPath) {
            $vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
            if (Test-Path $vcvarsPath) {
                Write-ColorMessage "  ✅ Initialisation environnement VS..." "Green"
                cmd /c "`"$vcvarsPath`" >nul 2>&1 && set" | foreach {
                    if ($_ -match "^(.*?)=(.*)$") {
                        Set-Item "env:\$($matches[1])" $matches[2]
                    }
                }
            }
        }
    }
}

# Création du dossier build
Set-Location $ProjectRoot
if (Test-Path "build") {
    Write-ColorMessage "🧹 Nettoyage du dossier build..." "Yellow"
    Remove-Item "build" -Recurse -Force
}
New-Item -ItemType Directory -Name "build" | Out-Null
Set-Location "build"

# Configuration CMake
Write-ColorMessage "⚙️  Configuration CMake..." "Yellow"
$cmakeArgs = @(
    ".."
    "-G", "Visual Studio 17 2022"
    "-A", "x64"
    "-DCMAKE_BUILD_TYPE=$BuildType"
    "-DCMAKE_PREFIX_PATH=$qtDir"
)

cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    Write-ColorMessage "❌ Échec configuration CMake" "Red"
    exit 1
}

# Compilation
Write-ColorMessage "🔨 Compilation..." "Yellow"
cmake --build . --config $BuildType --parallel $Jobs
if ($LASTEXITCODE -ne 0) {
    Write-ColorMessage "❌ Échec compilation" "Red"
    exit 1
}

# Vérification de l'exécutable
$exePath = "$BuildType\RaspberryAssistant.exe"
if (Test-Path $exePath) {
    Write-ColorMessage "✅ Compilation réussie!" "Green"
    $fileSize = [math]::Round((Get-Item $exePath).Length / 1MB, 2)
    Write-ColorMessage "📦 Exécutable: $exePath ($fileSize MB)" "Green"
    
    # Copier les DLL Qt nécessaires
    Write-ColorMessage "📋 Copie des dépendances Qt..." "Yellow"
    $qtBinDir = "$qtDir\bin"
    if (Test-Path $qtBinDir) {
        $qtDlls = @(
            "Qt6Core.dll", "Qt6Gui.dll", "Qt6Widgets.dll", "Qt6Qml.dll", 
            "Qt6Quick.dll", "Qt6Network.dll", "Qt6Multimedia.dll"
        )
        foreach ($dll in $qtDlls) {
            $sourcePath = Join-Path $qtBinDir $dll
            if (Test-Path $sourcePath) {
                Copy-Item $sourcePath $BuildType -Force
                Write-ColorMessage "  📄 $dll copiée" "Green"
            }
        }
    }
    
    Write-ColorMessage "🎉 BUILD TERMINÉ AVEC SUCCÈS!" "Green"
    Write-ColorMessage "▶️  Pour tester: .\build\$BuildType\RaspberryAssistant.exe --test-mode" "Cyan"
} else {
    Write-ColorMessage "❌ Exécutable non créé" "Red"
    exit 1
}