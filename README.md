# 🤖 EXO — Assistant Vocal Local Premium

**Version 25.1** | Avril 2026 | **Source de vérité : [`PROMPT_MAITRE.md`](PROMPT_MAITRE.md)**

![Qt 6.9.3](https://img.shields.io/badge/Qt-6.9.3-green?logo=qt)
![C++17](https://img.shields.io/badge/C++-17-blue?logo=cplusplus)
![Python 3.13](https://img.shields.io/badge/Python-3.13-yellow?logo=python)
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

EXO est un assistant vocal intelligent 100% local (sauf LLM Claude API), conçu pour tourner en temps réel sur un PC desktop ou un Raspberry Pi. Il combine un moteur C++/Qt haute performance avec 7 microservices Python spécialisés, communiquant par WebSocket.

**Pourquoi EXO ?**
- 🎙 **Voix naturelle** — XTTS v2 (58 voix, multilingue) + Whisper.cpp (Vulkan GPU, RTF 0.08–0.23)
- 🧠 **Mémoire persistante** — 3 couches (court/long/sémantique) + FAISS vectoriel
- 🏠 **Domotique** — Intégration Home Assistant (13 actions LLM)
- 🎨 **Interface premium** — QML style VS Code + Fluent Design + React web
- ⚡ **Ultra-Low Latency (v8.1)** — ContextCache, LatencyMetrics, warmup/keepalive ClaudeAPI
- 🛡️ **Observability & Résilience (v9.0)** — LogManager, MetricsManager, TraceManager, ErrorManager, ConfigManager, SecurityManager, CircuitBreaker, BaseService

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EXO Assistant v9.0                          │
├──────────────┬──────────────────────────────────────────────────────┤
│              │                                                      │
│  Interface   │   ┌─────────────┐    ┌──────────────────────────┐   │
│  QML / React │   │ Audio Input │───→│ VoicePipeline (C++ FSM) │   │
│              │   │  (RtAudio   │    │  DSP → VAD → WakeWord   │   │
│              │   │   WASAPI)   │    │       → STT stream      │   │
│              │   └─────────────┘    └──────────┬───────────────┘   │
│              │                                  │                   │
│              │                    ┌─────────────▼──────────────┐   │
│              │                    │     ClaudeAPI (SSE)        │   │
│              │                    │  8 Function Calling + NLU  │   │
│              │                    └─────────────┬──────────────┘   │
│              │                                  │                   │
│              │                    ┌─────────────▼──────────────┐   │
│              │                    │  TTSManager (C++ DSP)      │   │
│              │                    │  EQ → Compressor → Norm    │   │
│              │                    │  → Fade → Anti-clip → Out  │   │
│              │                    └────────────────────────────┘   │
├──────────────┴──────────────────────────────────────────────────────┤
│                    7 Microservices Python (WebSocket)               │
│  ┌──────┐ ┌──────┐ ┌─────┐ ┌────────┐ ┌───────┐ ┌─────┐ ┌─────┐ │
│  │ Orch │ │ STT  │ │ TTS │ │  VAD   │ │ Wake  │ │ Mem │ │ NLU │ │
│  │ 8765 │ │ 8766 │ │ 8767│ │  8768  │ │ 8770  │ │ 8771│ │ 8772│ │
│  └──────┘ └──────┘ └─────┘ └────────┘ └───────┘ └─────┘ └─────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Les 7 microservices

| Service | Port | Technologie | Rôle |
|---------|------|-------------|------|
| **Orchestrator** | 8765 | Python 3.13 | GUI WebSocket + bridge Home Assistant |
| **STT** | 8766 | Whisper.cpp (Vulkan) | Reconnaissance vocale GPU, modèle medium |
| **TTS** | 8767 | XTTS v2 (CUDA) | Synthèse vocale neurale, 24 kHz PCM16 |
| **VAD** | 8768 | Silero VAD | Détection d'activité vocale neurale |
| **WakeWord** | 8770 | OpenWakeWord | Détection du mot-clé "EXO" |
| **Memory** | 8771 | FAISS + SentenceTransformers | Mémoire sémantique vectorielle |
| **NLU** | 8772 | Transformers | Classification d'intention locale |

### Moteur C++ / Qt

| Module | Fichier | Rôle |
|--------|---------|------|
| AssistantManager | `app/core/` | Orchestrateur global, FSM |
| VoicePipeline | `app/audio/` | Pipeline audio : capture → DSP → VAD → STT |
| TTSManager | `app/audio/` | Lecture TTS, chaîne DSP (EQ, compressor, normalizer, fade) |
| ClaudeAPI | `app/llm/` | LLM SSE streaming + 8 Function Calling |
| AIMemoryManager | `app/llm/` | Mémoire 3 couches + FAISS |
| WeatherManager | `app/utils/` | Météo OpenWeatherMap + géolocalisation |
| ConfigManager | `app/core/` | Configuration 2 couches (env > global) |

### Interface

- **QML** — 18 composants style VS Code + Fluent Design (Sidebar, Transcript, Response, Visualizer GPU ShaderEffect GLSL 60 FPS, Settings, History, etc.)

---

## Framework Cognitif (`exo/`)

Package Python standalone implémentant l'architecture cognitive complète v1→v25 : modulaire, testable, déterministe, explicable, gouverné.

```
                    ┌───────────────────────────────────────┐
                    │           Agents Macro (5)            │
                    │  Cognition · Simulation · Planning    │
                    │     Observability · Governance        │
                    └───────────────┬───────────────────────┘
                                    │ orchestrent
                    ┌───────────────▼───────────────────────┐
                    │          Pipelines (3)                 │
                    │  Cognitive (8 couches chaînées)        │
                    │  Simulation (scénarios → arbitrage)    │
                    │  Planning (HTN → contraintes → optim)  │
                    └───────────────┬───────────────────────┘
                                    │ composés de
          ┌─────────────────────────▼──────────────────────────┐
          │                   Layers (8)                        │
          │  Perception → Extraction → Symbolic → Inference    │
          │  → Planning → Simulation → Decision → Supervision  │
          └─────────────────────────┬──────────────────────────┘
                                    │ utilisent
          ┌─────────────────────────▼──────────────────────────┐
          │                  Engines (8)                        │
          │  Rule · Causal · Inference · HTN · Simulation      │
          │  Optimization · Observability · Governance         │
          └─────────────────────────┬──────────────────────────┘
                                    │ s'appuient sur
          ┌─────────────────────────▼──────────────────────────┐
          │                   Core (4)                          │
          │  CognitiveKernel · CognitiveContext                │
          │  CognitiveState · CognitiveFlow                    │
          └────────────────────────────────────────────────────┘

  Transversal :  Governance (permissions, validation, compliance, audit)
                 Observability (telemetry, tracing, metrics, dashboard)
                 Agents Micro (8 tâches spécialisées)
```

| Composant | Fichiers | Rôle |
|-----------|----------|------|
| Core | 4 | Classes abstraites, data classes, graphe de connaissance |
| Engines | 8 | Moteurs cognitifs concrets (règles, causal, inférence, HTN, simulation…) |
| Layers | 8 | Couches de traitement chaînables (perception → supervision) |
| Pipelines | 3 | Orchestration de couches et moteurs |
| Agents macro | 5 | Orchestrateurs haut niveau (cognition, simulation, planning, obs, gov) |
| Agents micro | 8 | Tâches spécialisées (extraction, vérification, analyse…) |
| Governance | 4 | Permissions, validation 5 niveaux, compliance 4 domaines, audit |
| Observability | 4 | Télémétrie, tracing, métriques, dashboard |
| Tests | 5 | 117 tests couvrant tous les modules |

---

## Fonctionnalités

| Fonctionnalité | Détail |
|----------------|--------|
| 🎙 Reconnaissance vocale | Whisper.cpp Vulkan GPU — RTF 0.08–0.23 |
| 🗣 Synthèse vocale | XTTS v2 — 58 voix, multilingue, streaming PCM16 |
| 🧠 LLM | Claude API SSE + 8 Function Calling |
| ⚡ Ultra-Low Latency | ContextCache (TTL), LatencyMetrics (9 timestamps), warmup/keepalive |
| 💾 Mémoire | 3 couches (court/long/sémantique) + FAISS vectoriel |
| 🔊 VAD | Silero neural + mode hybride (builtin/silero/hybrid) |
| 👂 Wake word | OpenWakeWord neural + détection transcript |
| 🎛 DSP | Réduction de bruit spectrale + chaîne audio complète |
| 🏠 Domotique | Home Assistant — 13 actions LLM (lumières, médias, clima) |
| 🌤 Météo | OpenWeatherMap + géolocalisation |
| 🧪 Tests | 2335 tests automatisés (pytest) |

---

## Prérequis

| Composant | Version | Usage |
|-----------|---------|-------|
| Windows 11 | — | Plateforme principale |
| Qt | 6.9.3 MSVC 2022 x64 | Moteur C++ / QML |
| CMake | 3.21+ | Build system |
| Visual Studio Build Tools | 2022 | Compilateur MSVC |
| Python | 3.11+ | Microservices IA (venv `.venv_stt_tts`) |
| Python | 3.13+ | Orchestrator (venv `.venv`) |
| GPU | Vulkan compatible | STT (Whisper.cpp) + TTS (CUDA) |

> **Modèles & données** — Stockés sur `D:\EXO\` (modèles Whisper, XTTS, FAISS, wakeword, cache HuggingFace).

---

## Installation

### 1. C++ — Compilation

```powershell
# Configurer
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="C:\Qt\6.9.3\msvc2022_64"

# Compiler (windeployqt s'exécute automatiquement en POST_BUILD)
cmake --build build --config Release
```

### 2. Python — Venv microservices IA

```powershell
python -m venv .venv_stt_tts
.\.venv_stt_tts\Scripts\Activate.ps1
pip install websockets numpy soundfile "transformers>=4.40,<4.50"
pip install "torch==2.4.1" "torchaudio==2.4.1" --index-url https://download.pytorch.org/whl/cu121
pip install TTS
pip install silero-vad onnxruntime noisereduce openwakeword faiss-cpu sentence-transformers
```

### 3. Python — Venv orchestrator

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 4. Variables d'environnement (`.env`)

```ini
CLAUDE_API_KEY=sk-ant-api03-...
OWM_API_KEY=...
HA_URL=http://localhost:8123
HA_TOKEN=votre-token-longue-duree
```

---

## Lancement

### Tout-en-un (recommandé)

```powershell
.\launch_exo.ps1
```

Ou via VS Code : `Ctrl+Shift+P` → `Tasks: Run Task` → `launch_all` (démarre les 7 services + GUI en parallèle).

### Lancement manuel

```powershell
# Terminal 1 — Orchestrator (port 8765)
.\.venv\Scripts\python.exe python/orchestrator/exo_server.py

# Terminal 2 — STT Whisper.cpp (port 8766)
.\.venv_stt_tts\Scripts\python.exe python/stt/stt_server.py --backend whispercpp --model medium --device gpu

# Terminal 3 — TTS XTTS v2 (port 8767)
.\.venv_stt_tts\Scripts\python.exe python/tts/tts_server.py --voice "Claribel Dervla" --lang fr

# Terminal 4 — VAD Silero (port 8768)
.\.venv_stt_tts\Scripts\python.exe python/vad/vad_server.py

# Terminal 5 — WakeWord (port 8770)
.\.venv_stt_tts\Scripts\python.exe python/wakeword/wakeword_server.py

# Terminal 6 — Mémoire FAISS (port 8771)
.\.venv_stt_tts\Scripts\python.exe python/memory/memory_server.py

# Terminal 7 — NLU (port 8772)
.\.venv_stt_tts\Scripts\python.exe python/nlu/nlu_server.py

# GUI C++
build\Release\RaspberryAssistant.exe
```

---

## Utilisation

1. Dites **"EXO"** → l'assistant passe en mode écoute
2. Posez votre question → transcription Whisper → traitement Claude API
3. Réponse vocale XTTS v2 + affichage dans l'interface QML

### Domotique (Home Assistant)

EXO contrôle vos appareils via le langage naturel :
- Allumer / éteindre / basculer des entités
- Régler luminosité, couleur, température
- Contrôler les médias (play, pause, stop, volume)

---

## Configuration

Fichier `config/assistant.conf` — format INI, 3 niveaux de priorité : **Variables d'environnement > `assistant_local.conf` > `assistant.conf`**

```ini
[Claude]
api_key=${CLAUDE_API_KEY}
model=claude-sonnet-4-20250514

[STT]
server_url=ws://localhost:8766
backend=whispercpp
model=medium

[TTS]
server_url=ws://localhost:8767
backend=xtts
voice=Claribel Dervla
language=fr

[Voice]
wake_word=EXO
language=fr-FR

[VAD]
backend=silero
server_url=ws://localhost:8768
threshold=0.45

[WakeWord]
neural_enabled=true
server_url=ws://localhost:8770

[Memory]
semantic_enabled=true
semantic_server_url=ws://localhost:8771

[NLU]
local_enabled=true
server_url=ws://localhost:8772
```

---

## Arborescence du projet

```
EXO/
├── app/                          C++ — moteur principal
│   ├── main.cpp                   Point d'entrée Qt
│   ├── core/                      Orchestrateur, Config, Logs, Pipeline, HealthCheck
│   ├── audio/                     VoicePipeline, TTSManager, DSP, AudioInput
│   ├── llm/                       ClaudeAPI, AIMemoryManager
│   └── utils/                     WeatherManager
│
├── exo/                          Framework cognitif standalone (v25.1)
│   ├── core/                      CognitiveKernel, Context, State, Flow
│   ├── engines/                   8 moteurs (Rule, Causal, Inference, HTN,
│   │                              Simulation, Optimization, Observability, Governance)
│   ├── layers/                    8 couches (Perception → Supervision)
│   ├── pipelines/                 3 pipelines (Cognitive, Simulation, Planning)
│   ├── agents/
│   │   ├── macro/                 5 agents (Cognition, Simulation, Planning,
│   │   │                          Observability, Governance)
│   │   └── micro/                 8 agents (EntityExtraction, RuleVerification,
│   │                              CausalAnalysis, HTNExpansion, LocalSimulation,
│   │                              RiskAnalysis, LogicValidation, MetricsCollection)
│   ├── governance/                Permissions, Validation, Compliance, Audit
│   ├── observability/             Telemetry, Tracing, Metrics, Dashboard
│   ├── tests/                     117 tests (engines, pipelines, agents, gov, obs)
│   └── main.py                    Démo entry point
│
├── python/                       Microservices Python
│   ├── orchestrator/              exo_server.py + Home Assistant (8765)
│   ├── stt/                       stt_server.py + whisper_cpp.py (8766)
│   ├── tts/                       tts_server.py (8767)
│   ├── vad/                       vad_server.py (8768)
│   ├── wakeword/                  wakeword_server.py (8770)
│   ├── memory/                    memory_server.py (8771)
│   ├── nlu/                       nlu_server.py (8772)
│   └── shared/                    Modules partagés
│
├── qml/                          Interface QML (19 composants VS Code)
├── docs/                         Documentation
├── config/                       Configuration (assistant.conf)
├── rtaudio/                      RtAudio WASAPI (sous-module statique)
├── resources/                    Polices, icônes
├── scripts/                      Utilitaires PowerShell
├── tests/                        Tests (2218 pytest Python)
├── whisper.cpp/                  Whisper.cpp (sous-module)
├── .env                          Clés API (non versionné)
├── requirements.txt              Dépendances Python orchestrator
└── CMakeLists.txt                Build CMake
```

---

## 📖 Documentation

La documentation est dans [`docs/`](docs/) :

| Fichier / Dossier | Contenu |
|-------------------|--------|
| `architecture/` | Schémas d'architecture |
| `audits/` | Rapports d'audit |
| `modules.md` | Index des modules |
| `pipeline.md` | Pipeline vocal |
| `services.md` | Microservices Python |
| `CHANGELOG.md` | Historique des versions |
| `PLAN_IMPLEMENTATION.md` | Plan d'implémentation |

---

## Roadmap

### ✅ Réalisé (v25.1)
- RtAudio WASAPI — capture audio faible latence
- Interface QML 19 composants VS Code + Fluent Design
- Pipeline vocal VoicePipeline v4 (FSM, VAD, StreamingSTT)
- XTTS v2 — TTS neural multilingue, 58 voix, streaming PCM16
- STT Whisper.cpp + Vulkan GPU (RTF 0.08–0.23)
- Claude API SSE streaming + 8 Function Calling
- Mémoire 3 couches + FAISS vectoriel
- Silero VAD + OpenWakeWord neural
- DSP noisereduce spectral + chaîne audio complète
- NLU local (classification d'intention)
- Visualizer GPU ShaderEffect GLSL 60 FPS
- Intégration Home Assistant (13 actions LLM)
- **ContextCache** — cache in-process avec TTL par clé + refresh arrière-plan
- **LatencyMetrics** — instrumentation pipeline 9 timestamps, 6 métriques dérivées
- **ClaudeAPI warmup/keepalive** — connexion TCP/TLS pré-établie, latence 1er token réduite
- Observabilité complète (logging structuré, métriques, tracing distribué)
- Résilience (retry, timeout, fallback, circuit breaker)
- Sécurité (permissions, audit log)
- Config centralisée avec hot-reload
- **Framework cognitif standalone** (`exo/`) — 8 moteurs, 8 couches, 3 pipelines, 13 agents, gouvernance, observabilité
- **2335 tests automatisés** (2218 tests existants + 117 tests framework cognitif)

### 🔄 À venir
- Google Calendar — agenda intelligent
- Streaming musical — Spotify / Tidal
- Déploiement Raspberry Pi 5
- Interface mobile companion
- Docker — déploiement containerisé

---

## Contribuer

1. Fork le repo
2. Créer une branche (`git checkout -b feature/ma-fonctionnalite`)
3. Lire `PROMPT_MAITRE.md` pour les conventions
4. Lancer les tests : `ctest --test-dir build` + `pytest tests/python/`
5. Commit (`git commit -m "feat: description"`)
6. Push + Pull Request

### Conventions
- **C++** : C++17, Qt 6.9.3, nommage Qt (`camelCase`, `m_` pour membres)
- **Python** : PEP 8, asyncio, websockets
- **QML** : Design system EXO (voir [`docs/ui/design_system.md`](docs/ui/design_system.md))
- **Commits** : format conventionnel (`feat:`, `fix:`, `docs:`, `refactor:`)

---

## Licence

Ce projet est sous licence **MIT**. Voir [LICENSE](LICENSE) pour les détails.

---

**EXO** — C++ / Qt 6.9.3 · Python 3.13 · XTTS v2 · Whisper.cpp (Vulkan GPU) · FAISS · Silero · OpenWakeWord · Framework Cognitif v25.1