# Script d'installation automatique Qt MSVC
Write-Host "INSTALLATION QT MSVC 2022 64-BIT" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Verifier si Qt MSVC est deja installe
$qtMsvcPaths = @(
    "C:\Qt\6.9.3\msvc*",
    "C:\Qt\6.8*\msvc*", 
    "C:\Qt\6.7*\msvc*",
    "C:\Qt\6.6*\msvc*",
    "C:\Qt\6.5*\msvc*"
)

$qtMsvcFound = $false
foreach ($pattern in $qtMsvcPaths) {
    $found = Get-ChildItem $pattern -Directory -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "Qt MSVC deja installe: $($found.FullName)" -ForegroundColor Green
        $qtMsvcFound = $true
        break
    }
}

if ($qtMsvcFound) {
    Write-Host "Qt MSVC est disponible. Vous pouvez proceder a la compilation." -ForegroundColor Green
    exit 0
}

Write-Host "Qt MSVC non trouve. Installation requise." -ForegroundColor Yellow
Write-Host ""
Write-Host "OPTIONS D'INSTALLATION :" -ForegroundColor Cyan
Write-Host "1. Qt Maintenance Tool (Recommande)" -ForegroundColor White
Write-Host "   - Ouvrir C:\Qt\MaintenanceTool.exe" -ForegroundColor Gray
Write-Host "   - Selectionner 'Add or remove components'" -ForegroundColor Gray
Write-Host "   - Cocher 'Desktop MSVC 2022 64-bit'" -ForegroundColor Gray
Write-Host "   - Cocher 'Qt 3D' et 'Qt Multimedia'" -ForegroundColor Gray
Write-Host "   - Cliquer 'Update'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Installation complete Qt (Alternative)" -ForegroundColor White
Write-Host "   - Telecharger depuis: https://www.qt.io/download-qt-installer" -ForegroundColor Gray
Write-Host "   - Installer Qt 6.5+ avec composants MSVC" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Compilation avec MinGW (Solution temporaire)" -ForegroundColor White
Write-Host "   - Modifier CMakeLists.txt pour MinGW" -ForegroundColor Gray
Write-Host "   - Installer MinGW separately si necessaire" -ForegroundColor Gray

Write-Host ""
Write-Host "COMPOSANTS REQUIS :" -ForegroundColor Yellow
Write-Host "- Qt 6.5+ Desktop MSVC 2022 64-bit" -ForegroundColor White
Write-Host "- Qt 3D (pour designer 3D)" -ForegroundColor White  
Write-Host "- Qt Multimedia (pour audio)" -ForegroundColor White
Write-Host "- Qt Quick (pour interface QML)" -ForegroundColor White

Write-Host ""
Write-Host "Apres installation, relancez: .\scripts\test_simple.ps1" -ForegroundColor Cyan