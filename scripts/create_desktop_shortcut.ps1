#!/usr/bin/env powershell
# Crée un raccourci "EXO Assistant" sur le Bureau Windows.
# Usage : powershell -ExecutionPolicy Bypass -File scripts\create_desktop_shortcut.ps1

$projectDir = (Resolve-Path "$PSScriptRoot\..").Path
$desktop    = [Environment]::GetFolderPath('Desktop')
$lnkPath    = Join-Path $desktop "EXO Assistant.lnk"

$pythonExe  = Join-Path $projectDir ".venv\Scripts\python.exe"
$launcher   = Join-Path $projectDir "exo_launcher.py"

if (-not (Test-Path $pythonExe)) {
    Write-Host "ERREUR: python.exe introuvable : $pythonExe" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $launcher)) {
    Write-Host "ERREUR: exo_launcher.py introuvable : $launcher" -ForegroundColor Red
    exit 1
}

$shell    = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($lnkPath)

$icoPath = Join-Path $projectDir "resources\icons\exo.ico"

$shortcut.TargetPath       = $pythonExe
$shortcut.Arguments        = "`"$launcher`""
$shortcut.WorkingDirectory = $projectDir
$shortcut.Description      = "Lance EXO Assistant v4.2"
if (Test-Path $icoPath) {
    $shortcut.IconLocation = "$icoPath,0"
}
$shortcut.Save()

Write-Host "Raccourci cree : $lnkPath" -ForegroundColor Green
