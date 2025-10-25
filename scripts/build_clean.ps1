# =============================================================================
# Script de compilation rapide - Assistant Domotique v2.0
# Compilation avec CMake et Qt 6.9.3
# =============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("Debug", "Release")]
    [string]$BuildType = "Debug"
)

Write-Host "COMPILATION ASSISTANT DOMOTIQUE v2.0" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Configuration: $BuildType" -ForegroundColor Yellow

$ErrorActionPreference = "Continue"

# Rafraichir l'environnement
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verifier les prerequis
Write-Host "`nVerification des prerequis..." -ForegroundColor Yellow

$prereqsOk = $true

# Test CMake
try {
    $cmakeVersion = cmake --version 2>$null | Select-Object -First 1
    if ($cmakeVersion) {
        Write-Host "  OK CMake: $cmakeVersion" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR: CMake non trouve" -ForegroundColor Red
        $prereqsOk = $false
    }
} catch {
    Write-Host "  ERREUR: CMake non accessible" -ForegroundColor Red
    $prereqsOk = $false
}

# Test Qt
$qtFound = $false
$qtPaths = @("C:\Qt", "${env:ProgramFiles}\Qt", "${env:ProgramFiles(x86)}\Qt")

foreach ($qtPath in $qtPaths) {
    if (Test-Path $qtPath) {
        $qtVersions = Get-ChildItem $qtPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^6\." }
        if ($qtVersions) {
            $qtVersion = $qtVersions | Sort-Object Name -Descending | Select-Object -First 1
            $qtDir = $qtVersion.FullName
            
            # Chercher le dossier MSVC ou MinGW
            $compilerDirs = Get-ChildItem $qtDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "(msvc|mingw)" }
            if ($compilerDirs) {
                # Priorité à msvc2022_64 au lieu de arm64
                $compilerDir = $compilerDirs | Where-Object { $_.Name -eq "msvc2022_64" } | Select-Object -First 1
                if (-not $compilerDir) {
                    $compilerDir = $compilerDirs | Sort-Object Name -Descending | Select-Object -First 1
                }
                $qtCMakeDir = Join-Path $compilerDir.FullName "lib\cmake\Qt6"
                
                if (Test-Path $qtCMakeDir) {
                    Write-Host "  OK Qt: $($qtVersion.Name) avec $($compilerDir.Name) trouve" -ForegroundColor Green
                    $env:Qt6_DIR = $qtCMakeDir
                    $env:QT_COMPILER = $compilerDir.Name
                    
                    # Configurer PATH pour MinGW si necessaire
                    if ($compilerDir.Name -match "mingw") {
                        $mingwToolsPath = Join-Path $qtPath "Tools\mingw*\bin"
                        $mingwBinDirs = Get-ChildItem $mingwToolsPath -Directory -ErrorAction SilentlyContinue
                        if ($mingwBinDirs) {
                            $mingwBinPath = $mingwBinDirs | Sort-Object Name -Descending | Select-Object -First 1
                            $env:Path = "$($mingwBinPath.FullName);$env:Path"
                            Write-Host "    PATH MinGW configure: $($mingwBinPath.FullName)" -ForegroundColor Gray
                        }
                    }
                    
                    $qtFound = $true
                    break
                }
            }
        }
    }
}

if (-not $qtFound) {
    Write-Host "  ERREUR: Qt 6+ non trouve avec CMake" -ForegroundColor Red
    $prereqsOk = $false
}

# Test Visual Studio Build Tools
$vsFound = $false
$vsPaths = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
)

