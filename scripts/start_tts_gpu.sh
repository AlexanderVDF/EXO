#!/usr/bin/env bash
# ==========================================================================
# start_tts_gpu.sh — Launch EXO TTS GPU Server in WSL2
#
# Usage:
#   ~/exo_tts_server/start_tts_gpu.sh
#   ~/exo_tts_server/start_tts_gpu.sh --voice "Claribel Dervla" --lang fr
# ==========================================================================

set -euo pipefail

VENV_DIR="$HOME/exo_tts_venv"
SERVER_DIR="$HOME/exo_tts_server"
MODEL_DIR="$HOME/exo_tts_models"

# ROCm environment for AMD consumer GPUs
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export MIOPEN_LOG_LEVEL=2
export HIP_VISIBLE_DEVICES=0

# Model path
export EXO_SPEAKERS_FILE="$MODEL_DIR/speakers_xtts.pth"

# Activate venv
source "$VENV_DIR/bin/activate"

echo "[TTS-GPU] Starting EXO TTS GPU Server..."
echo "[TTS-GPU] Device: ROCm/HIP (AMD GPU via WSL2)"
echo "[TTS-GPU] Models: $MODEL_DIR"
echo "[TTS-GPU] Port: 8767 (ws://0.0.0.0:8767)"

# Check if port is already in use
if ss -tlnp 2>/dev/null | grep -q ":8767 "; then
    echo "[TTS-GPU] WARNING: Port 8767 already in use!"
    echo "[TTS-GPU] Kill existing process or use --port <other>"
fi

# Launch server with any additional args
exec python3 "$SERVER_DIR/tts_gpu_server.py" \
    --model-dir "$MODEL_DIR" \
    "$@"
