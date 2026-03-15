# EXO Assistant — Documentation Technique Complète

**Version 4.2 "Premium Open-Source Edition"** | Dernière mise à jour : Mars 2026

---

## Table des matières

1. [Présentation](#-présentation)
2. [Installation](#-installation)
3. [Architecture générale](#-architecture-générale)
4. [Moteur C++ / Qt](#-moteur-c--qt)
5. [Pipeline vocal](#-pipeline-vocal)
6. [Synthèse vocale (TTS)](#-synthèse-vocale-tts)
7. [Reconnaissance vocale (STT)](#-reconnaissance-vocale-stt)
8. [Serveurs Python](#-serveurs-python)
9. [Backend Python / Home Assistant](#-backend-python--home-assistant)
10. [GUI React](#-gui-react)
11. [Interface QML](#-interface-qml)
12. [Configuration](#-configuration)
13. [Météo & Géolocalisation](#-météo--géolocalisation)
14. [Mémoire persistante](#-mémoire-persistante)
15. [Claude API & Function Calling](#-claude-api--function-calling)
16. [Home Assistant — Détail technique](#-home-assistant--détail-technique)
17. [Logging](#-logging)
18. [Tests](#-tests)
19. [Dépannage](#-dépannage)
20. [Changelog](#-changelog)
21. [Roadmap](#-roadmap)

---

## 🎯 Présentation

EXO est un assistant personnel intelligent articulé autour de quatre couches :

| Couche | Technologie | Rôle |
|--------|-------------|------|
| **Moteur** | C++17 / Qt 6.9.3 | Audio, IA conversationnelle, météo, mémoire, DSP |
| **STT/TTS** | Python 3.11 / Whisper / XTTS v2 | Reconnaissance et synthèse vocale via WebSocket |
| **Backend** | Python 3.13 / aiohttp / websockets | Pont Home Assistant, orchestrateur GUI |
| **Frontends** | React 18 + QML (VS Code style) | Interfaces utilisateur web & native |

---

## 🚀 Installation

### Prérequis

- **Windows 11** avec PowerShell
- **Qt 6.9.3** MSVC 2022 x64 (`C:\Qt\6.9.3\msvc2022_64`)
- **CMake 3.21+** et **Visual Studio Build Tools 2022**
- **Python 3.11** (pour STT/TTS servers)
- **Python 3.13** (optionnel, pour le serveur GUI/HA)
- **Node.js 22+** (pour la GUI React)
- Clés API : Claude (Anthropic), OpenWeatherMap, token Home Assistant

### Étape 1 — Cloner & configurer

```powershell
git clone https://github.com/AlexanderVDF/EXO.git
cd EXO

# Créer le fichier d'environnement
copy .env.example .env
# Renseigner CLAUDE_API_KEY, OWM_API_KEY, HA_URL, HA_TOKEN
```

### Étape 2 — Compiler le moteur C++

```powershell
# Compilation standard (RtAudio WASAPI activé par défaut)
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="C:\Qt\6.9.3\msvc2022_64"
cd build
cmake --build . --config Debug

# Sans RtAudio (Qt Multimedia uniquement)
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="C:\Qt\6.9.3\msvc2022_64" -DENABLE_RTAUDIO=OFF
```

L'exécutable est généré dans `build\Debug\RaspberryAssistant.exe`.

**Déploiement des DLL Qt** (première fois) :

```powershell
C:\Qt\6.9.3\msvc2022_64\bin\windeployqt.exe build\Debug\RaspberryAssistant.exe --qmldir qml
```

### Étape 3 — Installer l'environnement Python STT/TTS

```powershell
python -m venv .venv_stt_tts
.\.venv_stt_tts\Scripts\activate
pip install websockets numpy soundfile "transformers>=4.40,<4.50"
pip install "torch==2.4.1" "torchaudio==2.4.1" --index-url https://download.pytorch.org/whl/cpu
pip install torch-directml TTS
```

> **Note** : Le backend GPU par défaut (whisper.cpp) utilise des binaires pré-compilés dans `whisper.cpp/build_vk/bin/Release/`. Le modèle GGML doit être dans `whisper.cpp/models/` (ex: `ggml-small.bin`). `faster-whisper` est optionnel (fallback CPU uniquement).

> **Note RtAudio** : L'option CMake `ENABLE_RTAUDIO` (ON par défaut) compile le backend RtAudio (WASAPI sur Windows) pour une capture audio à faible latence. Le backend audio Qt Multimedia reste disponible. Le choix se fait via `[Audio] backend=qt` ou `backend=rtaudio` dans `assistant.conf`.

### Étape 4 — Installer le backend Python

```powershell
pip install -r requirements.txt
```

Dépendances : `aiohttp >=3.9`, `websockets >=12`, `pytest >=8`, `pytest-asyncio >=0.23`.

### Étape 5 — Installer la GUI React

```powershell
cd gui
npm install
```

### Lancement

```powershell
# Méthode automatique (recommandée) — lance le moteur C++
.\launch_exo.ps1

# Ou manuellement : 7 serveurs Python + moteur C++
# Terminal 1 — Serveur GUI/HA
python src/exo_server.py

# Terminal 2 — Serveur STT (Whisper.cpp GPU)
.\.venv_stt_tts\Scripts\python.exe src/stt_server.py --backend whispercpp --model large-v3 --device gpu

# Terminal 3 — Serveur TTS (XTTS v2 GPU via WSL2 — RECOMMANDÉ)
wsl -d Ubuntu-22.04 -- bash -c "source ~/exo_tts_venv/bin/activate && export HSA_OVERRIDE_GFX_VERSION=10.3.0 && python3 ~/exo_tts_server/tts_gpu_server.py --voice 'Claribel Dervla' --lang fr"
# Ou fallback Windows (DirectML/CPU) :
# .\.venv_stt_tts\Scripts\python.exe src/tts_server.py --voice "Claribel Dervla" --lang fr

# Terminal 4 — Serveur VAD Silero (optionnel)
.\.venv_stt_tts\Scripts\python.exe src/vad_server.py

# Terminal 5 — Serveur WakeWord OpenWakeWord (optionnel)
.\.venv_stt_tts\Scripts\python.exe src/wakeword_server.py

# Terminal 6 — Serveur Mémoire FAISS (optionnel)
.\.venv_stt_tts\Scripts\python.exe src/memory_server.py

# Terminal 7 — Serveur NLU local (optionnel)
.\.venv_stt_tts\Scripts\python.exe src/nlu_server.py

# Terminal 8 — Moteur C++
build\Debug\RaspberryAssistant.exe

# GUI React (optionnel)
cd gui && npm run dev
```

Le script `launch_exo.ps1` ajoute Qt au PATH, charge les variables `.env` et lance l'exécutable.

### Chemins de données (SSD D:\EXO\)

Tous les modèles et données volumineuses résident sur le SSD dédié `D:\EXO\` :

| Répertoire | Contenu |
|------------|---------|
| `D:\EXO\models\whisper\` | Modèles GGML Whisper (ggml-large-v3.bin) |
| `D:\EXO\models\xtts\` | Modèles XTTS v2 |
| `D:\EXO\models\wakeword\` | Modèles OpenWakeWord |
| `D:\EXO\whispercpp\` | Binaires whisper.cpp (Vulkan) |
| `D:\EXO\faiss\` | Index FAISS mémoire sémantique |
| `D:\EXO\logs\` | Logs applicatifs |
| `D:\EXO\cache\huggingface\` | Cache HuggingFace / Transformers |

> **Note** : Ancien chemin `J:\EXO\` obsolète — migré vers `D:\EXO\` (SSD).

---

## 🏗️ Architecture générale

```
EXO/
├── src/                           # Moteur C++ + Backend Python
│   ├── main.cpp                   # Point d'entrée Windows
│   ├── assistantmanager.cpp/.h    # Coordinateur central v4
│   ├── configmanager.cpp/.h       # Config 3 couches (.env > user > conf)
│   ├── claudeapi.cpp/.h           # Client SSE Anthropic + Function Calling
│   ├── voicepipeline.cpp/.h       # Pipeline audio (VAD + STT + FSM)
│   ├── ttsmanager.cpp/.h          # TTS cascade (XTTS v2 → Qt) + DSP
│   ├── weathermanager.cpp/.h      # OpenWeatherMap + géoloc IP
│   ├── aimemorymanager.cpp/.h     # Mémoire 3 couches (conversations, prefs, sémantique)
│   ├── logmanager.cpp/.h          # Logging par catégories (hVoice, hClaude...)
│   ├── audio/                     # ★ Couche d'abstraction audio (v4.2)
│   │   ├── audioinput.h           # Interface abstraite AudioInput
│   │   ├── audioinput_qt.h/.cpp   # Backend Qt Multimedia (QAudioSource)
│   │   └── audioinput_rtaudio.h/.cpp  # Backend RtAudio WASAPI (optionnel)
│   ├── stt_server.py              # Serveur STT WebSocket (Whisper.cpp GPU / faster-whisper CPU)
│   ├── tts_server.py              # Serveur TTS WebSocket (XTTS v2 multi-voix)
│   ├── vad_server.py              # Serveur VAD Silero (port 8768)
│   ├── wakeword_server.py         # Serveur WakeWord OpenWakeWord (port 8770)
│   ├── memory_server.py           # Serveur mémoire FAISS vectoriel (port 8771)
│   ├── nlu_server.py              # Serveur NLU local (port 8772)
│   ├── exo_server.py              # Serveur Python principal (GUI + HA)
│   ├── whisper_cpp.py             # Wrapper Python pour whisper-server.exe (Vulkan)
│   └── integrations/              # Modules Home Assistant
│       ├── __init__.py
│       ├── home_bridge.py         # WebSocket + REST + EventBus
│       ├── ha_entities.py         # Cache & requêtes entités
│       ├── ha_devices.py          # Appareils (MAC/IP matching)
│       ├── ha_areas.py            # Pièces (Plans ↔ HA sync)
│       ├── ha_actions.py          # 13 actions LLM Function Calling
│       ├── ha_sync.py             # Synchronisation complète
│       └── tests/                 # 92 tests pytest
│
├── gui/                           # Interface React
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js             # Port 3000, proxy WS
│   ├── tailwind.config.js         # Palette EXO (#6C5CE7, #00CEC9)
│   └── src/
│       ├── App.jsx, main.jsx, index.css
│       ├── components/            # Avatar, Card, Icon, Sidebar, TopBar...
│       ├── screens/               # Home, Plans, NetworkMap, Devices, Settings
│       ├── hooks/                 # useWebSocket (auto-reconnect)
│       └── theme/
│
├── qml/                           # Interface QML native
│   ├── MainWindow.qml             # ★ Interface principale VS Code style
│   └── vscode/                    # ★ 10 composants VS Code style (v4)
│       ├── Sidebar.qml            # Barre latérale icônes
│       ├── StatusIndicator.qml    # État pipeline (idle/listening/speaking)
│       ├── MicrophoneLevel.qml    # Niveau micro temps réel
│       ├── TranscriptView.qml     # Transcription STT
│       ├── ResponseView.qml       # Réponse Claude
│       ├── Visualizer.qml         # Visualiseur audio ShaderEffect GPU
│       ├── BottomBar.qml          # Barre de statut inférieure
│       ├── SettingsPanel.qml      # Panneau configuration (audio, STT, TTS, VAD, DSP…)
│       ├── HistoryPanel.qml       # Historique conversations
│       └── LogPanel.qml           # Panneau logs temps réel
│
├── rtaudio/                       # Bibliothèque RtAudio (sous-module, WASAPI)
│
├── config/
│   ├── assistant.conf              # Config par défaut (lecture seule)
│   ├── assistant_local.conf        # Config locale (non versionné)
│   └── environment.example         # Template Raspberry Pi
│
├── resources/
│   ├── fonts/
│   └── icons/
│
├── scripts/
│   ├── benchmark_stt.py
│   ├── check_dependencies.ps1
│   ├── cleanup.ps1
│   ├── install_dependencies.ps1
│   ├── quick_build.ps1
│   ├── test_environment.ps1
│   └── verify_project.ps1
│
├── whisper.cpp/                    # Whisper.cpp (Vulkan GPU) — sous-module
│
├── docs/                           # Documentation unifiée
│   ├── EXO_DOCUMENTATION.md        # ★ Ce fichier — doc technique complète
│   ├── EXO_SPEC_V4.2.md            # Spécification concise (source de vérité)
│   └── ARCHIVES.md                 # Plans, prompts et réparations historiques (v4.0–v4.2)
│
├── CMakeLists.txt                  # Build CMake (Qt6, v4.2.0, option ENABLE_RTAUDIO)
├── requirements.txt                # Dépendances Python (aiohttp, websockets, silero-vad, faiss-cpu...)
├── pyproject.toml                  # Config pytest
├── .env                            # Variables secrètes (non versionné)
├── launch_exo.ps1                  # Script de lancement
└── README.md                       # Présentation GitHub
```

### Diagramme de communication

```
┌──────────────────────────────────────────────────────────────┐
│              RaspberryAssistant (C++ / Qt 6.9.3)             │
│                                                              │
│  AssistantManager                                            │
│  ├── ConfigManager ──── 3 couches (.env > user > conf)       │
│  ├── ClaudeAPI ──────── SSE streaming + 8 Function Tools     │
│  ├── VoicePipeline ──── Audio 16kHz + VAD + Wake Word        │
│  │   ├── StreamingSTT ─── ws://localhost:8766 ──┐            │
│  │   └── TTSManager ───── ws://localhost:8767 ──┼──┐         │
│  ├── WeatherManager ─── OpenWeatherMap + Géoloc  │  │         │
│  └── AIMemoryManager ── JSON 3 couches + FAISS   │  │         │
└──────────────────────────────────┬───────────────┘  │         │
                                   │                  │         │
          ┌────────────────────────▼──────┐  ┌───────▼─────┐  │
          │   stt_server.py               │  │ tts_server  │  │
          │   (Whisper.cpp GPU)           │  │ (XTTS v2)   │  │
          │   :8766 (WebSocket)           │  │ :8767 (WS)  │  │
          └───────────────────────────────┘  └─────────────┘  │
          ┌───────────────┐ ┌───────────────┐ ┌────────────┐  │
          │ vad_server.py │ │ wakeword_srv  │ │ memory_srv │  │
          │ (Silero VAD)  │ │ (OpenWakeWord)│ │ (FAISS)    │  │
          │ :8768 (WS)    │ │ :8770 (WS)    │ │ :8771 (WS) │  │
          └───────────────┘ └───────────────┘ └────────────┘  │
          ┌───────────────┐                                   │
          │ nlu_server.py │                                   │
          │ (NLU local)   │                                   │
          │ :8772 (WS)    │                                   │
          └───────────────┘                                   │
                                                              │
              ┌─────────────────────────┐                     │
              │    GUI React            │     ws://localhost:8765
              │  http://localhost:3000  │─────────┐            │
              └─────────────────────────┘         │            │
                                        ┌─────────▼───────────┘
                                        │   exo_server.py
                                        │   (Python asyncio)
                                        │   :8765 (WebSocket)
                                        │
                                        │  HomeBridge · Sync
                                        │  Entities · Devices
                                        │  Areas · Actions
                                        └───────────┬──────────
                                                    │ WebSocket + REST
                                                    │ ws://HA_URL/api/websocket
                                        ┌───────────▼───────────┐
                                        │   Home Assistant      │
                                        │   (http://HA_URL)     │
                                        └───────────────────────┘
```

### Ports réseau

| Port | Protocole | Service | Processus |
|------|-----------|---------|-----------|
| 8765 | WebSocket | GUI / Home Assistant bridge | exo_server.py |
| 8766 | WebSocket | Speech-to-Text (Whisper) | stt_server.py |
| 8767 | WebSocket | Text-to-Speech (XTTS v2) | tts_gpu_server.py (WSL2) / tts_server.py (fallback) |
| 8768 | WebSocket | VAD Silero neural | vad_server.py |
| 8769 | HTTP | Whisper.cpp backend interne | whisper-server.exe |
| 8770 | WebSocket | WakeWord OpenWakeWord | wakeword_server.py |
| 8771 | WebSocket | Mémoire FAISS vectorielle | memory_server.py |
| 8772 | WebSocket | NLU classification locale | nlu_server.py |
| 3000 | HTTP | GUI React (Vite dev) | npm run dev |

---

## ⚙️ Moteur C++ / Qt

### Modules Qt utilisés

Définis dans `CMakeLists.txt` :

| Module | Usage |
|--------|-------|
| Core | Types fondamentaux, signaux/slots |
| Quick | Moteur QML |
| QuickControls2 | Material Design (Dark theme) |
| Widgets | Widgets natifs |
| Network | HTTP REST (Claude, OWM, géoloc) |
| Multimedia | QAudioSource / QAudioSink / DSP |
| MultimediaWidgets | — |
| TextToSpeech | Synthèse vocale Qt (fallback) |
| WebSockets | Communication STT/TTS/GUI |
| Sql | Stockage local |

### Composants principaux

#### AssistantManager (v4)
Coordinateur central. Instancie et connecte tous les managers via signaux/slots Qt. Expose des Q_PROPERTY et Q_INVOKABLE au QML. Dispatch les Function Calls Claude vers Home Assistant via VoicePipeline WebSocket. Auto-analyse les réponses Claude pour extraction mémoire.

#### ConfigManager (v4)
Système à **3 couches** de priorité :

```
.env (secrets) → user_config.ini (prefs) → assistant.conf (défauts)
                  ↑ Priorité maximale
```

- **Variables d'environnement** : `.env` chargé au démarrage (`loadDotEnv()`)
- **Préférences utilisateur** : `%APPDATA%\EXOAssistant\user_config.ini` (QSettings)
- **Configuration base** : `config/assistant.conf` (lecture seule)

API générique : `getString()`, `getInt()`, `getDouble()`, `getBool()`, `setUserValue()`.  
Raccourcis spécialisés : `getClaudeApiKey()`, `getSTTServerUrl()`, `getTTSServerUrl()`, `getVADThreshold()`, etc.

Constantes par défaut (constexpr) :
```
DEFAULT_CLAUDE_MODEL     = "claude-sonnet-4-20250514"
DEFAULT_STT_SERVER_URL   = "ws://localhost:8766"
DEFAULT_TTS_SERVER_URL   = "ws://localhost:8767"
DEFAULT_GUI_SERVER_URL   = "ws://localhost:8765"
DEFAULT_STT_MODEL        = "large-v3"
DEFAULT_TTS_VOICE         = "Claribel Dervla"
DEFAULT_VAD_THRESHOLD    = 0.45
```

#### ClaudeAPI (v4)
Client SSE streaming pour l'API Anthropic (`https://api.anthropic.com/v1/messages`). Function Calling avec 8 outils EXO. Retry exponentiel (3 tentatives). Rate limiting (50 req/min). Modèle : `claude-sonnet-4-20250514`.

- `sendMessageFull(userMsg, systemPrompt, tools[], stream=true)`
- `sendToolResult(toolUseId, resultObj)` — réponse aux appels d'outils
- `buildEXOTools()` → 8 outils Function Calling (météo, HA, mémoire...)

#### WeatherManager
OpenWeatherMap avec mise à jour automatique toutes les 10 minutes. Conseils vestimentaires basés sur température et conditions. Géolocalisation IP via ip-api.com (HTTPS).

#### AudioInput — Abstraction audio (v4.2)

Couche d'abstraction pour la capture audio, permettant de choisir entre Qt Multimedia et RtAudio WASAPI :

```
AudioInput (interface abstraite, src/audio/audioinput.h)
├── AudioInputQt     → QAudioSource (Qt Multimedia, compatible universel)
└── AudioInputRtAudio → RtAudio WASAPI (Windows, faible latence, compilé si ENABLE_RTAUDIO=ON)
```

| Méthode | Description |
|---------|-------------|
| `open(sampleRate, channels)` | Configure le format audio |
| `start()` | Démarre la capture |
| `stop()` | Arrête la capture |
| `suspend()` / `resume()` | Pause/reprise (pendant TTS) |
| `setCallback(fn)` | Callback `void(const int16_t*, int)` pour les échantillons |

Le backend est sélectionné via `[Audio] backend=qt` ou `backend=rtaudio` dans `assistant.conf`, ou via le ComboBox dans SettingsPanel.qml.

#### AIMemoryManager (v4)
Mémoire à **3 couches** :
- **Conversations** : buffer circulaire de 100 échanges
- **Préférences** : auto-détection regex (25+ patterns)
- **Souvenirs sémantiques** : extraction de faits avec décroissance d'importance

Persistance JSON v2 dans `%APPDATA%\EXOAssistant\`. Écritures atomiques (write → rename).

**Bridge FAISS (v4.2)** : Lorsque `[Memory] semantic_enabled=true`, AIMemoryManager se connecte en WebSocket à `memory_server.py` (:8771) pour indexer et rechercher les souvenirs par similarité vectorielle (FAISS + SentenceTransformers `all-MiniLM-L6-v2`). Les recherches vectorielles sont prioritaires, avec fallback sur la recherche regex locale.

---

## 🔊 Pipeline vocal

### Machine à états (FSM)

```
┌──────┐  VAD détecte  ┌─────────────────┐  >300ms  ┌───────────┐
│ Idle │──────────────→│ DetectingSpeech  │─────────→│ Listening │
└──┬───┘               └─────────────────┘          └─────┬─────┘
   │                                                       │ Silence détecté
   │ TTS terminé                                          ▼
   │ + guard 1.5s     ┌──────────┐             ┌──────────────────┐
   │←─────────────────│ Speaking │←────────────│  Transcribing    │
   │                  └──────────┘   Claude →  └────────┬─────────┘
   │                       ↑         TTS                │ STT final
   │                       │                            ▼
   │                  ┌──────────┐             ┌──────────────────┐
   │                  │ Thinking │←────────────│  Wake word check │
   │                  └──────────┘             └──────────────────┘
```

Les 6 états : `Idle`, `DetectingSpeech`, `Listening`, `Transcribing`, `Thinking`, `Speaking`.

### VoicePipeline (v4)

Le pipeline audio complet orchestré par la classe `VoicePipeline` :

1. **Capture** : AudioInput abstraction (RtAudio WASAPI ou Qt Multimedia) @ 16 kHz, mono, Int16
2. **Prétraitement** : Butterworth high-pass 2nd ordre (150 Hz), noise gate, AGC
3. **VAD** : Détecteur d'activité vocale (builtin énergie+ZCR ou Silero neural via vad_server.py, seuil configurable 0.45)
4. **Wake word** : Détection logicielle "EXO" dans le transcript STT + OpenWakeWord neural (wakeword_server.py, score > 0.7)
5. **STT** : Streaming vers `stt_server.py` via WebSocket (Whisper.cpp Vulkan GPU / faster-whisper CPU)
6. **NLU** : Classification locale (nlu_server.py) ou envoi à ClaudeAPI avec contexte conversationnel
7. **TTS** : Synthèse via TTSManager (cascade XTTS v2 → Qt TTS)

#### Classe StreamingSTT

Client WebSocket connecté à `stt_server.py` sur `ws://localhost:8766`.

```
┌── startUtterance ──→ {"type":"start"} ──→ stt_server.py
│   feedAudio(pcm)  ──→ Binary PCM16     ──→ (Whisper inference)
│   endUtterance    ──→ {"type":"end"}    ──→
│                   ←── {"type":"partial","text":"..."} ←──
│                   ←── {"type":"final","text":"...","segments":[...]} ←──
└──────────────────────────────────────────────────────
```

#### AudioPreprocessor

DSP sur le signal d'entrée micro :
- Butterworth high-pass 2nd ordre (coupe <150 Hz)
- Noise gate (seuil RMS 0.005)
- AGC automatique

#### VADEngine

Trois backends disponibles (configurable via `[VAD] backend`) :
- **Builtin** : heuristique énergie + ZCR (toujours disponible, ~600ms calibration)
- **Silero** : VAD neural via vad_server.py (:8768), modèle Silero VAD ONNX
- **Hybrid** : combinaison builtin + Silero pour une détection optimale

---

## 🗣️ Synthèse vocale (TTS)

### Architecture cascade

```
TTSManager::speakText("Bonjour Alex")
    │
    ▼
TTSWorker (thread dédié "EXO-TTS")
    ├── tryPythonTTS() ──→ ws://localhost:8767 (XTTS v2 TTS)
    │   └── Si connecté : PCM16 chunks via WebSocket
    │
    └── tryQtTTS() ──→ QTextToSpeech (Microsoft Julie, fallback)
        └── Si XTTS échoue : synthèse locale Windows
```

**Priorité** : XTTS v2 TTS (Python/WebSocket) → Qt TextToSpeech (fallback local).

### Pipeline DSP audio

Chaîne de traitement appliquée à chaque chunk PCM16 avant lecture :

```
PCM16 brut → EQ (3kHz +3dB) → Compresseur (-18dB, 2:1) → Normalisation (-14dBFS) → Fade in/out → Anti-clip → QAudioSink
```

| Étage | Classe | Paramètres |
|-------|--------|------------|
| **EQ présence** | TTSEqualizer | 3 kHz, +3 dB, Q=1.0 (peaking biquad) |
| **Compresseur** | TTSCompressor | -18 dBFS, ratio 2:1, attaque 5ms, relâche 50ms |
| **Normalisation** | TTSNormalizer | Cible -14 dBFS peak (max +20 dB) |
| **Fade** | TTSFade | In 5ms, out 10ms (cosinus surélevé) |
| **Anti-clip** | — | Hard limiter ±1.0 |

### Analyse prosodique

Avant synthèse, le texte est analysé pour ajuster pitch, débit et volume :
- Questions (`?`) : pitch +0.08, débit +0.05
- Exclamations (`!`) : pitch +0.06, volume +0.08
- Phrases courtes (<5 mots) : débit -0.1
- Phrases longues (>20 mots) : débit +0.05

### Sortie audio

- **Device** : `QAudioSink` (Haut-parleurs Realtek par défaut)
- **Format** : 16000 Hz, 1 canal, Int16
- **Buffer PCM** : accumulateur `m_pcmBuffer` vidé par timer 20ms (`pumpBuffer`)
- **Drain** : à la fin de la synthèse, le buffer est vidé entièrement avant `finalizeSpeech()`

### XTTS v2 TTS (serveur Python)

- **Voix** : `Claribel Dervla` (58 voix intégrées, auto-téléchargement HuggingFace)
- **Sample rate** : 24000 Hz
- **Protocole** : `{"type":"synthesize","text":"...","rate":1.0,"pitch":1.0}` → chunks PCM16 binaires → `{"type":"end"}`
- **Performance** : RTF ~0.05 (20× temps réel sur GPU AMD ROCm via WSL2)

---

## 🎤 Reconnaissance vocale (STT)

### Backends STT (v4.1)

EXO supporte deux backends STT, sélectionnables via `assistant.conf` :

| Backend | Moteur | Device | Performance | Modèle recommandé |
|---------|--------|--------|-------------|-------------------|
| **whispercpp** (défaut) | Whisper.cpp + Vulkan GPU | AMD/NVIDIA/Intel GPU | RTF 0.08–0.23 | ggml-large-v3.bin |
| **faster_whisper** (fallback) | faster-whisper (CTranslate2) | CPU (ou CUDA) | RTF 1.0–1.5 | small |

**Configuration** :
- `backend=whispercpp` — Whisper.cpp via whisper-server.exe HTTP (Vulkan GPU, port 8769)
- `backend=faster_whisper` — faster-whisper CPU classique
- `backend=auto` — essaie whispercpp, fallback sur faster_whisper

**Whisper.cpp (Vulkan)** :
- Binaires compilés dans `D:\EXO\whispercpp\build_vk\bin\Release\`
- Modèles GGML dans `D:\EXO\models\whisper\` (ex: `ggml-large-v3.bin`)
- `whisper_cpp.py` gère le sous-processus whisper-server.exe
- GPU testé : AMD Radeon RX 6750 XT (Vulkan 1.3.290)

- **Langue** : français (`fr`)
- **Beam size** : 5

### Protocole WebSocket (port 8766)

| Direction | Message | Description |
|-----------|---------|-------------|
| → | `{"type":"start"}` | Début d'utterance |
| → | Binary PCM16 | Chunks audio 16kHz mono |
| → | `{"type":"end"}` | Fin d'utterance |
| → | `{"type":"config","language":"fr","beam_size":5}` | Configuration |
| → | `{"type":"cancel"}` | Annulation |
| ← | `{"type":"partial","text":"..."}` | Transcription partielle |
| ← | `{"type":"final","text":"...","segments":[...],"duration":float}` | Transcription finale |

---

## 🐍 Serveurs Python

### Environnements virtuels

| Venv | Python | Usage | Dépendances |
|------|--------|-------|-------------|
| `.venv_stt_tts` | 3.11 | STT + TTS + IA servers | websockets, numpy, TTS, torch, torchaudio, torch-directml, transformers, silero-vad, onnxruntime, noisereduce, openwakeword, faiss-cpu, sentence-transformers |
| `.venv` | 3.13 | GUI server + HA | aiohttp, websockets |

### `stt_server.py` — Reconnaissance vocale

Serveur WebSocket sur `:8766`. Backend dual : Whisper.cpp (Vulkan GPU) ou faster-whisper (CPU). Intègre DSP noisereduce (réduction de bruit spectrale, intensité configurable).

```powershell
# Backend GPU par défaut (whisper.cpp + Vulkan)
.\.venv_stt_tts\Scripts\python.exe src/stt_server.py --backend whispercpp --model large-v3 --device gpu

# Fallback CPU
.\.venv_stt_tts\Scripts\python.exe src/stt_server.py --backend faster_whisper --model small

# Auto (essaie GPU, fallback CPU)
.\.venv_stt_tts\Scripts\python.exe src/stt_server.py --backend auto
```

### `tts_server.py` — Synthèse vocale XTTS v2

Serveur WebSocket sur `:8767`. Encapsule Coqui XTTS v2 avec 58 voix intégrées (défaut: `Claribel Dervla`).

```powershell
.\.venv_stt_tts\Scripts\python.exe src/tts_server.py --voice "Claribel Dervla" --lang fr
# Options: --voice <speaker> --lang fr --port 8767
```

Le modèle XTTS v2 (~1.87 Go) est auto-téléchargé dans `~\AppData\Local\tts\`.

### `vad_server.py` — VAD Silero

Serveur WebSocket sur `:8768`. Détection d'activité vocale neurale via Silero VAD. Reçoit du PCM16 binaire, retourne `{"type":"vad","score":float,"is_speech":bool}`.

```powershell
.\.venv_stt_tts\Scripts\python.exe src/vad_server.py
# Port par défaut: 8768
```

### `wakeword_server.py` — OpenWakeWord

Serveur WebSocket sur `:8770`. Détection neurale de wake-word via OpenWakeWord. Reçoit du PCM16 binaire, retourne `{"type":"wakeword","word":"...","score":float}`.

```powershell
.\.venv_stt_tts\Scripts\python.exe src/wakeword_server.py
# Port par défaut: 8770
```

### `memory_server.py` — Mémoire FAISS vectorielle

Serveur WebSocket sur `:8771`. Mémoire sémantique vectorielle FAISS + SentenceTransformers (`all-MiniLM-L6-v2`). Opérations : `add` (indexer un souvenir), `search` (recherche vectorielle par similarité).

```powershell
.\.venv_stt_tts\Scripts\python.exe src/memory_server.py
# Port par défaut: 8771
```

### `nlu_server.py` — NLU Classification locale

Serveur WebSocket sur `:8772`. Classification d'intentions locale (11 catégories : météo, heure, timer, domotique, musique, rappel, salutation…) avec extraction d'entités. Regex par défaut, framework transformers optionnel.

```powershell
.\.venv_stt_tts\Scripts\python.exe src/nlu_server.py
# Port par défaut: 8772
```

### `exo_server.py` — Orchestrateur GUI + HA

Le serveur principal Python :
1. Charge les variables `.env`
2. Initialise `HomeBridge` (connexion HA)
3. Bootstrap tous les managers (entités, appareils, pièces)
4. Démarre le serveur WebSocket GUI sur `ws://localhost:8765`
5. Pousse un snapshot initial à chaque client GUI connecté
6. Dispatche les messages GUI : `plan_move`, `settings_update`, `network_scan`
7. Shutdown gracieux sur SIGINT/SIGTERM

---

## 🏠 Backend Python / Home Assistant

### `home_bridge.py` — Pont WebSocket + REST

**EventBus** interne (async emit/on/off) pour distribuer les événements HA.

Connexion WebSocket persistante :
- Auto-reconnect toutes les 5 secondes
- Ping/pong toutes les 30 secondes
- Commandes/réponses avec système de futures (timeout 15 s)
- Événements souscrits : `state_changed`, `device_registry_updated`, `area_registry_updated`, `entity_registry_updated`

REST helpers pour les opérations ponctuelles (GET/POST vers `/api/...`).

Bootstrap en parallèle (`asyncio.gather`) : `get_states`, `devices`, `areas`, `entity_registry`.

### `ha_entities.py` — Gestionnaire d'entités

Cache en mémoire de toutes les entités HA. Requêtes : `get_entity`, `list_by_domain`, `list_by_area`, `search`, `summary`, `all_summaries`. Mise à jour en temps réel sur événements `state_changed`.

### `ha_devices.py` — Gestionnaire d'appareils

Matching par MAC et IP (normalisé). Persistance JSON dans `%APPDATA%\EXOAssistant\ha_devices.json`. Mapping appareil → entités. Fallback sur cache offline.

### `ha_areas.py` — Gestionnaire de pièces

Mappings area ↔ device ↔ entity. Assignation via commandes WS (`device_registry/update`, `entity_registry/update`). Synchronisation Plans → HA (drag-drop met à jour l'area HA). Recherche floue de pièce par nom.

### `ha_actions.py` — Actions LLM Function Calling

13 outils exposés au moteur Claude pour le contrôle domotique :

| Outil | Description |
|-------|-------------|
| `ha_turn_on` | Allumer une entité |
| `ha_turn_off` | Éteindre une entité |
| `ha_toggle` | Basculer une entité |
| `ha_set_brightness` | Luminosité (0–255, clamped) |
| `ha_set_color` | Couleur RGB (clamped 0–255) |
| `ha_set_temperature` | Thermostat °C |
| `ha_play_media` | Lancer un média |
| `ha_pause_media` | Pause média |
| `ha_stop_media` | Stop média |
| `ha_get_state` | État d'une entité (+ fallback REST) |
| `ha_list_devices` | Lister les appareils |
| `ha_list_entities` | Lister les entités |
| `ha_list_areas` | Lister les pièces |

`ActionDispatcher` avec table de dispatch et méthode `execute()` comme point d'entrée unique.

### `ha_sync.py` — Synchronisation complète

- **Plans → HA** : déplacement d'un appareil dans la vue 2D/3D met à jour l'area HA
- **Network → HA** : matching MAC/IP des hôtes réseau contre le registre HA
- **Snapshot** : `build_full_snapshot()` construit l'état complet (entités, appareils, pièces, topologie)
- **Topologie** : nœuds/arêtes vis-network pour la carte réseau
- **Push GUI** : broadcast temps réel sur `state_changed`

---

## ⚛️ GUI React

### Stack technique

- **React 18** + **Vite 5** (HMR, build rapide)
- **TailwindCSS 3** avec palette custom :
  - Fond : `#0E0E11`
  - Accent : `#6C5CE7`
  - Secondaire : `#00CEC9`
- **Konva / react-konva** : Plans 2D (drag-drop appareils)
- **Three.js / @react-three/fiber** : Vue 3D des plans
- **vis-network / vis-data** : Carte réseau interactive
- **Phosphor Icons** : Iconographie

### Écrans

| Écran | Fichier | Description |
|-------|---------|-------------|
| Home | `screens/Home.jsx` | Dashboard principal, état assistant |
| Plans | `screens/Plans.jsx` | Vue 2D (Konva) + 3D (Three.js) des pièces |
| NetworkMap | `screens/NetworkMap.jsx` | Carte réseau vis-network |
| Devices | `screens/Devices.jsx` | Liste et détail des appareils HA |
| Settings | `screens/Settings.jsx` | Thème, voix, VAD, réseau |

### Composants

| Composant | Description |
|-----------|-------------|
| `Avatar.jsx` | Avatar animé (canvas) |
| `Card.jsx` | Carte générique glassmorphism |
| `Icon.jsx` | Wrapper Phosphor Icons |
| `Sidebar.jsx` | Navigation latérale |
| `TopBar.jsx` | Barre supérieure + état connexion |
| `StateIndicator.jsx` | Indicateur d'état coloré |
| `Waveform.jsx` | Visualiseur audio néon (canvas) |

### WebSocket

Le hook `useWebSocket.js` gère la connexion à `ws://localhost:8765` avec :
- Auto-reconnect (backoff exponentiel)
- Callback `onMessage` pour dispatcher les messages
- État de connexion exposé aux composants

### Build & dev

```powershell
cd gui
npm run dev      # Dev server http://localhost:3000 (proxy WS → 8765)
npm run build    # Production dans gui/dist/
npm run preview  # Preview du build
```

---

## 🎨 Interface QML

Interface Material Design Dark intégrée au moteur C++. **L'interface principale est `MainWindow.qml`** (style VS Code).

### Interface VS Code (v4 — active)

`main.cpp` charge `qml/MainWindow.qml` qui organise l'interface en panneaux :

| Composant | Fichier | Rôle |
|-----------|---------|------|
| **MainWindow** | `qml/MainWindow.qml` | Layout principal (sidebar + panels) |
| **Sidebar** | `qml/vscode/Sidebar.qml` | Barre latérale avec icônes navigation |
| **StatusIndicator** | `qml/vscode/StatusIndicator.qml` | État du pipeline (idle/listening/speaking) |
| **MicrophoneLevel** | `qml/vscode/MicrophoneLevel.qml` | Niveau micro temps réel |
| **TranscriptView** | `qml/vscode/TranscriptView.qml` | Transcription STT live |
| **ResponseView** | `qml/vscode/ResponseView.qml` | Réponse Claude |
| **Visualizer** | `qml/vscode/Visualizer.qml` | Visualiseur audio (ShaderEffect GLSL GPU, 60 FPS, fallback Canvas) |
| **BottomBar** | `qml/vscode/BottomBar.qml` | Barre de statut inférieure |
| **SettingsPanel** | `qml/vscode/SettingsPanel.qml` | Panneau configuration (audio, STT, TTS, VAD, DSP, WakeWord, Memory) |
| **HistoryPanel** | `qml/vscode/HistoryPanel.qml` | Historique conversations |
| **LogPanel** | `qml/vscode/LogPanel.qml` | Panneau logs temps réel |

#### Signal audio C++ → QML

```
VoicePipeline::audioLevel(float rms, float vadScore)   // voicepipeline.h
  → MainWindow.onAudioLevel → micLevel
    → BottomBar.audioLevel → Visualizer.audioLevel (ShaderEffect GLSL GPU)
    → Sidebar.micLevel → MicrophoneLevel.level (barre horizontale colorée)
```

> **Note** : Les composants legacy (`qml/components/`) ont été supprimés. L'interface active est exclusivement dans `qml/vscode/`.

---

## ⚙️ Configuration

### Fichiers de configuration

| Fichier | Portée | Description |
|---------|--------|-------------|
| `.env` | Secrets | Clés API et tokens (non versionné) |
| `config/assistant.conf` | Défaut | Paramètres par défaut (lecture seule) |
| `%APPDATA%\EXOAssistant\user_config.ini` | Utilisateur | Préférences (prioritaire) |

### Variables d'environnement (`.env`)

```ini
# Anthropic — obligatoire
CLAUDE_API_KEY=sk-ant-api03-...

# OpenWeatherMap — obligatoire pour la météo
OWM_API_KEY=...

# Home Assistant — optionnel
HA_URL=http://localhost:8123
HA_TOKEN=votre-token-longue-duree
```

### Structure `assistant.conf`

```ini
[Claude]
api_key=${CLAUDE_API_KEY}
model=claude-sonnet-4-20250514
base_url=https://api.anthropic.com/v1/messages
max_tokens=4096
temperature=0.7

[OpenWeatherMap]
api_key=${OWM_API_KEY}
city=Paris
update_interval=600000

[Voice]
wake_word=EXO
language=fr-FR
voice_rate=-0.3
voice_pitch=-0.1
voice_volume=0.9

[STT]
server_url=ws://localhost:8766
backend=whispercpp
model=small
language=fr
beam_size=5

[TTS]
server_url=ws://localhost:8767
backend=xtts
voice=Claribel Dervla
language=fr
pitch=1.0
rate=1.0
style=neutral

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
models=hey_jarvis

[Memory]
semantic_enabled=false
semantic_server_url=ws://localhost:8771

[NLU]
local_enabled=false
server_url=ws://localhost:8772
model=regex

[Audio]
backend=qt
# qt = Qt Multimedia (QAudioSource), rtaudio = RtAudio WASAPI (faible latence)

[Server]
gui_url=ws://localhost:8765

[Logging]
level=Info
debug_enabled=true
console_enabled=true
file_enabled=false
```

### Système de priorité

```
.env (secrets) → assistant.conf (défauts) → user_config.ini (prefs utilisateur)
                                              ↑ Priorité maximale
```

Chaque modification depuis l'interface est immédiatement persistée dans `user_config.ini` via QSettings.

## 🌤️ Météo & Géolocalisation

### OpenWeatherMap

- Données temps réel (température, conditions, humidité, vent)
- Mise à jour automatique toutes les 10 minutes
- Conseils vestimentaires intelligents

### Géolocalisation IP

1. Requête HTTPS vers ip-api.com
2. Récupération : ville, région, pays
3. Mise à jour automatique de la ville météo
4. Sauvegarde persistante dans `user_config.ini`

Activation : Interface → Configuration → "Géolocalisation Automatique" → Détecter ma Position.

---

## 💾 Mémoire persistante

### AIMemoryManager v4 — 3 couches

| Couche | Capacité | Description |
|--------|----------|-------------|
| **Conversations** | 100 échanges | Buffer circulaire, 5 dernières utilisées comme contexte Claude |
| **Préférences** | Illimité | Auto-détection par 25+ patterns regex dans les réponses |
| **Souvenirs sémantiques** | Illimité | Faits extraits des conversations, avec décroissance d'importance |

### Stockage

- **Chemin** : `%APPDATA%\EXOAssistant\exa_memory.json`
- **Format** : JSON v2 (écritures atomiques : write tmp → rename)
- **Auto-analyse** : les réponses de Claude sont automatiquement scannées pour extraire préférences et souvenirs

### API C++ (Q_INVOKABLE)

```cpp
void addConversation(QString userMessage, QString assistantResponse);
QString getConversationContext(int maxEntries = 5);
void updateUserPreference(QString key, QVariant value);
QVariant getUserPreference(QString key);
void clearAllMemory();
void clearConversationHistory();
```

---

## 🤖 Claude API & Function Calling

### Configuration

| Paramètre | Valeur par défaut |
|-----------|-------------------|
| Modèle | `claude-sonnet-4-20250514` |
| Max tokens | 4096 |
| Température | 0.7 |
| Timeout | 30s |
| Rate limit | 50 req/min |
| Retries | 3 (backoff exponentiel) |

### Streaming SSE

L'API utilise le streaming Server-Sent Events pour des réponses en temps réel :
- Les chunks texte sont accumulés et émis via `partialResponse()`
- Les appels d'outils sont détectés dans les content blocks
- Signal `toolCallDetected(toolName, toolInput)` pour dispatch

### Function Calling — 8 outils EXO

| Outil | Description |
|-------|-------------|
| `get_weather` | Météo actuelle et prévisions |
| `ha_turn_on` | Allumer un appareil HA |
| `ha_turn_off` | Éteindre un appareil HA |
| `ha_toggle` | Basculer un appareil HA |
| `ha_set_brightness` | Régler luminosité (0–255) |
| `ha_set_color` | Couleur RGB |
| `ha_get_state` | État d'une entité HA |
| `ha_list_entities` | Lister les entités HA |

### Workflow

1. Wake word "EXO" détecté dans transcript STT
2. Contexte construit (5 dernières conversations + préférences + mémoire sémantique)
3. Requête SSE streaming à `https://api.anthropic.com/v1/messages`
4. Si Function Call détecté → dispatch vers Home Assistant via WebSocket
5. Résultat renvoyé à Claude via `sendToolResult()`
6. Réponse finale → TTS + affichage interface + sauvegarde mémoire

---

## 🏠 Home Assistant — Détail technique

### Connexion

| Protocole | URL | Usage |
|-----------|-----|-------|
| WebSocket | `ws://HA_URL/api/websocket` | Événements temps réel, commandes |
| REST | `http://HA_URL/api/...` | Opérations ponctuelles |

Authentification par token longue durée (`HA_TOKEN` dans `.env`).

### Événements souscrits

| Événement | Effet |
|-----------|-------|
| `state_changed` | MAJ cache entité + push GUI |
| `device_registry_updated` | Refresh registre appareils |
| `area_registry_updated` | Rebuild mappings pièces |
| `entity_registry_updated` | Refresh registre entités |

### Flux de données

```
HA event → HomeBridge.EventBus → managers (entities/devices/areas)
                                       ↓
                               SyncManager → GUI broadcast (ws://8765)
```

### Persistance locale

- `%APPDATA%\EXOAssistant\ha_devices.json` — cache appareils (fallback offline)

---

## 📋 Logging

### LogManager (v4)

Système de logging par catégories avec macros dédiées :

| Macro | Catégorie | Usage |
|-------|-----------|-------|
| `hLog()` | DEFAULT | Messages généraux |
| `hConfig()` | CONFIG | Configuration et .env |
| `hClaude()` | CLAUDE | API Anthropic |
| `hVoice()` | VOICE | Pipeline audio, TTS, STT, VAD |
| `hWeather()` | WEATHER | Météo et géolocalisation |
| `hAssistant()` | ASSISTANT | Orchestrateur et mémoire |
| `hDebug(cat)` | — | Debug avec catégorie custom |
| `hWarning(cat)` | — | Warning avec catégorie custom |
| `hCritical(cat)` | — | Critical avec catégorie custom |

### Fichier log

- **Chemin** : `%APPDATA%\EXOAssistant\EXO Assistant\henri.log`
- **Activation** : `[Logging] file_enabled=true` dans `assistant.conf`
- **Format** : `[YYYY-MM-DD HH:MM:SS.mmm] LEVEL [CATEGORY] message`

---

## 🧪 Tests

### Tests Python (92)

```powershell
python -m pytest src/integrations/tests/ -v
```

| Fichier | Tests | Couverture |
|---------|-------|------------|
| `test_home_bridge.py` | EventBus, init, ws_command, dispatch | Connexion WS |
| `test_entities.py` | Bootstrap, requêtes, live update, summary | Cache entités |
| `test_devices.py` | Bootstrap, MAC/IP matching, search, mapping | Appareils |
| `test_areas.py` | Bootstrap, assignation, plan sync, summary | Pièces |
| `test_actions.py` | 13 tools validation, turn/brightness/color/media | Actions LLM |
| `test_sync.py` | Plan sync, network matching, snapshot, topology | Synchronisation |

Configuration pytest dans `pyproject.toml` : `asyncio_mode = "auto"`.

### Scripts PowerShell

| Script | Description |
|--------|-------------|
| `scripts/test_environment.ps1` | Vérification complète de l'environnement |
| `scripts/verify_project.ps1` | Validation de la structure du projet |
| `scripts/check_dependencies.ps1` | Vérification des dépendances |
| `scripts/quick_build.ps1` | Compilation rapide |
| `scripts/install_dependencies.ps1` | Installation automatique |
| `scripts/cleanup.ps1` | Nettoyage des artefacts |

---

## 🐛 Dépannage

### L'application ne se lance pas (STATUS_DLL_NOT_FOUND)

Le moteur C++ nécessite les DLL Qt. Exécuter une seule fois :
```powershell
C:\Qt\6.9.3\msvc2022_64\bin\windeployqt.exe build\Debug\RaspberryAssistant.exe --qmldir qml
```

### TTS ne fonctionne pas (pas de son)

1. Vérifier que `tts_server.py` tourne sur le port 8767 :
   ```powershell
   Get-NetTCPConnection -LocalPort 8767 -ErrorAction SilentlyContinue
   ```
2. Vérifier les logs : `henri.log` doit montrer `tryPythonTTS: connected = true`
3. Si XTTS échoue, le fallback Qt TTS (Microsoft Julie) prend le relais
4. Vérifier la sortie audio par défaut Windows

### STT ne transcrit pas

1. Vérifier que `stt_server.py` tourne sur le port 8766
2. Le modèle Whisper GGML (ex: ggml-small.bin) doit être dans `whisper.cpp/models/`
3. Vérifier les logs : `StreamingSTT: connecté au serveur STT`
4. Vérifier que le micro est actif et sélectionné comme périphérique par défaut

### EXO ne m'entend pas

- Le wake word est **"EXO"** (détection logicielle dans le transcript STT)
- Vérifier les logs : `VAD: parole détectée` → `STT final: "..."`
- Si le transcript est vide mais la parole détectée, vérifier le micro et le modèle STT

### Erreur `AUDCLNT_E_NOT_STOPPED`

Conflit WASAPI mineur lors de la reprise du micro après TTS. Non bloquant — le pipeline se réinitialise automatiquement.

### Configuration non trouvée

Le moteur cherche `config/assistant.conf` en relatif depuis le répertoire du projet. Lancer depuis la racine du projet ou utiliser `launch_exo.ps1`.

### Géolocalisation échoue

- Pas de connexion Internet
- Service ip-api.com indisponible
- Firewall bloquant les requêtes HTTPS

### Backend Python ne se connecte pas à HA

- Vérifier `HA_URL` et `HA_TOKEN` dans `.env`
- Vérifier que Home Assistant est accessible depuis la machine

---

## 📝 Changelog

### v4.2 — Mars 2026 — "Premium Open-Source Edition"
- ✅ **RtAudio WASAPI** — capture audio faible latence via abstraction AudioInput (src/audio/), backend sélectionnable Qt/RtAudio
- ✅ **XTTS v2** — TTS premium neural multilingue, streaming PCM16, contrôle pitch/rate/style
- ✅ **Silero VAD** — VAD neural via WebSocket (vad_server.py :8768), modes builtin/silero/hybrid
- ✅ **DSP noisereduce** — réduction de bruit spectrale intégrée à stt_server.py, intensité configurable
- ✅ **OpenWakeWord** — détection neurale wake-word (wakeword_server.py :8770), complément transcript
- ✅ **STT CPU fallback** — whispercpp_cpu backend GGUF int8
- ✅ **FAISS + SentenceTransformers** — mémoire sémantique vectorielle (memory_server.py :8771), bridge C++ WebSocket
- ✅ **NLU local** — classification d'intention regex + framework transformers (nlu_server.py :8772)
- ✅ **Visualizer GPU** — ShaderEffect GLSL (remplace Canvas CPU), 60 FPS, fallback Canvas
- ✅ **SettingsPanel premium** — audio backend, VAD backend, noise reduction, wakeword neural, semantic memory, chat input
- ✅ **Configuration étendue** — sections [VAD], [DSP], [WakeWord], [Memory], [NLU], [Audio]
- ✅ **7 serveurs Python** — STT :8766, TTS :8767, VAD :8768, WakeWord :8770, Memory :8771, NLU :8772, GUI :8765
- ✅ **Nettoyage legacy** — suppression composants QML v3, fichiers obsolètes, unification documentation

### v4.1 — Mars 2026
- ✅ **Backend STT Whisper.cpp + Vulkan GPU** — RTF 0.08–0.23 sur AMD RX 6750 XT (vs RTF 1.4 CPU)
- ✅ **Dual backend STT** — whisper.cpp (Vulkan GPU, défaut) / faster-whisper (CPU, fallback)
- ✅ **whisper_cpp.py** — wrapper Python communiquant avec whisper-server.exe via HTTP, auto-restart
- ✅ **stt_server.py refactorisé** — classe STTEngine dual-backend, filtre anti-hallucination
- ✅ **Ajustements VoicePipeline** — SPEECH_HANG_FRAMES=30 (~600ms), min utterance 2s
- ✅ **Configuration** — backend=whispercpp, beam_size=5, modèle small
- ✅ **Chat manuel** — TextField dans TranscriptView + `sendManualQuery()` → Claude
- ✅ **Visualizer amélioré** — hauteur augmentée (72px), traits plus épais (1.5px)
- ✅ **Multi-wakeword + phonétique** — Levenshtein ≤ 1, variantes "egzo", "ekso", "exho"...
- ✅ **Multi-langue** — ComboBox STT (fr, en, es, de, it, pt, ja, zh)
- ✅ **Météo** — bouton détection automatique de la ville
- ✅ **Réglages microphone** — sliders VAD threshold, noise gate, toggle AGC
- ✅ **TTS voice selection** — ComboBox XTTS v2 voices (58 speakers, 17 langues)
- ✅ **TTS DSP amélioré** — compressor -12dB, normalizer -16dBFS, fades 8/15ms

### v4.0 — Mars 2026
- ✅ **Interface VS Code** — 10 composants QML (Sidebar, StatusIndicator, MicrophoneLevel, TranscriptView, ResponseView, Visualizer, BottomBar, SettingsPanel, HistoryPanel, MainWindow)
- ✅ **VoicePipeline v4** — FSM 5 états, VADEngine, AudioPreprocessor, StreamingSTT WebSocket
- ✅ **TTSManager v4** — Cascade XTTS v2/Qt TTS, DSP 5 étapes (EQ, Compressor, Normalizer, Fade, Anti-clip), buffer PCM + pompe timer
- ✅ **Serveurs Python STT/TTS** — stt_server.py (Whisper.cpp Vulkan GPU + fallback CPU, port 8766), tts_server.py (XTTS v2 58 voix, port 8767)
- ✅ **ConfigManager v4** — priorité 3 couches (CLI > conf > défaut)
- ✅ **ClaudeAPI v4** — SSE streaming + 8 outils Function Calling
- ✅ **AIMemoryManager v4** — mémoire 3 couches (court/long/sémantique)
- ✅ **LogManager** — catégories VOICE/TTS/STT/CONFIG/CLAUDE/MEMORY, fichier rotatif
- ✅ **Correction TTS** — 3 bugs critiques (buffer overflow, arrêt prématuré, race condition URL)

### v3.0 — Juillet 2025
- ✅ **GUI React complète** — 5 écrans (Home, Plans, NetworkMap, Devices, Settings)
- ✅ **Backend Python Home Assistant** — 6 modules + serveur WebSocket
- ✅ **13 actions LLM Function Calling** — contrôle domotique par la voix
- ✅ **92 tests unitaires Python** — couverture complète HA
- ✅ **Audit sécurité** — 12 correctifs (API keys, HTTPS, atomic writes, double-delete, QElapsedTimer)
- ✅ **Fix audio** — buffer clearing + calibration seuils
- ✅ **Renommage Henri → EXO** — toute la codebase

### v2.1 — Octobre 2025
- ✅ Géolocalisation automatique IP
- ✅ Persistance météo corrigée (Settings hybrides)
- ✅ Architecture unifiée (60% réduction doublons)
- ✅ Interface améliorée (section géolocalisation)
- ✅ Code optimisé (debug conditionnel)

### v2.0
- ✅ Interface radiale Material Design
- ✅ Intégration Claude API complète
- ✅ Système de mémoire persistante
- ✅ Reconnaissance vocale Porcupine + TTS
- ✅ Météo temps réel OpenWeatherMap
- ✅ Configuration modulaire

---

## 🔮 Roadmap

- [x] **Whisper STT** — reconnaissance vocale Whisper.cpp (Vulkan GPU) + fallback faster-whisper (CPU)
- [x] **XTTS v2 TTS** — synthèse vocale neurale XTTS v2 avec DSP
- [x] **Silero VAD** — VAD neural (builtin/silero/hybrid)
- [x] **OpenWakeWord** — détection neurale wake-word
- [x] **FAISS Mémoire** — mémoire sémantique vectorielle
- [x] **NLU local** — classification d'intention locale
- [x] **Visualizer GPU** — rendu shader OpenGL/Vulkan
- [x] **RtAudio** — capture WASAPI faible latence avec abstraction AudioInput
- [ ] **Google Calendar** — agenda intelligent + rappels
- [ ] **Streaming musical** — Spotify / Tidal
- [ ] **Déploiement Raspberry Pi 5** — version ARM optimisée
- [ ] **Interface mobile** — companion app
- [x] **Multi-langues** — support international (fr, en, es, de, it, pt, ja, zh)
- [ ] **Auto-update** — mise à jour automatique
- [ ] **Docker** — déploiement containerisé

---

## Contact

- **Développeur** : Alexandre VDF
- **Repository** : [github.com/AlexanderVDF/EXO](https://github.com/AlexanderVDF/EXO)

---

**EXO Assistant v4.2** — C++ / Qt 6.9.3 · Python · XTTS v2 · Whisper.cpp (Vulkan GPU) · FAISS · Silero · OpenWakeWord