#!/usr/bin/env powershell
# Script de lancement EXO Assistant
# Utilisation: .\launch_exo.ps1
# TTS GPU via DirectML (XTTS v2 + ONNX Runtime DirectML / AMD GPU)

Write-Host "Lancement d'EXO Assistant..." -ForegroundColor Cyan

# --- Racines projet ---
$projectDir = "C:\Users\aalou\Exo"
$ssdRoot    = "D:\EXO"
$pythonSTT  = "$projectDir\.venv_stt_tts\Scripts\python.exe"

# --- Dossier logs ---
$logDir = "$ssdRoot\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

# --- TTS GPU DirectML ---
$ttsPort = 8767
$ttsRunning = Get-NetTCPConnection -LocalPort $ttsPort -ErrorAction SilentlyContinue |
    Where-Object { $_.State -eq 'Listen' }
if (-not $ttsRunning) {
    $ttsScript = "$projectDir\python\tts\tts_server_directml.py"
    if ((Test-Path $pythonSTT) -and (Test-Path $ttsScript)) {
        Write-Host "Demarrage du TTS GPU DirectML (XTTS v2)..." -ForegroundColor Yellow
        $ttsProc = Start-Process -FilePath $pythonSTT -ArgumentList "$ttsScript --voice `"Claribel Dervla`" --lang fr" -PassThru -WindowStyle Minimized -RedirectStandardOutput "$logDir\tts_stdout.log" -RedirectStandardError "$logDir\tts_stderr.log"
        Write-Host "TTS DirectML lance (PID: $($ttsProc.Id)) - attente demarrage..." -ForegroundColor Yellow
        $timeout = 120
        $elapsed = 0
        while ($elapsed -lt $timeout) {
            Start-Sleep -Seconds 2
            $elapsed += 2
            $listening = Get-NetTCPConnection -LocalPort $ttsPort -ErrorAction SilentlyContinue |
                Where-Object { $_.State -eq 'Listen' }
            if ($listening) {
                Write-Host "TTS DirectML pret sur le port $ttsPort" -ForegroundColor Green
                break
            }
        }
        if ($elapsed -ge $timeout) {
            Write-Host "ATTENTION: TTS DirectML non demarre dans les ${timeout}s - fallback Qt TTS" -ForegroundColor Red
        }
    } else {
        Write-Host "ATTENTION: TTS DirectML non disponible - EXO utilisera le fallback Qt TTS" -ForegroundColor Red
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
$sttServer = "$projectDir\python\stt\stt_server.py"

$sttRunning = Get-NetTCPConnection -LocalPort 8766 -ErrorAction SilentlyContinue
if (-not $sttRunning) {
    if (Test-Path $pythonSTT) {
        Write-Host "Demarrage du serveur STT (whisper.cpp medium)..." -ForegroundColor Yellow
        $sttProc = Start-Process -FilePath $pythonSTT -ArgumentList "$sttServer --backend whispercpp --model medium --beam-size 3 --language fr" -PassThru -WindowStyle Minimized -RedirectStandardOutput "$logDir\stt_stdout.log" -RedirectStandardError "$logDir\stt_stderr.log"
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
        Write-Host "Attention: Python venv non trouve ($pythonSTT) - STT server non lance" -ForegroundColor Red
    }
} else {
    Write-Host "STT server deja en cours sur le port 8766" -ForegroundColor Green
}

# Lancer EXO
Write-Host "Demarrage d'EXO..." -ForegroundColor Green
Set-Location "$projectDir\build\Debug"
Write-Host "EXO demarre a $(Get-Date -Format 'HH:mm:ss') - logs dans $logDir" -ForegroundColor Cyan
& .\RaspberryAssistant.exe 2>&1 | Tee-Object -FilePath "$logDir\exo_console.log"
$exoExitCode = $LASTEXITCODE
Write-Host "EXO termine avec code: $exoExitCode a $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor $(if ($exoExitCode -eq 0) { 'Green' } else { 'Red' })

# Cleanup: arreter les serveurs lances
if ($ttsProc -and -not $ttsProc.HasExited) {
    Write-Host "Arret du serveur TTS DirectML (PID: $($ttsProc.Id))..." -ForegroundColor Yellow
    Stop-Process -Id $ttsProc.Id -Force -ErrorAction SilentlyContinue
}
if ($sttProc -and -not $sttProc.HasExited) {
    Write-Host "Arret du serveur STT (PID: $($sttProc.Id))..." -ForegroundColor Yellow
    Stop-Process -Id $sttProc.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "EXO ferme." -ForegroundColor Cyan