foreach ($vsPath in $vsPaths) {
    if (Test-Path $vsPath) {
        Write-Host "  OK Visual Studio Build Tools trouve" -ForegroundColor Green
        $vsFound = $true
        
        # Configurer l'environnement VS
        Write-Host "  Configuration environnement MSVC..." -ForegroundColor Cyan
        cmd /c "`"$vsPath`" >nul 2>&1 && set" | ForEach-Object {
            if ($_ -match "^(.*?)=(.*)$") {
                [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
            }
        }
        break
    }
}

if (-not $vsFound) {
    Write-Host "  ERREUR: Visual Studio Build Tools non trouve" -ForegroundColor Red
    $prereqsOk = $false
}

if (-not $prereqsOk) {
    Write-Host "`nERREUR: Prerequis manquants. Arret de la compilation." -ForegroundColor Red
    exit 1
}

# Creer le dossier build
Write-Host "`nPreparation du build..." -ForegroundColor Yellow
$buildDir = "build"

if (Test-Path $buildDir) {
    Write-Host "  Nettoyage du dossier build existant..." -ForegroundColor Cyan
    Remove-Item $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
Set-Location $buildDir

# Configuration CMake
Write-Host "`nConfiguration CMake..." -ForegroundColor Yellow

$cmakeArgs = @(
    ".."
    "-DCMAKE_BUILD_TYPE=$BuildType"
)

# Choisir le generateur selon le compilateur Qt
if ($env:QT_COMPILER -match "mingw") {
    $cmakeArgs += @("-G", "MinGW Makefiles")
    Write-Host "  Utilisation de MinGW Makefiles" -ForegroundColor Cyan
} else {
    $cmakeArgs += @("-G", "Visual Studio 17 2022", "-A", "x64")
    Write-Host "  Utilisation de Visual Studio 2022" -ForegroundColor Cyan
}

if ($env:Qt6_DIR) {
    $cmakeArgs += "-DQt6_DIR=`"$env:Qt6_DIR`""
}

Write-Host "  Arguments CMake: $($cmakeArgs -join ' ')" -ForegroundColor Gray

try {
    & cmake @cmakeArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK Configuration CMake reussie" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR Configuration CMake echec (code: $LASTEXITCODE)" -ForegroundColor Red
        Set-Location ..
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "  ERREUR CMake: $($_.Exception.Message)" -ForegroundColor Red
    Set-Location ..
    exit 1
}

# Compilation
Write-Host "`nCompilation..." -ForegroundColor Yellow

try {
    if ($env:QT_COMPILER -match "mingw") {
        # Pour MinGW, utiliser make directement
        & mingw32-make
    } else {
        # Pour Visual Studio, utiliser cmake --build
        & cmake --build . --config $BuildType
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK Compilation reussie !" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR Compilation echec (code: $LASTEXITCODE)" -ForegroundColor Red
        Set-Location ..
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "  ERREUR Build: $($_.Exception.Message)" -ForegroundColor Red
    Set-Location ..
    exit 1
}

# Verifier l'executable
$exeName = "RaspberryAssistant.exe"
$exePaths = @(
    "$BuildType\$exeName",
    "src\$BuildType\$exeName", 
    "Debug\$exeName",
    "Release\$exeName"
)

$exeFound = $false
foreach ($exePath in $exePaths) {
    if (Test-Path $exePath) {
        $fullExePath = Resolve-Path $exePath
        Write-Host "`nSUCCES ! Executable cree:" -ForegroundColor Green
        Write-Host "  $fullExePath" -ForegroundColor White
        
        # Afficher la taille
        $fileSize = [math]::Round((Get-Item $fullExePath).Length / 1MB, 2)
        Write-Host "  Taille: $fileSize MB" -ForegroundColor Gray
        
        $exeFound = $true
        break
    }
}

if (-not $exeFound) {
    Write-Host "`nATTENTION: Executable non trouve dans les emplacements attendus" -ForegroundColor Yellow
    Write-Host "Compilation terminee, mais verifiez manuellement le dossier build" -ForegroundColor Yellow
}

Set-Location ..

Write-Host "`n=== COMPILATION TERMINEE ===" -ForegroundColor Cyan
Write-Host "Configuration: $BuildType" -ForegroundColor White
Write-Host "Dossier build: $buildDir" -ForegroundColor White

if ($exeFound) {
    Write-Host "`nPour tester l'assistant:" -ForegroundColor Yellow
    Write-Host "  cd build" -ForegroundColor Gray
    Write-Host "  .\$BuildType\RaspberryAssistant.exe --test" -ForegroundColor Gray
} else {
    Write-Host "`nVerifiez le contenu du dossier build pour localiser l'executable" -ForegroundColor Yellow
}

Write-Host "`nProchaine etape: Tests des modules avec --test-mode" -ForegroundColor Cyan