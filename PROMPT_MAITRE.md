# PROMPT MAÎTRE — EXO v9.0

> **Source de vérité unique** • 30 mars 2026
> Ce document EST l'architecture. Il n'y a rien d'autre.
> Toute information absente de ce document n'existe pas.

---

## 1. IDENTITÉ

| Champ | Valeur |
|-------|--------|
| Nom | EXO Assistant |
| Version | 9.0 (Observability & Résilience) |
| Phonétique | /ɛɡ.zɔ/ ou /ɛk.so/ |
| Wakewords | `EXO`, `EXO!`, `EXO?` |
| Nature | Assistant vocal IA offline-first, Windows natif |
| Licence | MIT |
| Branche | `main` |
| OS | Windows 11 uniquement (production) |
| Auteur | Alexandre VDF |

---

## 2. STACK TECHNOLOGIQUE

| Composant | Technologie | Version |
|-----------|-------------|---------|
| Moteur C++ | Qt / QML | 6.9.3 (MSVC 2022 x64) |
| Standard | C++17 | — |
| Build | CMake | ≥ 3.20 |
| STT | Whisper.cpp | Vulkan GPU, modèle **medium** |
| TTS | XTTS v2 (Coqui) | CUDA RTX 3070 |
| VAD | Silero VAD | neural, hybrid backend |
| WakeWord | OpenWakeWord | `hey_jarvis.onnx` |
| LLM | Claude | `claude-sonnet-4-20250514` |
| Mémoire sémantique | FAISS + SentenceTransformers | `all-MiniLM-L6-v2` (384-dim) |
| NLU | Classifieur regex local | — |
| Audio capture | RtAudio (WASAPI) ou QAudioSource | — |
| Audio output | QAudioSink | 16 kHz mono PCM16 |
| GUI principale | QML | VS Code dark + Fluent Design |
| GUI admin | React 18 + Vite | optionnel |
| Domotique | Home Assistant | REST + WebSocket |
| Python IA | 3.11 | venv `.venv_stt_tts` |
| Python orchestrateur | 3.13 | venv `.venv` |
| GPU affichage | AMD RX 6750 XT | Direct3D11 (Qt) + Vulkan (STT) |
| GPU compute | NVIDIA RTX 3070 SUPRIM X | CUDA (TTS) |

---

## 3. ARCHITECTURE

### 3.1 Vue d'ensemble

```
┌──────────────────────────────────────────────────────────────────┐
│                        EXO Assistant (C++/Qt)                    │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────────┐   │
│  │ AudioInput │→ │ VoicePipeline│→ │ AssistantManager       │   │
│  │ (RtAudio)  │  │ (FSM)        │  │ (coordinateur central) │   │
│  └────────────┘  └──────────────┘  └────────────────────────┘   │
│        ↓               ↓ ↑              ↓           ↓           │
│  ┌──────────┐   ┌──────────────┐  ┌──────────┐ ┌──────────┐   │
│  │ DSP Entrée│   │ PipelineEvent│  │ Claude   │ │ Weather  │   │
│  │ HP+Gate+  │   │ (34 types)   │  │ API (SSE)│ │ Manager  │   │
│  │ AGC+Norm  │   └──────────────┘  └──────────┘ └──────────┘   │
│  └──────────┘                           ↓                       │
│        ↓                          ┌──────────┐                  │
│  ┌──────────────── WebSocket ─────┤ TTSMgr   │                  │
│  │                                │ (DSP out) │                  │
│  │  ┌─────┐ ┌─────┐ ┌─────┐     └──────────┘                  │
│  │  │ STT │ │ VAD │ │ WW  │           ↓                        │
│  │  │:8766│ │:8768│ │:8770│     ┌──────────┐                   │
│  │  └─────┘ └─────┘ └─────┘     │ QAudioSink│                  │
│  │  ┌─────┐ ┌─────┐ ┌─────┐     │ (playback)│                  │
│  │  │ TTS │ │ MEM │ │ NLU │     └──────────┘                   │
│  │  │:8767│ │:8771│ │:8772│                                     │
│  │  └─────┘ └─────┘ └─────┘                                    │
│  │  ┌──────────────────────┐                                    │
│  │  │ Orchestrateur  :8765 │                                    │
│  │  └──────────────────────┘                                    │
│  └──────────────────────────────────────────────────────────────│
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 Sept microservices Python

| Service | Port | Venv | Technologie | Rôle |
|---------|------|------|-------------|------|
| `exo_server` | 8765 | `.venv` (3.13) | websockets + aiohttp | Orchestrateur, pont GUI↔C++ |
| `stt_server` | 8766 | `.venv_stt_tts` (3.11) | whisper.cpp Vulkan | Speech-to-Text |
| `tts_server` | 8767 | `.venv_stt_tts` (3.11) | XTTS v2 CUDA | Text-to-Speech |
| `vad_server` | 8768 | `.venv_stt_tts` (3.11) | Silero VAD ONNX | Voice Activity Detection |
| `wakeword_server` | 8770 | `.venv_stt_tts` (3.11) | OpenWakeWord ONNX | Détection "EXO" |
| `memory_server` | 8771 | `.venv_stt_tts` (3.11) | FAISS + SentenceTransformers | Mémoire sémantique |
| `nlu_server` | 8772 | `.venv_stt_tts` (3.11) | Regex classifieur | Intent detection |

**Note :** `stt_server` délègue à `whisper-server.exe` via HTTP POST sur `http://127.0.0.1:8769/inference` (port interne, non exposé).

