# Test simple de l'environnement
Write-Host "TEST DE L'ENVIRONNEMENT DE DEVELOPPEMENT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Rafraichir PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

$testsPassed = 0
$testsTotal = 0

Write-Host "`n=== TESTS DES OUTILS DE BASE ===" -ForegroundColor Yellow

# Test Git
$testsTotal++
try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Host "  OK Git - $gitVersion" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ECHEC Git - Non trouve" -ForegroundColor Red
    }
} catch {
    Write-Host "  ECHEC Git - Erreur" -ForegroundColor Red
}

# Test Python
$testsTotal++
try {
    $pythonVersion = python --version 2>$null
    if ($pythonVersion -match "Python 3\.1[1-9]") {
        Write-Host "  OK Python - $pythonVersion" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ECHEC Python - Version incorrecte ou absente" -ForegroundColor Red
    }
} catch {
    Write-Host "  ECHEC Python - Non trouve" -ForegroundColor Red
}

# Test CMake
$testsTotal++
try {
    $cmakeVersion = cmake --version 2>$null | Select-Object -First 1
    if ($cmakeVersion) {
        Write-Host "  OK CMake - $cmakeVersion" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ECHEC CMake - Non trouve" -ForegroundColor Red
    }
} catch {
    Write-Host "  ECHEC CMake - Erreur" -ForegroundColor Red
}

Write-Host "`n=== TEST VISUAL STUDIO BUILD TOOLS ===" -ForegroundColor Yellow

# Test VS Build Tools
$testsTotal++
$vsPaths = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
)

$vsFound = $false
foreach ($path in $vsPaths) {
    if (Test-Path $path) {
        Write-Host "  OK Visual Studio Build Tools - Trouve" -ForegroundColor Green
        $testsPassed++
        $vsFound = $true
        break
    }
}

if (-not $vsFound) {
    Write-Host "  ECHEC Visual Studio Build Tools - Non trouve" -ForegroundColor Red
}

Write-Host "`n=== TEST QT 6.5+ ===" -ForegroundColor Yellow

# Test Qt
$testsTotal++
$qtPaths = @("C:\Qt", "${env:ProgramFiles}\Qt", "${env:ProgramFiles(x86)}\Qt")
$qtFound = $false

foreach ($qtPath in $qtPaths) {
    if (Test-Path $qtPath) {
        $qtVersions = Get-ChildItem $qtPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^6\.[5-9]" }
        if ($qtVersions) {
            $versionList = ($qtVersions.Name -join ', ')
            Write-Host "  OK Qt 6.5+ - Versions $versionList" -ForegroundColor Green
            $testsPassed++
            $qtFound = $true
            break
        }
    }
}

if (-not $qtFound) {
    Write-Host "  ECHEC Qt 6.5+ - Non trouve" -ForegroundColor Red
}

Write-Host "`n=== TEST PACKAGES PYTHON CLES ===" -ForegroundColor Yellow

# Test quelques packages Python essentiels
$packages = @("anthropic", "requests", "numpy", "speech_recognition")
foreach ($package in $packages) {
    $testsTotal++
    try {
        $moduleTest = switch ($package) {
            "speech_recognition" { "speech_recognition" }
            default { $package }
        }
        
        $result = python -c "import $moduleTest; print('OK')" 2>$null
        if ($result -eq "OK") {
            Write-Host "  OK Python $package - Installe" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "  ECHEC Python $package - Non trouve" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ECHEC Python $package - Erreur" -ForegroundColor Red
    }
}

Write-Host "`n=== TEST CONFIGURATION CLAUDE ===" -ForegroundColor Yellow

# Test config Claude
$testsTotal++
if (Test-Path "config\assistant.conf") {
    $config = Get-Content "config\assistant.conf" -Raw -ErrorAction SilentlyContinue
    if ($config -and $config -match "claude_api_key.*=.*sk-ant-api03-") {
        Write-Host "  OK Configuration Claude - Cle API configuree" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ECHEC Configuration Claude - Cle API manquante" -ForegroundColor Red
    }
} else {
    Write-Host "  ECHEC Configuration Claude - Fichier config manquant" -ForegroundColor Red
}

Write-Host "`n=== RESUME FINAL ===" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

$pourcentage = [math]::Round(($testsPassed / $testsTotal) * 100, 1)

Write-Host "`nResultats:" -ForegroundColor White
Write-Host "  Tests reussis: $testsPassed/$testsTotal ($pourcentage%)" -ForegroundColor $(if ($testsPassed -eq $testsTotal) { "Green" } else { "Yellow" })

if ($testsPassed -eq $testsTotal) {
    Write-Host "`nSUCCES - ENVIRONNEMENT PRET !" -ForegroundColor Green
    Write-Host "Vous pouvez lancer la compilation:" -ForegroundColor White
    Write-Host "  .\scripts\quick_build.ps1 Debug" -ForegroundColor Yellow
} elseif ($testsPassed -ge ($testsTotal - 2)) {
    Write-Host "`nPRESQUE PRET - Quelques elements manquent" -ForegroundColor Yellow
    Write-Host "Verifiez les installations manquantes ci-dessus" -ForegroundColor White
} else {
    Write-Host "`nATTENTION - Plusieurs dependances manquent" -ForegroundColor Red
    Write-Host "Installez les dependances manquantes avant de continuer" -ForegroundColor White
}

Write-Host "`nPour relancer: .\scripts\test_simple.ps1" -ForegroundColor Cyan