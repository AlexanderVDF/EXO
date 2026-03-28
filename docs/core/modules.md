> 🧭 [Index](../README.md) → [Architecture](../README.md#-architecture--spécifications--core) → modules.md
# Index des modules EXO
> Documentation EXO v4.2 — Section : Architecture
> Dernière mise à jour : Mars 2026

> Auto-généré par `auto_maintain.py` — 2026-03-22

---

<!-- TOC -->
## Table des matières

- [Modules Python](#modules-python)
- [Classes C++](#classes-c)

<!-- /TOC -->

## Modules Python

| Module | Dossier | Fichiers | Point d'entrée |
|--------|---------|----------|----------------|
| memory | `python/memory` | 2 | `python/memory/memory_server.py` |
| nlu | `python/nlu` | 2 | `python/nlu/nlu_server.py` |
| orchestrator | `python/orchestrator` | 8 | `python/orchestrator/exo_server.py` |
| shared | `python/shared` | 3 | `` |
| stt | `python/stt` | 3 | `python/stt/stt_server.py` |
| tts | `python/tts` | 4 | `python/tts/tts_gpu_server.py` |
| vad | `python/vad` | 2 | `python/vad/vad_server.py` |
| wakeword | `python/wakeword` | 2 | `python/wakeword/wakeword_server.py` |

## Classes C++

| Classe | Header | Module |
|--------|--------|--------|
| `AudioDeviceManager` | `app/audio/AudioDeviceManager.h` | audio |
| `AudioInput` | `app/audio/AudioInput.h` | audio |
| `AudioInputQt` | `app/audio/AudioInputQt.h` | audio |
| `AudioInputRtAudio` | `app/audio/AudioInputRtAudio.h` | audio |
| `TTSBackend` | `app/audio/TTSBackend.h` | audio |
| `TTSBackendQt` | `app/audio/TTSBackendQt.h` | audio |
| `TTSBackendXTTS` | `app/audio/TTSBackendXTTS.h` | audio |
| `TTSEqualizer` | `app/audio/TTSManager.h` | audio |
| `TTSCompressor` | `app/audio/TTSManager.h` | audio |
| `TTSNormalizer` | `app/audio/TTSManager.h` | audio |
| `TTSFade` | `app/audio/TTSManager.h` | audio |
| `TTSDSPProcessor` | `app/audio/TTSManager.h` | audio |
| `TTSWorker` | `app/audio/TTSManager.h` | audio |
| `TTSManager` | `app/audio/TTSManager.h` | audio |
| `CircularAudioBuffer` | `app/audio/VoicePipeline.h` | audio |
| `AudioPreprocessor` | `app/audio/VoicePipeline.h` | audio |
| `VADEngine` | `app/audio/VoicePipeline.h` | audio |
| `StreamingSTT` | `app/audio/VoicePipeline.h` | audio |
| `PipelineState` | `app/audio/VoicePipeline.h` | audio |
| `VoicePipeline` | `app/audio/VoicePipeline.h` | audio |
| `AssistantManager` | `app/core/AssistantManager.h` | core |
| `ConfigManager` | `app/core/ConfigManager.h` | core |
| `HealthCheck` | `app/core/HealthCheck.h` | core |
| `LogManager` | `app/core/LogManager.h` | core |
| `PipelineModule` | `app/core/PipelineEvent.h` | core |
| `ModuleState` | `app/core/PipelineEvent.h` | core |
| `PipelineEventBus` | `app/core/PipelineEvent.h` | core |
| `AnomalyType` | `app/core/PipelineTracer.h` | core |
| `PipelineTracer` | `app/core/PipelineTracer.h` | core |
| `EventType` | `app/core/PipelineTypes.h` | core |
| `ServiceManager` | `app/core/ServiceManager.h` | core |
| `WebSocketClient` | `app/core/WebSocketClient.h` | core |
| `AIMemoryManager` | `app/llm/AIMemoryManager.h` | llm |
| `ClaudeAPI` | `app/llm/ClaudeAPI.h` | llm |
| `WeatherManager` | `app/utils/WeatherManager.h` | utils |

---
*Retour à l'index : [docs/README.md](../README.md)*