### 3.3 Patterns de conception

| Pattern | Fichier | Usage |
|---------|---------|-------|
| Machine à états (FSM) | `voicepipeline.h` | Pipeline vocal 6 états |
| Bus d'événements | `pipelineevent.h` | 34 types d'événements |
| Health Check | `healthcheck.h` | Ping/pong JSON 10s, timeout 5s |
| Service Supervisor | `servicesupervisor.h` | Lancement/supervision microservices |
| Singleton settings | `configmanager.h` | QSettings INI, 3 fichiers config |
| Observer pattern | `assistantmanager.h` | Signaux Qt cross-module |
| Command pattern | `claudeapi.h` | 8 Function Calling tools |
| In-process cache | `contextcache.h` | TTL par clé, refresh arrière-plan |
| Instrumentation | `latencymetrics.h` | 9 timestamps pipeline, métriques dérivées |
| Cascade fallback | `ttsmanager.h` | XTTS → Qt TTS → Erreur |

### 3.4 Ownership mémoire C++

Tous les objets ont `AssistantManager` comme parent Qt. Pas de `unique_ptr`/`shared_ptr` isolés.

```
AssistantManager (QObject root)
├── ConfigManager
├── LogManager
├── PipelineEventBus
│   └── PipelineTracer (timeline + détection anomalies)
├── HealthCheck
├── VoicePipeline
│   ├── AudioInput (RtAudio ou QAudioSource)
│   ├── CircularAudioBuffer (ring buffer 32s @ 16kHz)
│   ├── AudioPreprocessor (HP + NoiseGate + AGC + Norm)
│   ├── VADEngine (→ vad_server :8768)
│   ├── StreamingSTT (→ stt_server :8766)
│   └── WakeWordEngine (→ wakeword_server :8770)
├── TTSManager
│   ├── TTSWorker (thread dédié)
│   │   ├── TTSBackendXTTS (→ tts_server :8767)
│   │   └── TTSBackendQt (fallback)
│   └── TTSDSPProcessor (EQ→Comp→Norm→Fade→Clip)
├── ClaudeAPI (SSE + Function Calling + warmup/keepalive)
├── ContextCache (TTL per-key, background refresh)
├── LatencyMetrics (9 timestamps, 6 métriques dérivées)
├── WeatherManager (OpenWeatherMap)
├── AIMemoryManager (FAISS)
├── ServiceManager (lancement Python)
└── WebSocketClient (→ exo_server :8765)
```

### 3.5 Exposition QML

10 context properties exposées via `exposeToQml()` :

```cpp
assistantManager, voiceManager, ttsManager, claudeAPI,
configManager, logManager, pipelineEventBus, healthCheck,
weatherManager, memoryManager
```

---

## 4. PIPELINE VOCAL (FSM)

### 4.1 Machine à états

```
IDLE → DETECTING_SPEECH → LISTENING → TRANSCRIBING → THINKING → SPEAKING → IDLE
  ↑                                                                    |
  └────────────────────────────────────────────────────────────────────┘
```

| État | Déclencheur entrée | Action | Durée typique |
|------|-------------------|--------|---------------|
| `IDLE` | Fin de Speaking / Init | Écoute wakeword + VAD | ∞ |
| `DETECTING_SPEECH` | WakeWord détecté (seuil ≥ 0.7) | VAD confirme la voix | < 100 ms |
| `LISTENING` | VAD confirme parole | Capture audio → STT stream | 1–15 s |
| `TRANSCRIBING` | Silence détecté (VAD) | Whisper.cpp transcrit | 0.5–2 s |
| `THINKING` | Texte transcrit reçu | Claude SSE traite | 0.2–1 s (1er token) |
| `SPEAKING` | Réponse LLM reçue | TTS synthétise + playback | 1–10 s |

### 4.2 34 EventTypes

