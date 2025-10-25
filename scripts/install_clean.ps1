# Installation automatique des dependances - Assistant Domotique v2.0
Write-Host "Installation des dependances - Assistant Domotique v2.0" -ForegroundColor Cyan

# Verification droits administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Droits administrateur requis. Relancement..." -ForegroundColor Yellow
    Start-Process PowerShell -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
    exit 0
}

Write-Host "Droits administrateur confirmes" -ForegroundColor Green

# Configuration PowerShell
Write-Host "Configuration PowerShell..." -ForegroundColor White
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Installation Chocolatey
Write-Host "Installation Chocolatey..." -ForegroundColor White
try {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Chocolatey installe avec succes" -ForegroundColor Green
    } else {
        Write-Host "Chocolatey deja present" -ForegroundColor Green
    }
} catch {
    Write-Host "Erreur Chocolatey: $($_.Exception.Message)" -ForegroundColor Red
}

# Rafraichir PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Installation Python 3.11
Write-Host "Installation Python 3.11..." -ForegroundColor White
try {
    choco install python3 --version=3.11.9 -y --force
    Write-Host "Python 3.11 installe" -ForegroundColor Green
} catch {
    Write-Host "Erreur Python: $($_.Exception.Message)" -ForegroundColor Red
}

# Installation Git
Write-Host "Installation Git..." -ForegroundColor White
try {
    choco install git -y
    Write-Host "Git installe" -ForegroundColor Green
} catch {
    Write-Host "Erreur Git: $($_.Exception.Message)" -ForegroundColor Red
}

# Installation CMake
Write-Host "Installation CMake..." -ForegroundColor White
try {
    choco install cmake -y --installargs 'ADD_CMAKE_TO_PATH=System'
    Write-Host "CMake installe" -ForegroundColor Green
} catch {
    Write-Host "Erreur CMake: $($_.Exception.Message)" -ForegroundColor Red
}

# Installation Visual Studio Build Tools
Write-Host "Installation Visual Studio Build Tools..." -ForegroundColor White
try {
    choco install visualstudio2022buildtools -y --package-parameters "--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.CMake.Project"
    Write-Host "Visual Studio Build Tools installe" -ForegroundColor Green
} catch {
    Write-Host "Erreur VS Build Tools: $($_.Exception.Message)" -ForegroundColor Red
}

# Installation packages Python
Write-Host "Installation packages Python..." -ForegroundColor White
try {
    # Creer dossier python
    if (-not (Test-Path "python")) {
        New-Item -ItemType Directory -Path "python" -Force
    }
    
    # Creer requirements.txt
    $requirements = @"
anthropic>=0.3.0
requests>=2.31.0
aiohttp>=3.8.0
websockets>=11.0
SpeechRecognition>=3.10.0
pydub>=0.25.1
pyaudio>=0.2.11
google-auth>=2.22.0
google-auth-oauthlib>=1.0.0
google-auth-httplib2>=0.1.0
google-api-python-client>=2.100.0
spotipy>=2.23.0
numpy>=1.24.0
scipy>=1.11.0
pillow>=10.0.0
opencv-python>=4.8.0
"@
    
    Set-Content -Path "python\requirements.txt" -Value $requirements
    
    # Installer les packages
    python -m pip install --upgrade pip
    python -m pip install -r python\requirements.txt
    Write-Host "Packages Python installes" -ForegroundColor Green
} catch {
    Write-Host "Erreur packages Python: $($_.Exception.Message)" -ForegroundColor Red
}

# Information Qt
Write-Host "" 
Write-Host "IMPORTANT: Qt 6.5+ doit etre installe manuellement" -ForegroundColor Yellow
Write-Host "Telechargez depuis: https://www.qt.io/download-qt-installer" -ForegroundColor Yellow
Write-Host "Selectionnez: Qt 6.5+ Desktop MSVC 2019 64-bit + Qt 3D + Qt Multimedia" -ForegroundColor Yellow

# Verifications
Write-Host ""
Write-Host "Verification des installations..." -ForegroundColor White

try { 
    $pythonVer = python --version 2>&1
    Write-Host "Python: $pythonVer" -ForegroundColor Green 
} catch { 
    Write-Host "Python: Non trouve" -ForegroundColor Red 
}

try { 
    $pipVer = python -m pip --version 2>&1
    Write-Host "Pip: $pipVer" -ForegroundColor Green 
} catch { 
    Write-Host "Pip: Non trouve" -ForegroundColor Red 
}

try { 
    $gitVer = git --version 2>&1
    Write-Host "Git: $gitVer" -ForegroundColor Green 
} catch { 
    Write-Host "Git: Non trouve" -ForegroundColor Red 
}

try { 
    $cmakeVer = cmake --version 2>&1 | Select-Object -First 1
    Write-Host "CMake: $cmakeVer" -ForegroundColor Green 
} catch { 
    Write-Host "CMake: Non trouve" -ForegroundColor Red 
}

# Verification Qt
$qtFound = $false
$qtPaths = @("${env:ProgramFiles}\Qt", "${env:ProgramFiles(x86)}\Qt", "C:\Qt")

foreach ($path in $qtPaths) {
    if (Test-Path $path) {
        $qtVersions = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^6\." }
        if ($qtVersions) {
            Write-Host "Qt: Trouve dans $path" -ForegroundColor Green
            $qtFound = $true
            break
        }
    }
}

if (-not $qtFound) {
    Write-Host "Qt: Non trouve - Installation manuelle requise" -ForegroundColor Yellow
}

# Resume final
Write-Host ""
Write-Host "INSTALLATION TERMINEE !" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host "Dependances installees:" -ForegroundColor Cyan
Write-Host "- Python 3.11+ avec pip" -ForegroundColor White
Write-Host "- Git pour controle de version" -ForegroundColor White
Write-Host "- CMake pour build system" -ForegroundColor White  
Write-Host "- Visual Studio Build Tools 2022" -ForegroundColor White
Write-Host "- Bibliotheques Python completes" -ForegroundColor White

Write-Host ""
Write-Host "PROCHAINES ETAPES:" -ForegroundColor Cyan
Write-Host "1. Redemarrez PowerShell" -ForegroundColor White
Write-Host "2. Installez Qt 6.5+ si necessaire" -ForegroundColor White
Write-Host "3. Lancez: .\scripts\quick_build.ps1 Debug" -ForegroundColor White
Write-Host "4. Testez: cd build\Debug && .\RaspberryAssistant.exe" -ForegroundColor White

Write-Host ""
Write-Host "Environnement pret pour le developpement !" -ForegroundColor Green