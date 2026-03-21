# Diagramme des modules C++

```
AssistantManager (QObject)
│
├── ConfigManager          ← config/assistant.conf (INI 3 couches)
├── LogManager             ← logging catégorisé, rotation fichiers
├── PipelineEventBus       ← bus d'événements typés (35+ EventType)
│   └── PipelineTracer     ← assemblage timeline, détection anomalies
├── HealthCheck            ← monitoring 6 services (ping/pong WebSocket)
│
├── VoicePipeline          ← pipeline audio complet
│   ├── AudioInput (interface)
│   │   ├── AudioInputQt       ← QAudioSource (Qt Multimedia)
│   │   └── AudioInputRtAudio  ← RtAudio/WASAPI (optionnel)
│   ├── CircularAudioBuffer    ← ring buffer 32s @ 16kHz
│   ├── AudioPreprocessor      ← DSP entrée (HP 150Hz, gate, AGC, norm)
│   ├── VADEngine              ← Silero VAD via WebSocket (port 8768)
│   ├── StreamingSTT           ← Whisper.cpp via WebSocket (port 8766)
│   └── WakeWordEngine         ← OpenWakeWord via WebSocket (port 8770)
│
├── TTSManager             ← orchestrateur TTS + DSP sortie
│   ├── TTSBackend (interface abstraite)
│   │   ├── TTSBackendXTTS     ← XTTS v2 via WebSocket (port 8767)
│   │   └── TTSBackendQt       ← Qt TextToSpeech (fallback local)
│   ├── TTSEqualizer           ← EQ présence 3kHz
│   ├── TTSCompressor          ← compresseur dynamique
│   └── TTSNormalizer          ← normalisation -16 dBFS
│
├── ClaudeAPI              ← client Anthropic (SSE + function calling)
├── AIMemoryManager        ← mémoire multi-couches (conversations, FAISS)
└── WeatherManager         ← OpenWeatherMap + conseils vestimentaires
```

## Ownership mémoire

Tous les objets sont créés avec `AssistantManager` comme parent Qt.
La destruction en cascade est gérée par le système de parenté `QObject`.
Pas de `std::unique_ptr` / `std::shared_ptr` isolés.

## Exposition QML

`AssistantManager::exposeToQml()` utilise `setContextProperty()` :
- `assistantManager` → AssistantManager*
- `voiceManager` → VoicePipeline*
- `ttsManager` → TTSManager*
- `claudeAPI` → ClaudeAPI*
- `configManager` → ConfigManager*
- `logManager` → LogManager*
- `pipelineEventBus` → PipelineEventBus*
- `healthCheck` → HealthCheck*
- `weatherManager` → WeatherManager*
- `memoryManager` → AIMemoryManager*