| Catégorie | Types |
|-----------|-------|
| **VAD** | `VADStarted`, `VADStopped`, `VADSpeechStart`, `VADSpeechEnd`, `VADError` |
| **STT** | `STTStarted`, `STTStopped`, `STTPartialResult`, `STTFinalResult`, `STTError`, `STTReady` |
| **LLM** | `LLMRequestSent`, `LLMTokenReceived`, `LLMResponseComplete`, `LLMError`, `LLMFunctionCall`, `LLMFunctionResult` |
| **TTS** | `TTSStarted`, `TTSStopped`, `TTSChunkReceived`, `TTSPlaybackStarted`, `TTSPlaybackFinished`, `TTSError`, `TTSReady` |
| **Audio** | `AudioCaptureStarted`, `AudioCaptureStopped`, `AudioPlaybackStarted`, `AudioPlaybackStopped`, `AudioLevelUpdate` |
| **Orchestrateur** | `PipelineStarted`, `PipelineStopped`, `PipelineError`, `WakeWordDetected`, `WakeWordReady`, `ServiceStatusChanged` |

### 4.3 Latences typiques

| Étape | Latence |
|-------|---------|
| VAD inference | < 5 ms |
| WakeWord inference | < 10 ms |
| STT (medium, Vulkan GPU) | 500 ms – 2 s |
| NLU regex | < 50 ms |
| Claude 1er token (SSE) | 200 ms – 1 s |
| TTS 1er chunk | 200 – 500 ms |
| DSP sortie | < 1 ms |
| RTF STT (AMD RX 6750 XT) | 0.08 – 0.23 |
| Perceived latency (v8.1 ULL) | tTtsFirstAudio − tSttFinal |

---

## 5. AUDIO

### 5.1 Formats audio

| Point | Sample rate | Channels | Format | Buffer |
|-------|------------|----------|--------|--------|
| Capture micro | 16 000 Hz | Mono | PCM16 | — |
| VAD chunks | 16 000 Hz | Mono | Float32 | 512 samples (32 ms) |
| WakeWord chunks | 16 000 Hz | Mono | Float32 | 1280 samples (80 ms) |
| STT stream | 16 000 Hz | Mono | PCM16 | continu |
| TTS sortie native | 24 000 Hz | Mono | PCM16 | — |
| Playback QAudioSink | 16 000 Hz | Mono | PCM16 | rééchantillonné |
| Ring buffer | 16 000 Hz | Mono | PCM16 | 32 s (512 000 samples) |

### 5.2 Pipeline entrée (capture → STT)

```
Micro → RtAudio/QAudioSource (16kHz PCM16)
  → CircularAudioBuffer (32s ring)
  → AudioPreprocessor
      → Butterworth HP 2e ordre, fc=150 Hz
      → Noise Gate (configurable)
      → AGC (configurable)
      → RMS Normalizer
  → VAD (512 samples / 32ms) → seuil 0.45
  → WakeWord (1280 samples / 80ms) → seuil ≥ 0.7, cooldown 3s
  → STT stream (WebSocket :8766 → whisper-server.exe :8769)
```

### 5.3 Pipeline sortie (TTS → playback)

```
Claude réponse (texte)
  → TTSManager
      → découpage en phrases (timeout 12s par chunk)
      → TTSBackendXTTS (WebSocket :8767, CUDA)
          ↓ fallback si timeout
      → TTSBackendQt (synthèse locale)
  → PCM16 24kHz
  → TTSDSPProcessor (5 étages)
  → Rééchantillonnage 24→16 kHz
  → Crossfade inter-chunks (kSmooth = 0.7)
  → QAudioSink (playback 16kHz mono)
```

### 5.4 DSP chaîne sortie (5 étages)

Valeurs réelles du code (`TTSDSPProcessor::configure`) :

| Étage | Paramètres | Rôle |
|-------|-----------|------|
| 1. EQ peak/bell | 3 000 Hz, +1.5 dB, Q=1.0 | Présence voix douce |
| 2. Compresseur | seuil −14 dB, ratio 1.8:1, attack 5 ms, release 50 ms | Compression douce |
| 3. Normalizer | cible −14 dBFS | Niveau constant |
| 4. Fade | in 15 ms, out 20 ms | Anti-pop neural TTS |
| 5. Anti-clip | peak limiter | Protection saturation |

### 5.5 DSP chaîne entrée (AudioPreprocessor)

| Étage | Paramètres |
|-------|-----------|
| 1. High-pass | Butterworth 2e ordre, fc=150 Hz |
| 2. Noise gate | seuil configurable via GUI |
| 3. AGC | gain auto, configurable via GUI |
| 4. Normalizer | RMS |

