# 🤖 EXO — Assistant Personnel Intelligent

**Version 4.2 "Premium Open-Source Edition"** | C++ / Qt 6.9.3 | Python / XTTS v2 / Whisper.cpp / FAISS | Home Assistant

![Qt 6.9.3](https://img.shields.io/badge/Qt-6.9.3-green?logo=qt)
![C++17](https://img.shields.io/badge/C++-17-blue?logo=cplusplus)
![Python 3.11](https://img.shields.io/badge/Python-3.11-yellow?logo=python)
![Whisper.cpp](https://img.shields.io/badge/Whisper.cpp-Vulkan%20GPU-orange)
![XTTS v2](https://img.shields.io/badge/XTTS%20v2-TTS%20Neural-green)
![Silero VAD](https://img.shields.io/badge/Silero-VAD%20Neural-purple)
![FAISS](https://img.shields.io/badge/FAISS-Mémoire%20Vectorielle-red)
![OpenWakeWord](https://img.shields.io/badge/OpenWakeWord-Wake%20Word-orange)
![Claude API](https://img.shields.io/badge/Claude-Sonnet-blue?logo=anthropic)
![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Integration-41bdf5?logo=homeassistant)
![Windows 11](https://img.shields.io/badge/Windows-11-0078D4?logo=windows)

---

## Présentation

EXO est un assistant personnel intelligent articulé autour de quatre couches :

- **Moteur C++ / Qt** — pipeline vocal (Silero VAD, DSP, OpenWakeWord), Claude API (SSE + 8 Function Calling), météo, mémoire 3 couches + FAISS vectoriel
- **STT/TTS Python** — Whisper.cpp Vulkan GPU (reconnaissance vocale, RTF 0.08–0.23), XTTS v2 (synthèse vocale neurale multilingue), 7 serveurs WebSocket
- **Backend Python** — pont WebSocket/REST vers Home Assistant (entités, appareils, pièces, 13 actions LLM)
- **Interface QML** — style VS Code (10 composants : Sidebar, Transcript, Response, Visualizer GPU ShaderEffect, etc.)

---

## Démarrage rapide

### Prérequis

| Composant | Version | Usage |
|-----------|---------|-------|
| Windows 11 | — | Plateforme |
| Qt | 6.9.3 MSVC 2022 x64 | C++ / QML |
| CMake | 3.21+ | Build system |
| Visual Studio Build Tools | 2022 | Compilateur |
| Python | 3.11+ | STT/TTS (venv `.venv_stt_tts`) |
| Python | 3.13+ | Backend HA (venv `.venv`) |
| Node.js | 22+ | GUI React (optionnel) |

> **Données & modèles** : tous les modèles IA et données volumineuses résident sur `D:\EXO\` (STT, TTS, FAISS, logs, cache HuggingFace).

### 1. C++ — Compilation & lancement

```powershell
# Configurer & compiler
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="C:\Qt\6.9.3\msvc2022_64"
cd build; cmake --build . --config Debug

# Déployer les DLLs Qt (une seule fois)
C:\Qt\6.9.3\msvc2022_64\bin\windeployqt.exe Debug\RaspberryAssistant.exe --qmldir ..\qml

# Lancer
cd ..; build\Debug\RaspberryAssistant.exe
```

### 2. Python — Serveurs IA (venv STT/TTS)

```powershell
# Créer le venv STT/TTS
python -m venv .venv_stt_tts
.\.venv_stt_tts\Scripts\Activate.ps1
pip install websockets numpy soundfile "transformers>=4.40,<4.50"
pip install "torch==2.4.1" "torchaudio==2.4.1" --index-url https://download.pytorch.org/whl/cpu
pip install torch-directml TTS
pip install silero-vad onnxruntime noisereduce openwakeword faiss-cpu sentence-transformers

# Terminal 1 : serveur STT (ws://localhost:8766)
python src/stt_server.py --backend whispercpp --model large-v3 --device gpu

# Terminal 2 : serveur TTS XTTS v2 GPU (ws://localhost:8767 — RECOMMANDÉ via WSL2)
wsl -d Ubuntu-22.04 -- bash -c "source ~/exo_tts_venv/bin/activate && export HSA_OVERRIDE_GFX_VERSION=10.3.0 && python3 ~/exo_tts_server/tts_gpu_server.py --voice 'Claribel Dervla' --lang fr"
# Ou fallback Windows (DirectML/CPU) :
# python src/tts_server.py --voice "Claribel Dervla" --lang fr

# Terminal 3 : serveur VAD Silero (ws://localhost:8768)
python src/vad_server.py

# Terminal 4 : serveur WakeWord OpenWakeWord (ws://localhost:8770)
python src/wakeword_server.py

# Terminal 5 : serveur Mémoire FAISS (ws://localhost:8771)
python src/memory_server.py

# Terminal 6 : serveur NLU local (ws://localhost:8772)
python src/nlu_server.py
```

### 3. Python — Backend Home Assistant

```powershell
# Créer le venv Backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Terminal 7 : serveur GUI/HA (ws://localhost:8765)
python src/exo_server.py
```

### 4. Lancement rapide (tout-en-un)

```powershell
.\launch_exo.ps1
```

---

## Architecture

```
EXO/
├── src/                        # C++ — moteur principal
│   ├── main.cpp                # Point d'entrée Qt
│   ├── assistantmanager.*      # Orchestrateur FSM
│   ├── voicepipeline.*         # Pipeline vocal (VAD, STT, DSP, WakeWord)
│   ├── ttsmanager.*            # TTS cascade XTTS v2/Qt + DSP 5 étapes
│   ├── configmanager.*         # Config 3 couches (CLI > conf > défaut)
│   ├── claudeapi.*             # Client Anthropic SSE + Function Calling
│   ├── weathermanager.*        # OpenWeatherMap + géolocalisation
│   ├── aimemorymanager.*       # Mémoire 3 couches + bridge FAISS WebSocket
│   ├── logmanager.*            # Logging catégorisé rotatif
│   ├── stt_server.py           # Serveur STT dual backend (port 8766)
│   ├── whisper_cpp.py          # Wrapper Python pour whisper-server.exe (Vulkan)
│   ├── tts_server.py           # Serveur TTS XTTS v2 (port 8767)
│   ├── vad_server.py           # Serveur VAD Silero (port 8768)
│   ├── wakeword_server.py      # Serveur WakeWord OpenWakeWord (port 8770)
│   ├── memory_server.py        # Serveur mémoire FAISS vectoriel (port 8771)
│   ├── nlu_server.py           # Serveur NLU local (port 8772)
│   ├── exo_server.py           # Serveur GUI/HA (port 8765)
│   └── integrations/           # Python — modules Home Assistant
│
├── qml/                        # Interface QML style VS Code
│   ├── MainWindow.qml          # Fenêtre principale
│   └── vscode/                 # 9 composants VS Code
│
├── docs/                       # Documentation
│   ├── EXO_DOCUMENTATION.md    # Doc technique complète v4.2
│   └── ARCHIVES.md             # Plans et prompts historiques (v4.0–v4.2)
│
├── rtaudio/                    # RtAudio (WASAPI, sous-module statique)
├── gui/                        # React 18 + Vite (interface web)
├── config/                     # Configuration (assistant.conf)
├── resources/                  # Polices, icônes
├── scripts/                    # PowerShell utilitaires
├── .env                        # Variables d'environnement (non versionné)
├── requirements.txt            # Dépendances Python backend
└── CMakeLists.txt              # Build CMake
```

### Ports réseau

| Serveur | Port | Rôle |
|---------|------|------|
| `exo_server.py` | 8765 | GUI WebSocket + bridge HA |
| `stt_server.py` | 8766 | Whisper.cpp Vulkan GPU STT (large-v3) |
| `tts_gpu_server.py` (WSL2) | 8767 | XTTS v2 TTS GPU AMD ROCm |
| `vad_server.py` | 8768 | Silero VAD neural |
| `whisper-server` | 8769 | Whisper.cpp HTTP backend (interne) |
| `wakeword_server.py` | 8770 | OpenWakeWord détection neurale |
| `memory_server.py` | 8771 | FAISS mémoire sémantique vectorielle |
| `nlu_server.py` | 8772 | NLU classification d'intention locale |

---

## Configuration

### Variables d'environnement (`.env`)

```ini
CLAUDE_API_KEY=sk-ant-api03-...
OWM_API_KEY=...
HA_URL=http://localhost:8123
HA_TOKEN=votre-token-longue-duree
```

### Fichier `config/assistant.conf`

```ini
[Claude]
api_key=${CLAUDE_API_KEY}
model=claude-sonnet-4-20250514

[STT]
server_url=ws://localhost:8766
backend=whispercpp
model=small

[TTS]
server_url=ws://localhost:8767
backend=xtts
voice=Claribel Dervla
language=fr

[Voice]
wake_word=EXO
language=fr-FR

[VAD]
backend=builtin
server_url=ws://localhost:8768
threshold=0.45

[DSP]
noise_reduction_enabled=true
noise_reduction_strength=0.7

[WakeWord]
neural_enabled=false
server_url=ws://localhost:8770

[Memory]
semantic_enabled=false
semantic_server_url=ws://localhost:8771

[NLU]
local_enabled=false
server_url=ws://localhost:8772
```

---

## Utilisation

1. Dites **"EXO"** → l'assistant passe en mode écoute (détection transcript STT + OpenWakeWord neural)
2. Posez votre question → transcription Whisper → traitement Claude API
3. Réponse vocale XTTS v2 + affichage dans l'interface QML

### Domotique (Home Assistant)

Via le backend Python, EXO contrôle vos appareils HA :
- Allumer / éteindre / basculer des entités
- Régler luminosité, couleur, température
- Contrôler les médias (play, pause, stop)

---

## Documentation

| Document | Contenu |
|----------|---------|
| [docs/EXO_DOCUMENTATION.md](docs/EXO_DOCUMENTATION.md) | Documentation technique complète v4.2 |
| [docs/EXO_SPEC_V4.2.md](docs/EXO_SPEC_V4.2.md) | Spécification concise (source de vérité) |
| [docs/ARCHIVES.md](docs/ARCHIVES.md) | Plans, prompts et réparations historiques (v4.0–v4.2) |
| [COPILOT_MASTER_DIRECTIVE.md](COPILOT_MASTER_DIRECTIVE.md) | Directives obligatoires pour Copilot (12 sections) |

---

## Roadmap

### Réalisé (v4.2 — Premium Open-Source Edition)
- ✅ **RtAudio WASAPI** — capture audio faible latence, abstraction AudioInput (Qt Multimedia/RtAudio, sélectionnable)
- ✅ Interface QML style VS Code (10 composants)
- ✅ Pipeline vocal VoicePipeline v4 (FSM, VAD, StreamingSTT)
- ✅ **XTTS v2** — TTS neural multilingue, 58 voix, streaming PCM16
- ✅ **STT Whisper.cpp + Vulkan GPU** (RTF 0.08–0.23 sur AMD RX 6750 XT)
- ✅ Dual backend STT : whispercpp (GPU) / faster-whisper (CPU fallback)
- ✅ Claude API SSE streaming + 8 Function Calling
- ✅ Mémoire 3 couches (court/long/sémantique)
- ✅ **FAISS + SentenceTransformers** — mémoire sémantique vectorielle (memory_server.py)
- ✅ **Silero VAD** — VAD neural via WebSocket, modes builtin/silero/hybrid
- ✅ **OpenWakeWord** — détection neurale wake-word (complément transcript)
- ✅ **DSP noisereduce** — réduction de bruit spectrale, intensité configurable
- ✅ **NLU local** — classification d'intention locale (regex + framework transformers)
- ✅ **Visualizer GPU** — ShaderEffect GLSL 60 FPS (remplace Canvas CPU)
- ✅ Intégration Home Assistant (13 actions LLM)
- ✅ 7 serveurs Python (STT, TTS, VAD, WakeWord, Memory, NLU, GUI)

### À venir
- 🔄 Google Calendar — agenda intelligent
- 🔄 Streaming musical — Spotify / Tidal
- 🔄 Déploiement Raspberry Pi 5
- 🔄 Interface mobile companion
- 🔄 Docker — déploiement containerisé

---

## Licence

Ce projet est sous licence MIT.

---

**EXO v4.2** — C++ / Qt 6.9.3 · Python · XTTS v2 · Whisper.cpp (Vulkan GPU) · FAISS · Silero · OpenWakeWord