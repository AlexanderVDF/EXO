# 📚 API Reference — EXO v4.2

> Documentation de toutes les classes C++ et microservices Python

---

<!-- TOC -->
## Table des matières

- [C++ — Core](#c-core)
- [C++ — Pipeline vocal](#c-pipeline-vocal)
- [C++ — LLM](#c-llm)
- [C++ — Observabilité](#c-observabilité)
- [C++ — Utilitaires](#c-utilitaires)
- [Python — Microservices](#python-microservices)
- [Architecture des communications](#architecture-des-communications)

<!-- /TOC -->

## C++ — Core

| Classe | Description |
|---|---|
| [AssistantManager](AssistantManager.md) | Coordinateur principal, point d'entrée QML |
| [ConfigManager](ConfigManager.md) | Configuration 3 couches (.env > user > defaults) |
| [HealthCheck](HealthCheck.md) | Surveillance santé des microservices |
| [ServiceManager](ServiceManager.md) | Lancement et supervision des services Python |
| [LogManager](LogManager.md) | Logging centralisé + événements pipeline |
| [WebSocketClient](WebSocketClient.md) | Client WebSocket réutilisable avec auto-reconnexion |

## C++ — Pipeline vocal

| Classe | Description |
|---|---|
| [VoicePipeline](VoicePipeline.md) | Capture → Prétraitement → VAD → STT streaming |
| [AudioInput](AudioInput.md) | Backends audio (Qt Multimedia, RtAudio/WASAPI) + AudioDeviceManager |
| [TTSManager](TTSManager.md) | Synthèse vocale avec chaîne DSP (EQ → Compresseur → Normalisation → Fade) |

## C++ — LLM

| Classe | Description |
|---|---|
| [ClaudeAPI](ClaudeAPI.md) | Client Anthropic Messages API v1, SSE streaming, function calling |
| [AIMemoryManager](AIMemoryManager.md) | Mémoire 3 couches (conversations, préférences, souvenirs) + bridge FAISS |

## C++ — Observabilité

| Classe | Description |
|---|---|
| [PipelineEvent](PipelineEvent.md) | Bus d'événements (12 modules, 35+ types, corrélation UUID) |
| [PipelineTracer](PipelineTracer.md) | Analyse post-interaction, détection d'anomalies (8 types) |

## C++ — Utilitaires

| Classe | Description |
|---|---|
| [WeatherManager](WeatherManager.md) | Météo OpenWeatherMap + conseils vestimentaires |

---

## Python — Microservices

| Service | Port | Description |
|---|---|---|
| [stt_server](stt_server.md) | 8766 | STT streaming (whisper.cpp GPU / faster-whisper CPU) |
| [tts_server](tts_server.md) | 8767 | TTS streaming XTTS v2 (DirectML/CUDA/CPU) |
| [vad_server](vad_server.md) | 8768 | Détection d'activité vocale (Silero VAD) |
| [wakeword_server](wakeword_server.md) | 8770 | Détection mot de réveil (OpenWakeWord) |
| [memory_server](memory_server.md) | 8771 | Mémoire sémantique (FAISS + SentenceTransformers) |
| [nlu_server](nlu_server.md) | 8772 | Classification d'intentions (regex + transformer) |
| [exo_server](exo_server.md) | 8765 | Orchestrateur GUI WebSocket + Bridge Home Assistant |

---

## Architecture des communications

```
┌─────────────┐     WebSocket      ┌──────────────┐
│  Qt/QML GUI │◄──────────────────►│  exo_server  │ :8765
└──────┬──────┘                    └──────────────┘
       │
       │  C++ in-process
       ▼
┌──────────────┐    WS :8766    ┌──────────────┐
│ VoicePipeline│───────────────►│  stt_server  │
│              │    WS :8768    ├──────────────┤
│              │───────────────►│  vad_server  │
│              │    WS :8770    ├──────────────┤
│              │───────────────►│wakeword_server│
└──────────────┘                └──────────────┘

┌──────────────┐    WS :8767    ┌──────────────┐
│  TTSManager  │───────────────►│  tts_server  │
└──────────────┘                └──────────────┘

┌──────────────┐    WS :8771    ┌──────────────┐
│AIMemoryManager│──────────────►│memory_server │
└──────────────┘                └──────────────┘

┌──────────────┐    WS :8772    ┌──────────────┐
│AssistantManager│─────────────►│  nlu_server  │
└──────────────┘                └──────────────┘
```