---

## 6. PROTOCOLES WEBSOCKET

### 6.1 STT (port 8766)

**Client → Serveur :**

| Type | Payload |
|------|---------|
| `start` | `{"type":"start"}` |
| audio | Binaire PCM16 16kHz mono |
| `end` | `{"type":"end"}` |
| `cancel` | `{"type":"cancel"}` |
| `config` | `{"type":"config","model":"medium","language":"fr","beam_size":3}` |
| `ping` | `{"type":"ping"}` |

**Serveur → Client :**

| Type | Payload |
|------|---------|
| `ready` | `{"type":"ready","model":"medium","device":"gpu"}` |
| `partial` | `{"type":"partial","text":"..."}` |
| `final` | `{"type":"final","text":"...","segments":[...],"duration":1.23}` |
| `pong` | `{"type":"pong"}` |
| `error` | `{"type":"error","message":"..."}` |

**Architecture interne :** `stt_server.py` → HTTP POST → `whisper-server.exe` (port 8769)

**Filtre anti-hallucination :** crédits/génériques, mots répétés en boucle, phrases trop courtes.

### 6.2 TTS (port 8767)

**Client → Serveur :**

| Type | Payload |
|------|---------|
| `synthesize` | `{"type":"synthesize","text":"...","voice":"Claribel Dervla","lang":"fr","rate":1.0,"pitch":1.0,"style":"conversational"}` |
| `cancel` | `{"type":"cancel"}` |
| `list_voices` | `{"type":"list_voices"}` |
| `ping` | `{"type":"ping"}` |

**Serveur → Client :**

| Type | Payload |
|------|---------|
| `ready` | `{"type":"ready","sample_rate":24000}` |
| `start` | `{"type":"start","estimated_duration":2.5}` |
| audio | Binaire PCM16 24kHz mono |
| `end` | `{"type":"end","duration":2.3}` |
| `voices` | `{"type":"voices","voices":["Claribel Dervla","Nova Hogarth",...]}` |
| `pong` | `{"type":"pong"}` |
| `error` | `{"type":"error","message":"..."}` |

**Langues XTTS :** fr, en, de, es, it, pt, pl, tr, ru, nl, cs, ar, zh, ja, hu, ko, hi (17)

**Cascade fallback :** TTSBackendXTTS (timeout 12s) → TTSBackendQt → Erreur

**Cache :** LRU, clé = hash(texte + voix + langue + paramètres)

### 6.3 VAD (port 8768)

Silero VAD neural. Chunks de 512 samples (32 ms). Seuil par défaut : 0.45.

### 6.4 WakeWord (port 8770)

OpenWakeWord, modèle `hey_jarvis.onnx`. Chunks de 1280 samples (80 ms).
Seuil minimum : **0.7** (Python ET C++). Cooldown : **3 secondes**.
Détection **interdite** pendant `SPEAKING`, `THINKING`, `TRANSCRIBING`.

### 6.5 Memory (port 8771)

FAISS + SentenceTransformers (`all-MiniLM-L6-v2`, 384 dimensions).
Limite : 10 000 entrées. Répertoire : `D:\EXO\faiss\semantic_memory`.

### 6.6 NLU (port 8772)

Classifieur regex local. Dispatch via `{"action":"..."}` (exception : pas `{"type":"..."}`).

### 6.7 Orchestrateur (port 8765)

Pont WebSocket entre GUI React et le moteur C++.

### 6.8 Health Check

Intervalle : 10 s. Timeout : 5 s. Protocole : ping/pong JSON sur chaque WebSocket service.

---

## 7. LLM — CLAUDE

### 7.1 Modèle & configuration

| Paramètre | Valeur |
|-----------|--------|
| Modèle | `claude-sonnet-4-20250514` |
| Mode | SSE (Server-Sent Events) streaming |
| Max tokens | 4 096 |
| Température | 0.7 |
| Rate limit | 50 req/min |
| Timeout | 30 s |
| Retries | 3 (exponentiel) |

### 7.2 Huit Function Calling tools

| Tool | Description |
|------|-------------|
| `get_weather` | Météo actuelle |
| `ha_turn_on` | Allumer appareil HA |
| `ha_turn_off` | Éteindre appareil HA |
| `ha_toggle` | Basculer appareil HA |
| `ha_set_brightness` | Luminosité HA |
| `ha_set_color` | Couleur HA |
| `ha_get_state` | État appareil HA |
| `ha_list_entities` | Lister entités HA |

### 7.3 Treize actions Home Assistant

Les 8 FC tools + : `ha_set_temperature`, `ha_play_media`, `ha_pause_media`, `ha_stop_media`, `ha_list_devices`, `ha_list_areas`.

