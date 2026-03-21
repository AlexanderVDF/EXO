#!/usr/bin/env bash
# ==========================================================================
# setup_tts_wsl2.sh — Complete setup for XTTS v2 GPU on WSL2 + ROCm/AMD
#
# Usage (run inside WSL2 Ubuntu 22.04):
#   chmod +x ~/exo_tts_server/setup_tts_wsl2.sh
#   sudo ~/exo_tts_server/setup_tts_wsl2.sh
# ==========================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SETUP]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

VENV_DIR="$HOME/exo_tts_venv"
MODEL_DIR="$HOME/exo_tts_models"
SERVER_DIR="$HOME/exo_tts_server"

# ==========================================================================
# 1) System dependencies
# ==========================================================================
log "Installing system dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    python3-venv python3-pip python3-dev \
    build-essential cmake \
    libsndfile1 ffmpeg \
    wget curl git \
    2>&1 | tail -3
log "System dependencies OK"

# ==========================================================================
# 2) Check GPU availability
# ==========================================================================
log "Checking GPU availability..."
if [ -c /dev/dxg ]; then
    log "/dev/dxg present — Windows GPU paravirtualization available"
else
    warn "/dev/dxg NOT found — GPU may not be available"
fi

if [ -c /dev/kfd ]; then
    log "/dev/kfd present — native ROCm available"
else
    warn "/dev/kfd NOT found — native ROCm unavailable (expected in WSL2)"
    warn "Will use PyTorch ROCm with D3D12/DXCore backend"
fi

# ==========================================================================
# 3) Create Python venv
# ==========================================================================
log "Creating Python virtual environment at $VENV_DIR..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip -q

# ==========================================================================
# 4) Install PyTorch ROCm
# ==========================================================================
log "Installing PyTorch ROCm 6.2..."
pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/rocm6.2 \
    2>&1 | tail -5

# ==========================================================================
# 5) Install XTTS v2 dependencies
# ==========================================================================
log "Installing XTTS v2 and dependencies..."
pip install TTS websockets numpy soundfile transformers 2>&1 | tail -5

# ==========================================================================
# 6) Set up ROCm environment for AMD consumer GPUs
# ==========================================================================
log "Configuring ROCm environment..."

BASHRC="$HOME/.bashrc"
if ! grep -q "HSA_OVERRIDE_GFX_VERSION" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'ROCM_ENV'

# === EXO TTS GPU — ROCm environment ===
# Override GFX version for AMD consumer GPUs (RDNA2 = 10.3.0)
export HSA_OVERRIDE_GFX_VERSION=10.3.0
# ROCm paths
export ROCM_HOME=/opt/rocm
export PATH=$ROCM_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ROCM_HOME/lib:$LD_LIBRARY_PATH
# Suppress ROCm warnings in WSL2
export MIOPEN_LOG_LEVEL=2
export HIP_VISIBLE_DEVICES=0
ROCM_ENV
    log "ROCm environment variables added to ~/.bashrc"
else
    log "ROCm environment already in ~/.bashrc"
fi

# Apply immediately
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export MIOPEN_LOG_LEVEL=2
export HIP_VISIBLE_DEVICES=0

# ==========================================================================
# 7) Create model directory
# ==========================================================================
log "Creating model directory at $MODEL_DIR..."
mkdir -p "$MODEL_DIR"

# ==========================================================================
# 8) Test PyTorch GPU
# ==========================================================================
log "Testing PyTorch GPU detection..."
python3 -c "
import torch
print(f'PyTorch: {torch.__version__}')
hip = getattr(torch.version, 'hip', None)
print(f'ROCm HIP: {hip or \"N/A\"}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
    print(f'Devices: {torch.cuda.device_count()}')
    t = torch.randn(512, 512, device='cuda')
    r = torch.mm(t, t)
    print(f'GPU matmul test: OK')
    print('STATUS: GPU_READY')
else:
    print('STATUS: CPU_ONLY')
    print('Note: GPU not detected. XTTS will run on CPU (slower but functional)')
"

# ==========================================================================
# 9) Copy server script
# ==========================================================================
log "Setting up TTS server..."
mkdir -p "$SERVER_DIR"
if [ -f /mnt/c/Users/aalou/Exo/scripts/tts_gpu_server.py ]; then
    cp /mnt/c/Users/aalou/Exo/scripts/tts_gpu_server.py "$SERVER_DIR/"
    log "TTS GPU server copied to $SERVER_DIR"
fi

# ==========================================================================
# Done
# ==========================================================================
log "============================================"
log "  SETUP COMPLETE"
log "============================================"
log "  Venv:    $VENV_DIR"
log "  Models:  $MODEL_DIR"
log "  Server:  $SERVER_DIR/tts_gpu_server.py"
log ""
log "  To copy models from Windows:"
log "    cp /mnt/j/EXO/models/xtts/speakers_xtts.pth ~/exo_tts_models/"
log ""
log "  To start the TTS GPU server:"
log "    source ~/exo_tts_venv/bin/activate"
log "    python3 ~/exo_tts_server/tts_gpu_server.py --voice 'Claribel Dervla' --lang fr"
log "============================================"
