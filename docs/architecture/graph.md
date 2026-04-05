# Graphe de dépendances C++

> Auto-généré par `auto_maintain.py` — 2026-04-05

## Matrice d'inclusion

```
  AudioDeviceManager.cpp -> AudioDeviceManager.h
  AudioInputQt.cpp -> AudioInputQt.h
  AudioInputQt.h -> AudioInput.h
  AudioInputRtAudio.cpp -> AudioInputRtAudio.h
  AudioInputRtAudio.h -> AudioInput.h
  TTSBackendQt.cpp -> TTSBackendQt.h
  TTSBackendQt.cpp -> TTSManager.h
  TTSBackendQt.h -> TTSBackend.h
  TTSBackendXTTS.cpp -> TTSBackendXTTS.h
  TTSBackendXTTS.cpp -> TTSManager.h
  TTSBackendXTTS.h -> TTSBackend.h
  TTSManager.cpp -> TTSManager.h
  TTSManager.cpp -> TTSBackend.h
  TTSManager.cpp -> TTSBackendQt.h
  TTSManager.cpp -> TTSBackendXTTS.h
  TTSManager.cpp -> LogManager.h
  TTSManager.cpp -> PipelineEvent.h
  TTSManager.cpp -> LatencyMetrics.h
  VoicePipeline.cpp -> VoicePipeline.h
  VoicePipeline.cpp -> LogManager.h
  VoicePipeline.cpp -> LatencyMetrics.h
  VoicePipeline.h -> AudioInput.h
  VoicePipeline.h -> AudioInputQt.h
  VoicePipeline.h -> AudioInputRtAudio.h
  VoicePipeline.h -> AudioDeviceManager.h
  VoicePipeline.h -> TTSManager.h
  VoicePipeline.h -> WebSocketClient.h
  VoicePipeline.h -> PipelineEvent.h
  AssistantManager.cpp -> AssistantManager.h
  AssistantManager.cpp -> AIMemoryManager.h
  AssistantManager.cpp -> ConfigManager.h
  AssistantManager.cpp -> LogManager.h
  AssistantManager.cpp -> HealthCheck.h
  AssistantManager.cpp -> ClaudeAPI.h
  AssistantManager.cpp -> VoicePipeline.h
  AssistantManager.cpp -> AudioDeviceManager.h
  AssistantManager.cpp -> WeatherManager.h
  AssistantManager.cpp -> PipelineEvent.h
  AssistantManager.cpp -> PipelineTracer.h
  AssistantManager.cpp -> ContextCache.h
  AssistantManager.cpp -> LatencyMetrics.h
  AssistantManager.h -> ConfigManager.h
  AssistantManager.h -> HealthCheck.h
  ConfigManager.cpp -> ConfigManager.h
  ConfigManager.cpp -> LogManager.h
  ContextCache.cpp -> ContextCache.h
  ContextCache.cpp -> LogManager.h
  HealthCheck.cpp -> HealthCheck.h
  HealthCheck.cpp -> ConfigManager.h
  HealthCheck.h -> WebSocketClient.h
  LatencyMetrics.cpp -> LatencyMetrics.h
  LatencyMetrics.cpp -> LogManager.h
  LogManager.cpp -> LogManager.h
  PipelineEvent.cpp -> PipelineEvent.h
  PipelineEvent.cpp -> LogManager.h
  PipelineEvent.h -> PipelineTypes.h
  PipelineTracer.cpp -> PipelineTracer.h
  PipelineTracer.cpp -> LogManager.h
  PipelineTracer.h -> PipelineEvent.h
  ServiceManager.cpp -> ServiceManager.h
  ServiceManager.h -> WebSocketClient.h
  ServiceRegistry.cpp -> ServiceRegistry.h
  ServiceRegistry.cpp -> LogManager.h
  ServiceRegistry.h -> ServiceState.h
  ServiceRegistry.h -> ServiceDescriptor.h
  ServiceSupervisor.cpp -> ServiceSupervisor.h
  ServiceSupervisor.cpp -> LogManager.h
  ServiceSupervisor.h -> ServiceRegistry.h
  ServiceSupervisor.h -> ServiceDescriptor.h
  ServiceSupervisor.h -> WebSocketClient.h
  WebSocketClient.cpp -> WebSocketClient.h
  WebSocketClient.cpp -> LogManager.h
  AIMemoryManager.cpp -> AIMemoryManager.h
  AIMemoryManager.cpp -> LogManager.h
  AIMemoryManager.h -> WebSocketClient.h
  ClaudeAPI.cpp -> ClaudeAPI.h
  ClaudeAPI.cpp -> LogManager.h
  ClaudeAPI.cpp -> PipelineEvent.h
  ClaudeAPI.cpp -> LatencyMetrics.h
  main.cpp -> AssistantManager.h
  main.cpp -> LogManager.h
  main.cpp -> ServiceSupervisor.h
  WeatherManager.cpp -> WeatherManager.h
```