HA connexion : REST + WebSocket. Ping/pong 30 s. Timeout futures 15 s.
Bootstrap parallèle : `asyncio.gather(get_states, devices, areas, entity_registry)`.

---

## 8. CONFIGURATION

### 8.1 Trois fichiers de configuration

| Fichier | Rôle | Priorité |
|---------|------|----------|
| `assistant.conf` | Config par défaut, lecture seule | Basse |
| `.env` | Secrets (API keys) | — |
| `%APPDATA%\EXOAssistant\user_config.ini` | Préférences utilisateur, écrasement | **Haute** |

`user_config.ini` est géré par `ConfigManager` via `QSettings` INI. `setUserValue()` appelle `setValue()` + `sync()`.

### 8.2 Variables d'environnement (lancement)

```
EXO_WHISPER_MODELS   = D:\EXO\models\whisper
EXO_WHISPERCPP_BIN   = D:\EXO\whispercpp\build_vk\bin\Release
EXO_XTTS_MODELS      = D:\EXO\models\xtts
EXO_FAISS_DIR        = D:\EXO\faiss\semantic_memory
EXO_WAKEWORD_MODELS  = D:\EXO\models\wakeword
HF_HOME              = D:\EXO\cache\huggingface
TRANSFORMERS_CACHE   = D:\EXO\cache\huggingface\hub
```

### 8.3 Chemins SSD D:\EXO\

```
D:\EXO\
├── models\
│   ├── whisper\         ← ggml-medium.bin
│   ├── xtts\            ← modèles XTTS v2
│   └── wakeword\        ← hey_jarvis.onnx
├── whispercpp\
│   └── build_vk\bin\Release\  ← whisper-server.exe
├── faiss\
│   └── semantic_memory\ ← index FAISS
└── cache\
    └── huggingface\     ← cache HF Hub
```

**INTERDIT :** Stocker des modèles sur `C:\`. Ancien chemin `J:\EXO\` obsolète.

### 8.4 Constantes clés (ConfigManager.h)

| Constante | Valeur |
|-----------|--------|
| `DEFAULT_WAKE_WORD` | `"Exo"` |
| `DEFAULT_WEATHER_CITY` | `"Paris"` |
| `DEFAULT_CLAUDE_MODEL` | `"claude-sonnet-4-20250514"` |
| `DEFAULT_VOICE_LANGUAGE` | `"fr-FR"` |
| `DEFAULT_VOICE_RATE` | −0.3 |
| `DEFAULT_VOICE_PITCH` | −0.1 |
| `DEFAULT_VOICE_VOLUME` | 0.9 |
| `DEFAULT_WEATHER_INTERVAL` | 600 000 ms (10 min) |
| `DEFAULT_STT_SERVER_URL` | `ws://localhost:8766` |
| `DEFAULT_TTS_SERVER_URL` | `ws://localhost:8767` |
| `DEFAULT_GUI_SERVER_URL` | `ws://localhost:8765` |
| `DEFAULT_STT_MODEL` | `"large-v3"` (constante — réalité : medium via args) |
| `DEFAULT_STT_LANGUAGE` | `"fr"` |
| `DEFAULT_STT_BEAM_SIZE` | 5 |
| `DEFAULT_TTS_VOICE` | `"Claribel Dervla"` |
| `DEFAULT_TTS_ENGINE` | `"xtts_cuda"` |
| `DEFAULT_VAD_BACKEND` | `"hybrid"` |
| `DEFAULT_VAD_THRESHOLD` | 0.45 |

### 8.5 Sections INI utilisateur

```ini
[Audio]        backend=rtaudio
[TTS]          voice, engine, language, style, pitch, rate
[STT]          model, language, beam_size
[VAD]          backend, threshold
[WakeWord]     neural_enabled
[OpenWeatherMap] city, api_key
[Location]     auto_detection=false
[Appearance]   current_theme
[Claude]       model, temperature, base_url, max_tokens
[DSP]          noise_reduction_enabled, noise_reduction_strength
[Log]          level
```

---

## 9. GUI

### 9.1 Architecture QML

```
qml/
├── theme/Theme.qml          ← singleton design tokens
├── components/               ← 19 composants réutilisables
├── vscode/                   ← 12 panneaux applicatifs
├── pages/SettingsPage.qml    ← page paramètres
└── icons/                    ← 12 SVG Fluent
```

Taille fixe : **1280 × 800 px**. Pas de responsive. Pas de thème clair. Pas d'i18n.

### 9.2 Design System — Tokens

#### Couleurs

