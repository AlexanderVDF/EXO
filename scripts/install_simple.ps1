# =============================================================================
# Script d'installation simplifié des dépendances - Windows
# Assistant Domotique v2.0
# =============================================================================

Write-Host "🚀 Installation des dépendances - Assistant Domotique v2.0" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# Fonction pour les messages colorés
function Write-Status {
    param([string]$Message, [string]$Status = "Info")
    $color = switch($Status) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }
    Write-Host $Message -ForegroundColor $color
}

# 1. Vérification des droits administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Status "⚠️  Droits administrateur requis. Relancement automatique..." "Warning"
    Start-Process PowerShell -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
    exit 0
}

Write-Status "✅ Droits administrateur confirmés" "Success"

# 2. Configuration de l'exécution PowerShell
Write-Status "`n🔐 Configuration PowerShell..." "Info"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Write-Status "✅ Politique d'exécution configurée" "Success"

# 3. Installation de Chocolatey
Write-Status "`n🍫 Installation de Chocolatey..." "Info"
try {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Status "✅ Chocolatey installé" "Success"
    } else {
        Write-Status "✅ Chocolatey déjà présent" "Success"
    }
} catch {
    Write-Status "❌ Erreur Chocolatey: $($_.Exception.Message)" "Error"
}

# Rafraîchir PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 4. Installation Python 3.11
Write-Status "`n🐍 Installation Python 3.11..." "Info"
try {
    choco install python3 --version=3.11.9 -y --force
    Write-Status "✅ Python 3.11 installé" "Success"
} catch {
    Write-Status "❌ Erreur Python: $($_.Exception.Message)" "Error"
}

# 5. Installation Git
Write-Status "`n📦 Installation Git..." "Info"
try {
    choco install git -y
    Write-Status "✅ Git installé" "Success"
} catch {
    Write-Status "❌ Erreur Git: $($_.Exception.Message)" "Error"
}

# 6. Installation CMake
Write-Status "`n🔨 Installation CMake..." "Info"
try {
    choco install cmake -y --installargs 'ADD_CMAKE_TO_PATH=System'
    Write-Status "✅ CMake installé" "Success"
} catch {
    Write-Status "❌ Erreur CMake: $($_.Exception.Message)" "Error"
}

# 7. Installation Visual Studio Build Tools 2022
Write-Status "`n🏗️  Installation Visual Studio Build Tools..." "Info"
try {
    choco install visualstudio2022buildtools -y --package-parameters "--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.CMake.Project"
    Write-Status "✅ Visual Studio Build Tools installé" "Success"
} catch {
    Write-Status "❌ Erreur VS Build Tools: $($_.Exception.Message)" "Error"
}

# 8. Installation des packages Python
Write-Status "`n📚 Installation packages Python..." "Info"
try {
    # Créer le dossier python s'il n'existe pas
    if (-not (Test-Path "python")) {
        New-Item -ItemType Directory -Path "python" -Force
    }
    
    # Créer requirements.txt
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
    Write-Status "✅ Packages Python installés" "Success"
} catch {
    Write-Status "❌ Erreur packages Python: $($_.Exception.Message)" "Error"
}

# 9. Information Qt
Write-Status "`n🎨 Information Qt 6.5+..." "Info"
Write-Status "Qt doit être installé manuellement depuis:" "Warning"
Write-Status "https://www.qt.io/download-qt-installer" "Warning"
Write-Status "Sélectionnez: Qt 6.5+ Desktop MSVC 2019 64-bit + Qt 3D + Qt Multimedia" "Warning"

# 10. Vérifications finales
Write-Status "`n✅ Vérification des installations..." "Info"

$checks = @{
    "Python" = { python --version }
    "Pip" = { python -m pip --version }
    "Git" = { git --version }
    "CMake" = { cmake --version }
}

foreach ($check in $checks.GetEnumerator()) {
    try {
        $result = & $check.Value 2>&1 | Select-Object -First 1
        Write-Status "  ✅ $($check.Key): $result" "Success"
    } catch {
        Write-Status "  ❌ $($check.Key): Non trouvé" "Error"
    }
}

# Vérification Qt
$qtPaths = @("${env:ProgramFiles}\Qt", "${env:ProgramFiles(x86)}\Qt", "C:\Qt")
$qtFound = $false

foreach ($path in $qtPaths) {
    if (Test-Path $path) {
        $qtVersions = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^6\." }
        if ($qtVersions) {
            Write-Status "  ✅ Qt trouve: $path ($($qtVersions.Name -join ', '))" "Success"
            $qtFound = $true
            break
        }
    }
}

if (-not $qtFound) {
    Write-Status "  ⚠️  Qt 6.5+ non trouve - Installation manuelle requise" "Warning"
}

# Résumé final
Write-Host "`n🎉 INSTALLATION TERMINÉE !" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Status "✅ Python 3.11+ installé" "Success"
Write-Status "✅ Git installé" "Success"  
Write-Status "✅ CMake installé" "Success"
Write-Status "✅ Visual Studio Build Tools installé" "Success"
Write-Status "✅ Packages Python installés" "Success"

if (-not $qtFound) {
    Write-Status "⚠️  Qt 6.5+ requis - A installer manuellement" "Warning"
}

Write-Host "`n🚀 PROCHAINES ÉTAPES:" -ForegroundColor Cyan
Write-Status "1. Redémarrez PowerShell" "Info"
Write-Status "2. Installez Qt 6.5+ si nécessaire" "Info"
Write-Status "3. Lancez: .\scripts\quick_build.ps1 Debug" "Info"
Write-Status "4. Testez: cd build\Debug && .\RaspberryAssistant.exe" "Info"

Write-Status "`n✨ Environnement prêt pour le développement !" "Success"