## Fichiers par module

### audio/

- `app/audio/AudioDeviceManager.cpp` (1 include(s))
- `app/audio/AudioDeviceManager.h` (0 include(s))
- `app/audio/AudioInput.h` (0 include(s))
- `app/audio/AudioInputQt.cpp` (1 include(s))
- `app/audio/AudioInputQt.h` (1 include(s))
- `app/audio/AudioInputRtAudio.cpp` (1 include(s))
- `app/audio/AudioInputRtAudio.h` (1 include(s))
- `app/audio/TTSBackend.h` (0 include(s))
- `app/audio/TTSBackendQt.cpp` (2 include(s))
- `app/audio/TTSBackendQt.h` (1 include(s))
- `app/audio/TTSBackendXTTS.cpp` (2 include(s))
- `app/audio/TTSBackendXTTS.h` (1 include(s))
- `app/audio/TTSManager.cpp` (7 include(s))
- `app/audio/TTSManager.h` (0 include(s))
- `app/audio/VoicePipeline.cpp` (3 include(s))
- `app/audio/VoicePipeline.h` (7 include(s))

### core/

- `app/core/AssistantManager.cpp` (13 include(s))
- `app/core/AssistantManager.h` (2 include(s))
- `app/core/ConfigManager.cpp` (2 include(s))
- `app/core/ConfigManager.h` (0 include(s))
- `app/core/ContextCache.cpp` (2 include(s))
- `app/core/ContextCache.h` (0 include(s))
- `app/core/HealthCheck.cpp` (2 include(s))
- `app/core/HealthCheck.h` (1 include(s))
- `app/core/LatencyMetrics.cpp` (2 include(s))
- `app/core/LatencyMetrics.h` (0 include(s))
- `app/core/LogManager.cpp` (1 include(s))
- `app/core/LogManager.h` (0 include(s))
- `app/core/PipelineEvent.cpp` (2 include(s))
- `app/core/PipelineEvent.h` (1 include(s))
- `app/core/PipelineTracer.cpp` (2 include(s))
- `app/core/PipelineTracer.h` (1 include(s))
- `app/core/PipelineTypes.h` (0 include(s))
- `app/core/ServiceDescriptor.h` (0 include(s))
- `app/core/ServiceManager.cpp` (1 include(s))
- `app/core/ServiceManager.h` (1 include(s))
- `app/core/ServiceRegistry.cpp` (2 include(s))
- `app/core/ServiceRegistry.h` (2 include(s))
- `app/core/ServiceState.h` (0 include(s))
- `app/core/ServiceSupervisor.cpp` (2 include(s))
- `app/core/ServiceSupervisor.h` (3 include(s))
- `app/core/WebSocketClient.cpp` (2 include(s))
- `app/core/WebSocketClient.h` (0 include(s))

### llm/

- `app/llm/AIMemoryManager.cpp` (2 include(s))
- `app/llm/AIMemoryManager.h` (1 include(s))
- `app/llm/ClaudeAPI.cpp` (4 include(s))
- `app/llm/ClaudeAPI.h` (0 include(s))

### root/

- `app/main.cpp` (3 include(s))

### utils/

- `app/utils/WeatherManager.cpp` (1 include(s))
- `app/utils/WeatherManager.h` (0 include(s))