| Token | Hex |
|-------|-----|
| bg.primary | `#1E1E1E` |
| bg.secondary | `#252526` |
| bg.elevated | `#2D2D2D` |
| bg.hover | `#2A2D2E` |
| bg.active | `#37373D` |
| bg.input | `#3C3C3C` |
| accent.main | `#0078D4` |
| accent.light | `#3A96DD` |
| accent.dark | `#005A9E` |
| accent.hover | `#1A86D9` |
| accent.active | `#094771` |
| text.primary | `#E0E0E0` |
| text.secondary | `#A0A0A0` |
| text.muted | `#5A5A5A` |
| text.disabled | `#4A4A4A` |
| text.accent | `#007ACC` |
| text.link | `#3A96DD` |
| border.default | `#3C3C3C` |
| border.light | `#505050` |
| border.focus | `#007ACC` |
| success | `#4EC9B0` |
| warning | `#DCDCAA` |
| error | `#F44747` |
| info | `#569CD6` |

#### États vocaux

| État | Couleur |
|------|---------|
| listening | `#007ACC` |
| transcribing | `#DCDCAA` |
| thinking | `#C586C0` |
| speaking | `#4EC9B0` |
| idle | `#5A5A5A` |

#### Splash

`#1A1A2E` (bg) / `#E94560` (accent) / `#16213E` (panel)

#### Typographie

| Style | Taille | Poids |
|-------|--------|-------|
| H1 | 24 px | SemiBold |
| H2 | 20 px | Medium |
| H3 | 16 px | Medium |
| Body | 14 px | Regular |
| Small | 13 px | Regular |
| Label | 12 px | Medium |
| Caption | 12 px | Regular |
| Micro | 11 px | Regular |
| Tiny | 10 px | Regular |

Polices : `Inter, Segoe UI, Roboto, sans-serif` — code : `Cascadia Code, Fira Code, JetBrains Mono, Consolas`

#### Espacements

2, 4, 6, 8, 10, 12, 16, 20, 24, 32 px

Marges : marginH 24, marginV 20, paddingBtn 12, paddingCard 16, paddingSection 24

#### Rayons & ombres

Rayons : Small 4, Medium 6, Large 8, XL 12, Round 999 px

Ombres : Small 4px/0.15, Medium 8px/0.20, Large 16px/0.30

#### Animations

Fast 80 ms, Normal 120 ms, Slow 200 ms, Page 150 ms

Easing : `OutCubic` (apparitions), `InOutCubic` (toggles)

### 9.3 Dix-neuf composants QML

`ExoButton`, `ExoCard`, `ExoSwitch`, `ExoSlider`, `ExoTextField`, `ExoSearchField`, `ExoDialog`, `ExoConfirmDialog`, `ExoNotification`, `ExoPanelHeader`, `ExoSheet`, `ExoTab`, `ExoProgressBar`, `ExoBadge`, `ExoStatusPill`, `ExoPipelineStatus`, `ExoServiceStatus`, `ExoMicButton`, `ExoWaveform`

### 9.4 React admin (optionnel)

React 18 + Vite + TailwindCSS. Palette : `#0E0E11` / `#6C5CE7` / `#00CEC9`.
Konva (2D plans), Three.js (3D), vis-network (topologie), Phosphor Icons.
Écrans : Home, Plans, NetworkMap, Devices, Settings.

---

## 10. TESTS

**565 tests** : 7 CTest C++ + 558 pytest Python

| Type | Durée | Commande |
|------|-------|----------|
| C++ (CTest) | ~0.6 s | `ctest --test-dir build -C Release` |
| Python (pytest) | ~3 s | `pytest tests/ --ignore=tests/e2e_tools_test.py` |

Build tests : `cmake -DBUILD_TESTS=ON`

Lib partagée : `exo_testlib` (statique, utilisée par tous les tests C++)

CMake helper : `exo_add_test(test_nouveau)`

Convention : C++ `test<Nom>()`, Python `test_<desc>`

Fixtures pytest : `fake_entities`, `fake_devices`, `fake_areas`

Répertoires : `tests/cpp/`, `tests/integration/`, `tests/performance/`, `tests/python/`

---

## 11. ULTRA-LOW LATENCY (v8.1)

### 11.1 ContextCache

Cache in-process avec TTL par clé. Thread-safe (QMutex). Éviction automatique toutes les 10 s.

| Clé | TTL | Usage |
|-----|-----|-------|
| `weather` | 60 s | Résultat `get_weather` |
| `datetime` | 10 s | Résultat `get_datetime` |
| `ha_state` | 30 s | État Home Assistant |

Signals : `cacheHit`, `cacheMiss`, `refreshNeeded`, `entryExpired`.

Refresh en arrière-plan : `addRefreshRule(key, intervalMs)` → émet `refreshNeeded` quand TTL proche de l'expiration.

