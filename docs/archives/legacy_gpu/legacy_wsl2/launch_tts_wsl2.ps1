#!/usr/bin/env powershell
# ============================================================================
# launch_tts_wsl2.ps1 - Lance le serveur TTS GPU dans WSL2
#
# Ce script :
#   1) Tue tout ancien serveur TTS sur le port 8767
#   2) Lance le serveur TTS GPU XTTS v2 dans WSL2 (ROCm/AMD GPU)
#   3) Attend que le serveur soit prêt
#   4) Vérifie la connectivité depuis Windows
#
# Utilisation :
#   .\scripts\launch_tts_wsl2.ps1
# ============================================================================

param(
    [string]$Voice = "Claribel Dervla",
    [string]$Lang = "fr",
    [int]$Port = 8767,
    [int]$TimeoutSec = 120
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  EXO TTS GPU Server (WSL2 + ROCm)"     -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- 1) Tuer tout processus sur le port 8767 ---
$existing = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
    Where-Object { $_.State -eq 'Listen' }
if ($existing) {
    Write-Host "[TTS-WSL2] Port $Port deja occupe (PID: $($existing.OwningProcess)) - arret..." -ForegroundColor Yellow
    Stop-Process -Id $existing.OwningProcess -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# --- 2) Verifier que WSL2 est disponible ---
$wslStatus = wsl --list --verbose 2>&1 | Select-String "Ubuntu-22.04"
if (-not $wslStatus) {
    Write-Host "[TTS-WSL2] ERREUR: Ubuntu-22.04 non trouve dans WSL2" -ForegroundColor Red
    exit 1
}
Write-Host "[TTS-WSL2] WSL2 Ubuntu-22.04 detecte" -ForegroundColor Green

# --- 3) Monter J:\ dans WSL2 si necessaire ---
wsl -d Ubuntu-22.04 -u root -- bash -c "
if [ ! -d /mnt/j/EXO ]; then
    mkdir -p /mnt/j 2>/dev/null
    mount -t drvfs J: /mnt/j 2>/dev/null
fi
" 2>$null

# --- 4) Verifier que le venv et les modeles existent ---
$venvCheck = wsl -d Ubuntu-22.04 -- bash -c "
test -f ~/exo_tts_venv/bin/activate && echo VENV_OK || echo VENV_MISSING
test -f ~/exo_tts_models/model.pth && echo MODEL_OK || echo MODEL_MISSING
test -f ~/exo_tts_models/speakers_xtts.pth && echo SPEAKERS_OK || echo SPEAKERS_MISSING
"
if ($venvCheck -match "VENV_MISSING") {
    Write-Host "[TTS-WSL2] ERREUR: venv non trouve. Lancez d'abord setup_tts_wsl2.sh dans WSL2" -ForegroundColor Red
    exit 1
}
if ($venvCheck -match "MODEL_MISSING") {
    Write-Host "[TTS-WSL2] ERREUR: model.pth manquant dans ~/exo_tts_models/" -ForegroundColor Red
    exit 1
}
if ($venvCheck -match "SPEAKERS_MISSING") {
    Write-Host "[TTS-WSL2] ERREUR: speakers_xtts.pth manquant dans ~/exo_tts_models/" -ForegroundColor Red
    exit 1
}
Write-Host "[TTS-WSL2] Venv et modeles OK" -ForegroundColor Green

# --- 5) Copier la derniere version du serveur ---
wsl -d Ubuntu-22.04 -- bash -c "
mkdir -p ~/exo_tts_server
cp /mnt/c/Users/aalou/Exo/scripts/tts_gpu_server.py ~/exo_tts_server/
cp /mnt/c/Users/aalou/Exo/scripts/start_tts_gpu.sh ~/exo_tts_server/
chmod +x ~/exo_tts_server/start_tts_gpu.sh
" 2>$null

# --- 6) Lancer le serveur TTS GPU en arriere-plan ---
Write-Host "[TTS-WSL2] Demarrage du serveur TTS GPU (voice=$Voice, lang=$Lang)..." -ForegroundColor Yellow

$wslCmd = "source ~/exo_tts_venv/bin/activate && " +
          "export HSA_OVERRIDE_GFX_VERSION=10.3.0 && " +
          "export MIOPEN_LOG_LEVEL=2 && " +
          "export HIP_VISIBLE_DEVICES=0 && " +
          "export EXO_SPEAKERS_FILE=~/exo_tts_models/speakers_xtts.pth && " +
          "python3 ~/exo_tts_server/tts_gpu_server.py " +
          "--voice '$Voice' --lang $Lang --port $Port --model-dir ~/exo_tts_models"

$proc = Start-Process -FilePath "wsl" `
    -ArgumentList "-d", "Ubuntu-22.04", "--", "bash", "-c", $wslCmd `
    -PassThru -WindowStyle Minimized

Write-Host "[TTS-WSL2] Processus lance (PID Windows: $($proc.Id))" -ForegroundColor Green

# --- 7) Attendre que le port soit accessible ---
Write-Host "[TTS-WSL2] Attente de la disponibilite du port $Port..." -ForegroundColor Yellow
$elapsed = 0
$ready = $false
while ($elapsed -lt $TimeoutSec -and -not $ready) {
    Start-Sleep -Seconds 2
    $elapsed += 2

    $conn = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Listen' }
    if ($conn) {
        $ready = $true
    }

    if ($elapsed % 10 -eq 0) {
        Write-Host "[TTS-WSL2] En attente... ($elapsed s / $TimeoutSec s)" -ForegroundColor Gray
    }
}

if ($ready) {
    Write-Host "[TTS-WSL2] TTS GPU READY sur ws://localhost:$Port" -ForegroundColor Green
} else {
    Write-Host "[TTS-WSL2] TIMEOUT: le serveur n'a pas demarre en $TimeoutSec s" -ForegroundColor Red
    Write-Host "[TTS-WSL2] Verifiez les logs avec: wsl -d Ubuntu-22.04 -- tail -50 ~/exo_tts_server/tts_gpu.log" -ForegroundColor Yellow
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TTS GPU pret - EXO peut se connecter" -ForegroundColor Green
Write-Host "  ws://localhost:$Port"                   -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
