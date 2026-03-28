> 🧭 [Index](../README.md) → [Architecture](../README.md#-architecture--spécifications--core) → EXO_DOCUMENTATION.md
# EXO Assistant — Documentation Technique Complète
> Documentation EXO v4.2 — Section : Architecture
> Dernière mise à jour : Mars 2026

<!-- TOC -->
## Table des matières

- [Présentation](#présentation)
- [Installation](#installation)
  - [Prérequis](#prérequis)
  - [Étape 1 — Cloner & configurer](#étape-1-cloner-configurer)
  - [Étape 2 — Compiler le moteur C++](#étape-2-compiler-le-moteur-c)
  - [Étape 3 — Installer l'environnement Python STT/TTS](#étape-3-installer-lenvironnement-python-stttts)
  - [Étape 4 — Installer le backend Python](#étape-4-installer-le-backend-python)
  - [Étape 5 — Installer la GUI React](#étape-5-installer-la-gui-react)
  - [Lancement](#lancement)
  - [Chemins de données (SSD D:\EXO\)](#chemins-de-données-ssd-dexo)
- [Architecture générale](#architecture-générale)
  - [Ports réseau (résumé)](#ports-réseau-résumé)
- [Moteur C++ / Qt](#moteur-c-qt)
  - [Modules Qt utilisés](#modules-qt-utilisés)
  - [AssistantManager (v4)](#assistantmanager-v4)
  - [ConfigManager (v4)](#configmanager-v4)
  - [ClaudeAPI (v4)](#claudeapi-v4)
  - [WeatherManager](#weathermanager)
  - [AudioInput — Abstraction audio (v4.2)](#audioinput-abstraction-audio-v42)
  - [AIMemoryManager (v4)](#aimemorymanager-v4)
- [Pipeline vocal](#pipeline-vocal)
- [Synthèse vocale (TTS)](#synthèse-vocale-tts)
- [Reconnaissance vocale (STT)](#reconnaissance-vocale-stt)
- [Serveurs Python](#serveurs-python)
- [Backend Python / Home Assistant](#backend-python-home-assistant)
  - [`home_bridge.py` — Pont WebSocket + REST](#home_bridgepy-pont-websocket-rest)
  - [`ha_entities.py` — Gestionnaire d'entités](#ha_entitiespy-gestionnaire-dentités)
  - [`ha_devices.py` — Gestionnaire d'appareils](#ha_devicespy-gestionnaire-dappareils)
  - [`ha_areas.py` — Gestionnaire de pièces](#ha_areaspy-gestionnaire-de-pièces)
  - [`ha_actions.py` — Actions LLM Function Calling](#ha_actionspy-actions-llm-function-calling)
  - [`ha_sync.py` — Synchronisation complète](#ha_syncpy-synchronisation-complète)
- [GUI React](#gui-react)
  - [Stack technique](#stack-technique)
  - [Écrans](#écrans)
  - [Composants](#composants)
  - [WebSocket](#websocket)
  - [Build & dev](#build-dev)
- [Interface QML](#interface-qml)
  - [Interface VS Code (v4 — active)](#interface-vs-code-v4-active)
  - [Signal audio C++ → QML](#signal-audio-c-qml)
- [Configuration](#configuration)
  - [Fichiers de configuration](#fichiers-de-configuration)
  - [Variables d'environnement (`.env`)](#variables-denvironnement-env)
  - [Structure `assistant.conf`](#structure-assistantconf)
  - [Système de priorité](#système-de-priorité)
- [Météo & Géolocalisation](#météo-géolocalisation)
  - [OpenWeatherMap](#openweathermap)
  - [Géolocalisation IP](#géolocalisation-ip)
- [Mémoire persistante](#mémoire-persistante)
  - [AIMemoryManager v4 — 3 couches](#aimemorymanager-v4-3-couches)
  - [Stockage](#stockage)
  - [API C++ (Q_INVOKABLE)](#api-c-q_invokable)
- [Claude API & Function Calling](#claude-api-function-calling)
  - [Configuration](#configuration)
  - [Streaming SSE](#streaming-sse)
  - [Function Calling — 8 outils EXO](#function-calling-8-outils-exo)
  - [Workflow](#workflow)
- [Home Assistant — Détail technique](#home-assistant-détail-technique)
  - [Connexion](#connexion)
  - [Événements souscrits](#événements-souscrits)
  - [Flux de données](#flux-de-données)
  - [Persistance locale](#persistance-locale)
- [Logging](#logging)
  - [LogManager (v4)](#logmanager-v4)
  - [Fichier log](#fichier-log)
- [Tests](#tests)
  - [Tests Python (92)](#tests-python-92)
  - [Scripts PowerShell](#scripts-powershell)
- [Dépannage](#dépannage)
  - [L'application ne se lance pas (STATUS_DLL_NOT_FOUND)](#lapplication-ne-se-lance-pas-status_dll_not_found)
  - [TTS ne fonctionne pas (pas de son)](#tts-ne-fonctionne-pas-pas-de-son)
  - [STT ne transcrit pas](#stt-ne-transcrit-pas)
  - [EXO ne m'entend pas](#exo-ne-mentend-pas)
  - [Erreur `AUDCLNT_E_NOT_STOPPED`](#erreur-audclnt_e_not_stopped)
  - [Configuration non trouvée](#configuration-non-trouvée)
  - [Géolocalisation échoue](#géolocalisation-échoue)
  - [Backend Python ne se connecte pas à HA](#backend-python-ne-se-connecte-pas-à-ha)
- [Changelog](#changelog)
  - [v4.2 — Mars 2026 — "Premium Open-Source Edition"](#v42-mars-2026-premium-open-source-edition)
  - [v4.1 — Mars 2026](#v41-mars-2026)
  - [v4.0 — Mars 2026](#v40-mars-2026)
  - [v3.0 — Juillet 2025](#v30-juillet-2025)
  - [v2.1 — Octobre 2025](#v21-octobre-2025)
  - [v2.0](#v20)
- [Roadmap](#roadmap)
- [Limitations connues — XTTS v2 DirectML](#limitations-connues-xtts-v2-directml)
  - [Goulot GPT autorégressif (CPU)](#goulot-gpt-autorégressif-cpu)
  - [Portée de DirectML](#portée-de-directml)
  - [CUDA (RTX 3070 — À venir)](#cuda-rtx-3070-à-venir)
  - [Latence réseau WebSocket](#latence-réseau-websocket)
- [Contact](#contact)

<!-- /TOC -->

**Version 4.2 "Premium Open-Source Edition"** | Dernière mise à jour : Mars 2026

> ⚠️ **Document monolithique historique** — Les sections spécialisées (Architecture, Pipeline, TTS, STT, Serveurs) ont été déplacées dans des fichiers dédiés. Ce fichier conserve les sections uniques (Installation, Configuration, GUI, Dépannage, Changelog…) et fournit des renvois vers la documentation canonique.

---

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

# Terminal 1 — Serveur GUI/HA
python python/orchestrator/exo_server.py

# Terminal 2 — Serveur STT (Whisper.cpp GPU)
.\.venv_stt_tts\Scripts\python.exe python/stt/stt_server.py --backend whispercpp --model large-v3 --device gpu

# Terminal 3 — Serveur TTS (XTTS v2)
.\.venv_stt_tts\Scripts\python.exe python/tts/tts_server.py --voice "Claribel Dervla" --lang fr

# Terminal 4 — Serveur VAD Silero (optionnel)
.\.venv_stt_tts\Scripts\python.exe python/vad/vad_server.py

# Terminal 5 — Serveur WakeWord OpenWakeWord (optionnel)
.\.venv_stt_tts\Scripts\python.exe python/wakeword/wakeword_server.py

# Terminal 6 — Serveur Mémoire FAISS (optionnel)
.\.venv_stt_tts\Scripts\python.exe python/memory/memory_server.py

# Terminal 7 — Serveur NLU local (optionnel)
.\.venv_stt_tts\Scripts\python.exe python/nlu/nlu_server.py

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

> 📋 **Section déplacée** — Voir la documentation canonique :
> - [architecture.md](architecture.md) — Arborescence du projet, diagramme de communication, ports réseau
> - [EXO_SPEC.md](EXO_SPEC.md) — Spécification technique concise (source de vérité)
> - [architecture_graph.md](architecture_graph.md) — Graphe d'architecture détaillé

### Ports réseau (résumé)

| Port | Service |
|------|---------|
| 8765 | GUI / HA bridge (`exo_server.py`) |
| 8766 | STT Whisper (`stt_server.py`) |
| 8767 | TTS XTTS v2 (`tts_server.py`) |
| 8768 | VAD Silero (`vad_server.py`) |
| 8769 | Whisper.cpp backend HTTP |
| 8770 | WakeWord (`wakeword_server.py`) |
| 8771 | Mémoire FAISS (`memory_server.py`) |
| 8772 | NLU local (`nlu_server.py`) |
| 3000 | GUI React (Vite dev) |

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

### AssistantManager (v4)
Coordinateur central. Instancie et connecte tous les managers via signaux/slots Qt. Expose des Q_PROPERTY et Q_INVOKABLE
au QML. Dispatch les Function Calls Claude vers Home Assistant via VoicePipeline WebSocket. Auto-analyse les réponses
Claude pour extraction mémoire.

### ConfigManager (v4)
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

### ClaudeAPI (v4)
Client SSE streaming pour l'API Anthropic (`https://api.anthropic.com/v1/messages`). Function Calling avec 8 outils EXO.
Retry exponentiel (3 tentatives). Rate limiting (50 req/min). Modèle : `claude-sonnet-4-20250514`.

- `sendMessageFull(userMsg, systemPrompt, tools[], stream=true)`
- `sendToolResult(toolUseId, resultObj)` — réponse aux appels d'outils
- `buildEXOTools()` → 8 outils Function Calling (météo, HA, mémoire...)

### WeatherManager
OpenWeatherMap avec mise à jour automatique toutes les 10 minutes. Conseils vestimentaires basés sur température et
conditions. Géolocalisation IP via ip-api.com (HTTPS).

### AudioInput — Abstraction audio (v4.2)

Couche d'abstraction pour la capture audio, permettant de choisir entre Qt Multimedia et RtAudio WASAPI :

```
AudioInput (interface abstraite, app/audio/AudioInput.h)
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

Le backend est sélectionné via `[Audio] backend=qt` ou `backend=rtaudio` dans `assistant.conf`, ou via le ComboBox dans
SettingsPanel.qml.

### AIMemoryManager (v4)
Mémoire à **3 couches** :
- **Conversations** : buffer circulaire de 100 échanges
- **Préférences** : auto-détection regex (25+ patterns)
- **Souvenirs sémantiques** : extraction de faits avec décroissance d'importance

Persistance JSON v2 dans `%APPDATA%\EXOAssistant\`. Écritures atomiques (write → rename).

**Bridge FAISS (v4.2)** : Lorsque `[Memory] semantic_enabled=true`, AIMemoryManager se connecte en WebSocket à
`memory_server.py` (:8771) pour indexer et rechercher les souvenirs par similarité vectorielle (FAISS +
SentenceTransformers `all-MiniLM-L6-v2`). Les recherches vectorielles sont prioritaires, avec fallback sur la recherche
regex locale.

---

## 🔊 Pipeline vocal

> 📋 **Section déplacée** — Voir la documentation canonique :
> - [pipeline.md](pipeline.md) — FSM 6 états, VoicePipeline, StreamingSTT, AudioPreprocessor, VADEngine
> - [../guides/audio_pipeline.md](../guides/audio_pipeline.md) — Guide détaillé du pipeline audio

**Résumé** : Pipeline 6 états (Idle → DetectingSpeech → Listening → Transcribing → Thinking → Speaking). Capture 16 kHz
mono → DSP (Butterworth HP 150 Hz, noise gate, AGC) → VAD (builtin/Silero/hybrid) → Wake word → STT streaming →
NLU/Claude → TTS.

---

## 🗣️ Synthèse vocale (TTS)

> 📋 **Section déplacée** — Voir [../guides/tts.md](../guides/tts.md) pour la documentation complète (architecture cascade, DSP pipeline, analyse prosodique, configuration XTTS v2).

**Résumé** : Cascade XTTS v2 (ws://localhost:8767) → Qt TTS (fallback). DSP : EQ 3 kHz → Compresseur → Normalisation -14
dBFS → Fade → Anti-clip. Voix : `Claribel Dervla`, 58 voix disponibles, RTF ~0.05 GPU.

---

## 🎤 Reconnaissance vocale (STT)

> 📋 **Section déplacée** — Voir [../guides/stt.md](../guides/stt.md) pour la documentation complète (backends, configuration, protocole WebSocket, benchmarks).

**Résumé** : Dual backend — Whisper.cpp Vulkan GPU (défaut, RTF 0.08–0.23) / faster-whisper CPU (fallback, RTF 1.0–1.5).
Port 8766, protocole WebSocket binaire PCM16. Langue : français, beam size : 5.

---

## 🐍 Serveurs Python

> 📋 **Section déplacée** — Voir [services.md](services.md) pour la documentation complète de chaque microservice (commandes de lancement, protocoles, configuration).

**Résumé** : 7 microservices Python — STT (:8766), TTS (:8767), VAD (:8768), WakeWord (:8770), Memory FAISS (:8771), NLU
(:8772), GUI/HA bridge (:8765). Deux venvs : `.venv_stt_tts` (Python 3.11, IA) et `.venv` (Python 3.13, orchestrateur).

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

Cache en mémoire de toutes les entités HA. Requêtes : `get_entity`, `list_by_domain`, `list_by_area`, `search`,
`summary`, `all_summaries`. Mise à jour en temps réel sur événements `state_changed`.

### `ha_devices.py` — Gestionnaire d'appareils

Matching par MAC et IP (normalisé). Persistance JSON dans `%APPDATA%\EXOAssistant\ha_devices.json`. Mapping appareil →
entités. Fallback sur cache offline.

### `ha_areas.py` — Gestionnaire de pièces

Mappings area ↔ device ↔ entity. Assignation via commandes WS (`device_registry/update`, `entity_registry/update`).
Synchronisation Plans → HA (drag-drop met à jour l'area HA). Recherche floue de pièce par nom.

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

### Signal audio C++ → QML

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
python -m pytest tests/python/ -v
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

Le moteur cherche `config/assistant.conf` en relatif depuis le répertoire du projet. Lancer depuis la racine du projet
ou utiliser `launch_exo.ps1`.

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
- ✅ **RtAudio WASAPI** — capture audio faible latence via abstraction AudioInput (app/audio/), backend sélectionnable
Qt/RtAudio
- ✅ **XTTS v2** — TTS premium neural multilingue, streaming PCM16, contrôle pitch/rate/style
- ✅ **Silero VAD** — VAD neural via WebSocket (vad_server.py :8768), modes builtin/silero/hybrid
- ✅ **DSP noisereduce** — réduction de bruit spectrale intégrée à stt_server.py, intensité configurable
- ✅ **OpenWakeWord** — détection neurale wake-word (wakeword_server.py :8770), complément transcript
- ✅ **STT CPU fallback** — whispercpp_cpu backend GGUF int8
- ✅ **FAISS + SentenceTransformers** — mémoire sémantique vectorielle (memory_server.py :8771), bridge C++ WebSocket
- ✅ **NLU local** — classification d'intention regex + framework transformers (nlu_server.py :8772)
- ✅ **Visualizer GPU** — ShaderEffect GLSL (remplace Canvas CPU), 60 FPS, fallback Canvas
- ✅ **SettingsPanel premium** — audio backend, VAD backend, noise reduction, wakeword neural, semantic memory, chat
input
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
- ✅ **Interface VS Code** — 10 composants QML (Sidebar, StatusIndicator, MicrophoneLevel, TranscriptView, ResponseView,
Visualizer, BottomBar, SettingsPanel, HistoryPanel, MainWindow)
- ✅ **VoicePipeline v4** — FSM 5 états, VADEngine, AudioPreprocessor, StreamingSTT WebSocket
- ✅ **TTSManager v4** — Cascade XTTS v2/Qt TTS, DSP 5 étapes (EQ, Compressor, Normalizer, Fade, Anti-clip), buffer PCM +
pompe timer
- ✅ **Serveurs Python STT/TTS** — stt_server.py (Whisper.cpp Vulkan GPU + fallback CPU, port 8766), tts_server.py (XTTS
v2 58 voix, port 8767)
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
- ✅ Reconnaissance vocale OpenWakeWord + TTS
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

## Limitations connues — XTTS v2 DirectML

### Goulot GPT autorégressif (CPU)
Le module GPT de XTTS v2 s'exécute **sur CPU** (PyTorch). Seul le vocodeur HiFi-GAN est accéléré via ONNX Runtime
DirectML sur le GPU AMD. La latence de première syllabe dépend donc de la vitesse CPU pour la partie autorégressive.

### Portée de DirectML
DirectML accélère uniquement le **vocodeur HiFi-GAN** (conversion mel-spectrogramme → PCM). Le modèle GPT et le speaker
encoder restent sur CPU. L'accélération GPU est donc partielle.

### CUDA (RTX 3070 — À venir)
Le support CUDA natif sous Windows est prévu pour remplacer le pipeline DirectML. Cela permettra l'accélération complète
(GPT + vocodeur) sur GPU NVIDIA.

### Latence réseau WebSocket
Le streaming TTS passe par WebSocket (`ws://localhost:8767`). Sur une machine locale, la latence est négligeable, mais
elle peut devenir perceptible si le serveur TTS est distant.

---

## Contact

- **Développeur** : Alexandre VDF
- **Repository** : [github.com/AlexanderVDF/EXO](https://github.com/AlexanderVDF/EXO)

---
*Retour à l'index : [docs/README.md](../README.md)*