### 11.2 LatencyMetrics

Singleton d'instrumentation pipeline. 9 timestamps par interaction, 6 métriques dérivées.

| Timestamp | Posé dans |
|-----------|-----------|
| `tSttStart` | VoicePipeline (handleVAD) |
| `tSttPartialFirst` | VoicePipeline (onSTTPartial) |
| `tSttFinal` | VoicePipeline (onSTTFinal) |
| `tLlmRequest` | ClaudeAPI (startRequest) |
| `tLlmFirstToken` | ClaudeAPI (handleContentBlockDelta) |
| `tLlmComplete` | ClaudeAPI (handleMessageStop) |
| `tTtsFirstChunk` | TTSManager (onWorkerChunk) |
| `tTtsFirstAudio` | TTSManager (pumpBuffer) |
| `tResponseDone` | TTSManager (finalizeSpeech) |

Métriques dérivées : `sttLatency`, `llmFirstTokenLatency`, `llmTotalLatency`, `ttsLatency`, `perceivedLatency` (tTtsFirstAudio − tSttFinal), `endToEnd`.

Historique : 100 snapshots max. `averages(lastN)` pour moyennes glissantes. `getLatencyReport()` exposé QML.

### 11.3 ClaudeAPI Warmup & KeepAlive

- `initWarmup()` — ping léger non-streaming au démarrage (1 token max, `max_tokens=1`)
- `startKeepAlive(240000)` — timer VeryCoarseTimer, renvoie un warmup toutes les 4 min
- `stopKeepAlive()` — arrête le timer

Objectif : connexion TCP/TLS pré-établie → latence 1er token réduite.

---

## 12. OBSERVABILITY, RÉSILIENCE & SÉCURITÉ (v9.0)

### 12.1 Modules partagés (`python/shared/`)

| Module | Rôle |
|--------|------|
| `log_manager.py` | Logging structuré JSON, rotation, correlation IDs |
| `metrics_manager.py` | Counters, Gauges, Histograms, Timers |
| `trace_manager.py` | Tracing distribué (traces + spans) |
| `error_manager.py` | Catégories d'erreurs, retry, timeout, fallback |
| `config_manager.py` | Config centralisée dot-notation, hot-reload |
| `security_manager.py` | Permissions par domaine, audit log JSONL |
| `supervisor_manager.py` | Health checks, watchdog, auto-restart |
| `resilience.py` | CircuitBreaker, décorateur `@resilient` |
| `base_service.py` | Fondation unifiée, `init_v9()` factory |

### 12.2 Intégration

Chaque microservice (25 au total) intègre v9 via :
```python
from shared.base_service import init_v9
_v9 = init_v9("service_name", port)
```

Messages WS standards gérés par BaseService : `ping`, `health`, `metrics`, `traces`, `errors`.

### 12.3 CircuitBreaker

États : CLOSED → OPEN (après N échecs) → HALF_OPEN (après cooldown). Registre global `get_breaker(name)`.

---

## 13. INVARIANTS & CONTRAINTES

### Invariants absolus

1. **XTTS v2 obligatoire.** Jamais Piper. Jamais autre moteur TTS.
2. **Whisper.cpp obligatoire.** Modèle medium en production. Jamais faster-whisper en prod.
3. **CUDA RTX 3070 pour TTS.** GPU compute dédié.
4. **Vulkan AMD 6750 XT pour STT.** GPU séparé.
5. **7 microservices Python.** Pas de fusion, pas de suppression.
6. **Pipeline FSM 6 états.** Transitions strictes, pas de raccourcis.
7. **WakeWord seuil ≥ 0.7.** Cooldown 3 s. Interdit pendant Speaking/Thinking/Transcribing.
8. **Données sur D:\EXO\.** Jamais C:\. J:\EXO\ obsolète.
9. **Windows terminal intégré VS Code.** Jamais Start-Process, jamais cmd.exe.
10. **Fallback TTS Qt uniquement en erreur critique.** Retry auto dans `tryPythonTTS()`.

### Contraintes de lancement

- Lancer EXO = exécuter la tâche VS Code `launch_all` (7 serveurs parallèles)
- Puis lancer `build\Release\RaspberryAssistant.exe`
- Dossiers ignorés pour contexte Copilot : `build/`, `logs/`, `models/`, `whisper.cpp/models/`, `.venv*/`, `node_modules/`

### VRAM acceptable

STT (Vulkan) : 1–2 Go. TTS (CUDA) : 2–4 Go.

---

## 14. RÈGLES COPILOT

### Style

Français, technique, structuré, sans blabla, niveau architecte système.

### Interdictions

