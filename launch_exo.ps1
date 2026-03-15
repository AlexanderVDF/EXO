#!/usr/bin/env powershell
# Script de lancement EXO Assistant
# Utilisation: .\launch_exo.ps1
# Le TTS GPU s'exécute dans WSL2 (XTTS v2 + ROCm/AMD GPU)

Write-Host "Lancement d'EXO Assistant..." -ForegroundColor Cyan

# --- Racines projet ---
$projectDir = "C:\Users\aalou\Exo"
$ssdRoot    = "D:\EXO"

# --- TTS GPU via WSL2 ---
$ttsPort = 8767
$ttsRunning = Get-NetTCPConnection -LocalPort $ttsPort -ErrorAction SilentlyContinue |
    Where-Object { $_.State -eq 'Listen' }
if (-not $ttsRunning) {
    Write-Host "Demarrage du TTS GPU WSL2..." -ForegroundColor Yellow
    & "$projectDir\scripts\launch_tts_wsl2.ps1" -Voice "Claribel Dervla" -Lang "fr" -Port $ttsPort
    $ttsRunning = Get-NetTCPConnection -LocalPort $ttsPort -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Listen' }
    if (-not $ttsRunning) {
        Write-Host "ATTENTION: TTS GPU non disponible - EXO utilisera le fallback Qt TTS" -ForegroundColor Red
    }
} else {
    Write-Host "TTS GPU deja actif sur le port $ttsPort" -ForegroundColor Green
}

# Verifier que l'executable existe
$exePath = "$projectDir\build\Debug\RaspberryAssistant.exe"
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

# --- Variables d'environnement EXO (chemins SSD) ---
$env:EXO_WHISPER_MODELS = "$ssdRoot\models\whisper"
$env:EXO_WHISPERCPP_BIN = "$ssdRoot\whispercpp\build_vk\bin\Release"
$env:EXO_XTTS_MODELS    = "$ssdRoot\models\xtts"
$env:EXO_FAISS_DIR      = "$ssdRoot\faiss\semantic_memory"
$env:EXO_WAKEWORD_MODELS = "$ssdRoot\models\wakeword"
$env:HF_HOME            = "$ssdRoot\cache\huggingface"
$env:TRANSFORMERS_CACHE  = "$ssdRoot\cache\huggingface\hub"
Write-Host "Variables EXO configurees (SSD: $ssdRoot)" -ForegroundColor Green

# Charger les variables d'environnement depuis .env
$envFile = "$projectDir\.env"
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

# Lancer le serveur STT (whisper.cpp) en arriere-plan
$python = "$ssdRoot\venv\exo\Scripts\python.exe"
$sttServer = "$projectDir\src\stt_server.py"

$sttRunning = Get-NetTCPConnection -LocalPort 8766 -ErrorAction SilentlyContinue
if (-not $sttRunning) {
    if (Test-Path $python) {
        Write-Host "Demarrage du serveur STT (whisper.cpp large-v3)..." -ForegroundColor Yellow
        $sttProc = Start-Process -FilePath $python -ArgumentList "$sttServer --backend whispercpp --model large-v3 --language fr" -PassThru -WindowStyle Minimized
        Write-Host "STT server lance (PID: $($sttProc.Id)) - attente connexion..." -ForegroundColor Yellow
        # Attendre que le serveur soit pret (max 30s)
        $timeout = 30
        $elapsed = 0
        while ($elapsed -lt $timeout) {
            Start-Sleep -Seconds 1
            $elapsed++
            $listening = Get-NetTCPConnection -LocalPort 8766 -ErrorAction SilentlyContinue
            if ($listening) {
                Write-Host "STT server pret sur le port 8766" -ForegroundColor Green
                break
            }
        }
        if ($elapsed -ge $timeout) {
            Write-Host "Attention: STT server n'a pas demarre dans les $timeout s" -ForegroundColor Red
        }
    } else {
        Write-Host "Attention: Python venv non trouve - STT server non lance" -ForegroundColor Red
    }
} else {
    Write-Host "STT server deja en cours sur le port 8766" -ForegroundColor Green
}

# Lancer EXO
Write-Host "Demarrage d'EXO..." -ForegroundColor Green
Set-Location "$projectDir\build\Debug"
& .\RaspberryAssistant.exe

# Cleanup: arreter le serveur STT si on l'a lance
if ($sttProc -and -not $sttProc.HasExited) {
    Write-Host "Arret du serveur STT (PID: $($sttProc.Id))..." -ForegroundColor Yellow
    Stop-Process -Id $sttProc.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "EXO ferme." -ForegroundColor Cyan