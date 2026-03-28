> 🧭 [Index](../README.md) → [Architecture](../README.md#-architecture--spécifications--core) → architecture.md
# Architecture EXO v4.2
> Documentation EXO v4.2 — Section : Architecture
> Dernière mise à jour : Mars 2026

---

<!-- TOC -->
## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Couches architecturales](#couches-architecturales)
  - [1. Interface utilisateur (QML)](#1-interface-utilisateur-qml)
  - [2. Couche applicative (C++ Qt)](#2-couche-applicative-c-qt)
  - [3. Microservices Python (WebSocket)](#3-microservices-python-websocket)
  - [4. Intégrations externes](#4-intégrations-externes)
- [Patterns de conception](#patterns-de-conception)
- [Communication inter-modules](#communication-inter-modules)
- [Fichiers de configuration](#fichiers-de-configuration)

<!-- /TOC -->

## Vue d'ensemble

EXO est un assistant vocal modulaire combinant un client C++/Qt temps réel et 7 microservices Python communiquant par
WebSocket.

```
┌──────────────────────────────────────────────────────────────────┐
│                        QML GUI (Qt Quick)                        │
│  MainWindow ─ Sidebar ─ TranscriptView ─ Visualizer ─ Settings  │
└───────────────────────────────┬──────────────────────────────────┘
                                │ Context Properties
┌───────────────────────────────▼──────────────────────────────────┐
│                   AssistantManager (C++ Qt)                       │
│  Orchestrateur central — machine à états — cycle de vie          │
├──────────┬──────────┬──────────┬──────────┬──────────┬──────────┤
│ Voice    │ TTS      │ Claude   │ Memory   │ Health   │ Config   │
│ Pipeline │ Manager  │ API      │ Manager  │ Check    │ Manager  │
└────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┴──────────┘
     │          │          │          │          │
     │ WS       │ WS       │ HTTPS    │ WS       │ WS (ping/pong)
     ▼          ▼          ▼          ▼          ▼
┌─────────┐┌─────────┐┌─────────┐┌─────────┐┌──────────┐┌─────────┐
│STT 8766 ││TTS 8767 ││Claude   ││Mem 8771 ││VAD 8768  ││NLU 8772│
│Whisper  ││XTTS v2  ││Anthropic││FAISS    ││Silero    ││Regex   │
│.cpp GPU ││GPU/CPU  ││SSE+FC   ││384-dim  ││          ││        │
└─────────┘└─────────┘└─────────┘└─────────┘└──────────┘└─────────┘
                                              ┌──────────┐
                                              │WW 8770   │
                                              │OpenWake  │
                                              └──────────┘
┌──────────────────────────────────────────────────────────────────┐
│              exo_server (port 8765) — Orchestrateur Python       │
│         GUI WebSocket + Home Assistant Bridge (REST/WS)          │
└──────────────────────────────────────────────────────────────────┘
```

## Couches architecturales

### 1. Interface utilisateur (QML)
- **Framework** : Qt Quick + QuickControls2
- **Thème** : VS Code dark
- **Layout** : Sidebar (260px) + StackLayout (chat/settings/history/logs/pipeline) + BottomBar
- **Exposition C++** : `setContextProperty()` depuis `AssistantManager::exposeToQml()`

### 2. Couche applicative (C++ Qt)
- **Orchestrateur** : `AssistantManager` — machine à états, cycle de vie composants
- **Audio** : `VoicePipeline` — capture → DSP → VAD → STT
- **TTS** : `TTSManager` — cascade XTTS v2 → Qt TTS, DSP 5 étages
- **LLM** : `ClaudeAPI` — SSE streaming, function calling, historique
- **Mémoire** : `AIMemoryManager` — conversations + préférences + sémantique FAISS
- **Événements** : `PipelineEventBus` — bus typé avec IDs de corrélation

### 3. Microservices Python (WebSocket)
Chaque serveur est un processus isolé, lancé via `tasks.json` VS Code.

| Service | Port | Technologie | Rôle |
|---------|------|-------------|------|
| exo_server | 8765 | asyncio+websockets | Gateway GUI + bridge HA |
| stt_server | 8766 | Whisper.cpp Vulkan | Reconnaissance vocale |
| tts_server | 8767 | XTTS v2 (GPU) | Synthèse vocale |
| vad_server | 8768 | Silero VAD | Détection d'activité vocale |
| wakeword_server | 8770 | OpenWakeWord | Détection mot de réveil |
| memory_server | 8771 | FAISS + SentenceTransformers | Mémoire sémantique |
| nlu_server | 8772 | Regex classifier | Classification d'intentions |

### 4. Intégrations externes
- **Anthropic Claude** : API REST avec SSE, function calling (13 outils HA)
- **Home Assistant** : REST + WebSocket, entités/devices/areas/actions
- **OpenWeatherMap** : Météo + conseils vestimentaires

## Patterns de conception

| Pattern | Implémentation | Fichiers |
|---------|----------------|----------|
| Machine à états | `PipelineState` FSM (6 états) | voicepipeline.h |
| Bus d'événements | `PipelineEventBus` (35+ types) | pipelineevent.h, pipelinetypes.h |
| Cascade/Fallback | TTS: XTTS → Qt → erreur | ttsmanager.h, TTSBackend.h |
| Config 3 couches | env > local > defaults | configmanager.h |
| Client WS réutilisable | Reconnexion auto + backoff | WebSocketClient.h |
| Health monitoring | Ping/pong périodique | healthcheck.h |
| Buffer circulaire | Ring buffer lock-free | circularaudiobuffer.h |
| Dispatcher JSON | `_on_json()` → switch type | Tous les serveurs Python |

## Communication inter-modules

Tous les échanges client-serveur utilisent **WebSocket** avec :
- **Contrôle** : JSON (`{"type": "...", ...}`)
- **Audio** : binaire brut (PCM16, little-endian)
- **Health** : ping/pong JSON (interval 10s, timeout 5s)

Exception : NLU utilise `{"action": "..."}` au lieu de `{"type": "..."}`.

## Fichiers de configuration

```
config/
├── assistant.conf          # Configuration principale (INI)
├── assistant_local.conf    # Surcharges utilisateur (non versionné)
├── assistant.conf.example  # Template
└── environment.example     # Variables d'environnement
```

Priorité de chargement : **Variables d'environnement > assistant_local.conf > assistant.conf**

---
*Retour à l'index : [docs/README.md](../README.md)*