- **Anti-Piper** : ne jamais proposer Piper TTS.
- **Anti-downgrade STT** : ne jamais proposer tiny, small, faster-whisper en production.
- **Anti-Start-Process** : ne jamais utiliser Start-Process, cmd.exe, fenêtres externes.
- **Anti-C:\** : ne jamais stocker de modèles sur C:\.
- **Anti-fragmentation doc** : un seul Prompt Maître, pas de .md dispersés.

### Macros de log

```cpp
hLog(), hConfig(), hClaude(), hVoice(), hWeather(), hAssistant()
hDebug(cat), hWarning(cat), hCritical(cat)
```

### Conventions commit

`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`

---

## 15. LIMITATIONS CONNUES

| Composant | Limitation | Contournement |
|-----------|-----------|---------------|
| STT (Whisper) | Hallucinations (crédits, sous-titres, mots répétés). Filtre `_is_hallucination()` pas 100% fiable | Filtre regex + longueur minimum |
| STT | Latence 1er mot : 500ms–2s | Modèle medium (trade-off qualité/vitesse) |
| TTS | Timeout 12s par chunk | Découpage en phrases côté TTSManager |
| VAD | Chunks fixes 32ms (contrainte Silero), sensible à la musique | Seuil 0.45 ajustable |
| WakeWord | Un seul modèle actif (`hey_jarvis`), cooldown 3s | — |
| NLU | Dispatch via `"action"` (incohérence avec `"type"` du reste) | Convention documentée |
| Mémoire | FAISS limité à 10 000 entrées | Suffisant pour usage personnel |
| GUI | Taille fixe 1280×800, pas de responsive, pas de thème clair, pas d'i18n | V6 : responsive + i18n |
| RAM | 7 processus Python ≈ 2–3 Go | Normal pour 7 services IA |
| OS | Windows uniquement | V6 : Raspberry Pi 5 ciblé |
| Mémoire AI | 100 échanges max, écritures atomiques tmp→rename | — |
| Géolocalisation | IP donne ville ISP, pas ville réelle. Désactivée par défaut | Saisie manuelle ville |

---

## 16. ÉVOLUTIONS (v10)

| Objectif | Statut |
|----------|--------|
| Google Calendar integration | Planifié |
| Spotify / Tidal | Planifié |
| Raspberry Pi 5 (ARM) | Planifié |
| Application mobile companion | Planifié |
| Docker packaging | Planifié |
| i18n GUI | Planifié |
| Thème clair | Planifié |
| Tests E2E | Planifié |
| Auto-update documentation | Planifié |
| Optimisation CUDA TTS (full GPU) | Planifié |

---

## 17. INSTALLATION

### Prérequis

- Windows 11 x64, MSVC 2022, Qt 6.9.3, CMake ≥ 3.20
- Python 3.11 (.venv_stt_tts) + Python 3.13 (.venv)
- GPU NVIDIA (CUDA) + GPU AMD (Vulkan)

### Build

```powershell
cmake -B build -G "Visual Studio 17 2022" -DCMAKE_PREFIX_PATH="C:/Qt/6.9.3/msvc2022_64"
cmake --build build --config Release
```

### Deployment

```powershell
windeployqt.exe build/Release/RaspberryAssistant.exe --qmldir qml
```

### Python

```bash
# venv IA (3.11)
pip install torch==2.4.1 torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cu121
pip install websockets numpy soundfile "transformers>=4.40,<4.50"
pip install TTS silero-vad onnxruntime noisereduce openwakeword faiss-cpu sentence-transformers

# venv orchestrateur (3.13)
pip install "aiohttp>=3.9" "websockets>=12" "pytest>=8" "pytest-asyncio>=0.23"
```

### Dépannage

| Problème | Solution |
|----------|----------|
| CUDA non détecté | Vérifier `torch.cuda.is_available()`, driver NVIDIA ≥ 535 |
| Whisper timeout | Vérifier `whisper-server.exe` sur port 8769 |
| TTS silencieux | Vérifier port 8767, logs Python |
| WakeWord non détecté | Vérifier seuil ≥ 0.7, modèle `hey_jarvis.onnx` |
| Config non sauvée | Vérifier droits écriture `%APPDATA%\EXOAssistant\` |
| RAM élevée | Normal (7 services Python ≈ 2-3 Go) |
| Géoloc mauvaise ville | Désactiver dans paramètres, saisir ville manuellement |
| Log file | `%APPDATA%\EXOAssistant\EXO Assistant\henri.log` |

---

> **Ce document est la seule vérité.** Toute modification d'architecture doit être reflétée ici.
> Dernière mise à jour : 30 mars 2026 — EXO v9.0
