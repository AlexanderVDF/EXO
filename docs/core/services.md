> 🧭 [Index](../README.md) → [Architecture](../README.md#-architecture--spécifications--core) → services.md
# Services EXO
> Documentation EXO v4.2 — Section : Architecture
> Dernière mise à jour : Mars 2026

> Auto-généré par `auto_maintain.py` — 2026-03-22

---

<!-- TOC -->
## Table des matières

- [Microservices](#microservices)
- [Tests disponibles](#tests-disponibles)
  - [cpp/ (7 fichier(s))](#cpp-7-fichiers)
  - [integration/ (1 fichier(s))](#integration-1-fichiers)
  - [performance/ (1 fichier(s))](#performance-1-fichiers)
  - [python/ (12 fichier(s))](#python-12-fichiers)

<!-- /TOC -->

## Microservices

| Service | Port | Langage | Protocole | Dossier |
|---------|------|---------|-----------|---------|
| exo_server | 8765 | Python | WebSocket | `python/orchestrator` |
| stt_server | 8766 | Python | WebSocket | `python/stt` |
| tts_server | 8767 | Python | WebSocket | `python/tts` |
| vad_server | 8768 | Python | WebSocket | `python/vad` |
| wakeword_server | 8770 | Python | WebSocket | `python/wakeword` |
| memory_server | 8771 | Python | WebSocket | `python/memory` |
| nlu_server | 8772 | Python | WebSocket | `python/nlu` |

## Tests disponibles

### cpp/ (7 fichier(s))

- `tests/cpp/test_audiopreprocessor.cpp`
- `tests/cpp/test_circularaudiobuffer.cpp`
- `tests/cpp/test_configmanager.cpp`
- `tests/cpp/test_healthcheck.cpp`
- `tests/cpp/test_pipelineevent.cpp`
- `tests/cpp/test_pipelinetracer.cpp`
- `tests/cpp/test_tts_dsp.cpp`

### integration/ (1 fichier(s))

- `tests/integration/test_pipeline_integration.py`

### performance/ (1 fichier(s))

- `tests/performance/test_performance.py`

### python/ (12 fichier(s))

- `tests/python/test_actions.py`
- `tests/python/test_areas.py`
- `tests/python/test_devices.py`
- `tests/python/test_entities.py`
- `tests/python/test_healthcheck_protocol.py`
- `tests/python/test_home_bridge.py`
- `tests/python/test_memory_server.py`
- `tests/python/test_nlu_server.py`
- `tests/python/test_stt_server.py`
- `tests/python/test_sync.py`
- `tests/python/test_tts_server.py`
- `tests/python/test_vad_server.py`

**Total : 21 fichier(s) de test**

---
*Retour à l'index : [docs/README.md](../README.md)*
