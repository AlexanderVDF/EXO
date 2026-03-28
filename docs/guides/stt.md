> 🧭 [Index](../README.md) → [Guides](../README.md#-guides-techniques--guides) → stt.md

# STT — Speech-to-Text (Whisper.cpp)
> Documentation EXO v4.2 — Section : Guides
> Dernière mise à jour : Mars 2026

---

<!-- TOC -->
## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Protocole WebSocket](#protocole-websocket)
  - [Messages entrants (C++ → Python)](#messages-entrants-c-python)
  - [Messages sortants (Python → C++)](#messages-sortants-python-c)
- [Backends](#backends)
  - [Whisper.cpp (Vulkan GPU) — Backend par défaut](#whispercpp-vulkan-gpu-backend-par-défaut)
  - [faster-whisper (CPU) — Fallback](#faster-whisper-cpu-fallback)
- [Filtre anti-hallucination](#filtre-anti-hallucination)
- [Configuration](#configuration)

<!-- /TOC -->

## Vue d'ensemble

Le module STT convertit la parole en texte via **Whisper.cpp** compilé avec le backend **Vulkan** pour accélération GPU.

- **Serveur** : `python/stt/stt_server.py` (port 8766)
- **Client C++** : `StreamingSTT` dans `app/audio/voicepipeline.h`
- **Engine GPU** : `python/stt/whisper_cpp.py` → appelle `whisper-server.exe` via HTTP

## Architecture

```
VoicePipeline (C++)                      stt_server.py (Python)
     │                                        │
     │ WS {"type":"start"}                    │
     │──────────────────────────────────────▶│
     │                                        │
     │ WS binaire (PCM16 16kHz)              │
     │──────────────────────────────────────▶│ → Accumulation
     │──────────────────────────────────────▶│   dans buffer
     │──────────────────────────────────────▶│
     │                                        │
     │ WS {"type":"end"}                      │
     │──────────────────────────────────────▶│
     │                                        │
     │                                        │──▶ whisper-server.exe
     │                                        │    (HTTP localhost:8769)
     │                                        │◀── JSON résultat
     │                                        │
     │ {"type":"partial","text":"bon"}        │
     │◀──────────────────────────────────────│
     │                                        │
     │ {"type":"final","text":"bonjour",      │
     │  "segments":[...], "duration":1.2}     │
     │◀──────────────────────────────────────│
```

## Protocole WebSocket

### Messages entrants (C++ → Python)

| Type | Payload | Description |
|------|---------|-------------|
| `start` | `{"type":"start"}` | Début d'un nouvel utterance |
| Binaire | PCM16 16kHz mono chunks | Données audio brutes |
| `end` | `{"type":"end"}` | Fin de l'utterance, lancer la transcription |
| `cancel` | `{"type":"cancel"}` | Annuler la transcription en cours |
| `config` | `{"type":"config", "model":"large-v3", "language":"fr", "beam_size":5}` | Reconfigurer le moteur |
| `ping` | `{"type":"ping"}` | Health check |

### Messages sortants (Python → C++)

| Type | Payload | Description |
|------|---------|-------------|
| `ready` | `{"type":"ready", "model":"...", "device":"..."}` | Moteur prêt |
| `partial` | `{"type":"partial", "text":"..."}` | Transcription partielle |
| `final` | `{"type":"final", "text":"...", "segments":[...], "duration":float}` | Transcription finale |
| `pong` | `{"type":"pong"}` | Réponse health check |
| `error` | `{"type":"error", "message":"..."}` | Erreur |

## Backends

### Whisper.cpp (Vulkan GPU) — Backend par défaut

- **Exécutable** : `D:\EXO\whispercpp\build_vk\bin\Release\whisper-server.exe`
- **Modèle** : `D:\EXO\models\whisper\ggml-large-v3.bin`
- **API interne** : HTTP POST vers `http://127.0.0.1:8769/inference`
- **GPU** : Vulkan (compatible AMD/NVIDIA/Intel)
- **Wrapper** : `python/stt/whisper_cpp.py` (classe `WhisperCppEngine`)

### faster-whisper (CPU) — Fallback

- **Bibliothèque** : `faster-whisper` (CTranslate2)
- **Usage** : quand Vulkan n'est pas disponible
- **Performance** : ~3x plus lent que GPU

## Filtre anti-hallucination

Le STT filtre automatiquement les faux positifs courants de Whisper :
- Textes de crédits/génériques (« Sous-titrage... », « Merci d'avoir regardé... »)
- Mots répétés en boucle
- Phrases trop courtes sans contenu sémantique

Implémentation : `_is_hallucination(text)` dans `stt_server.py`

## Configuration

```ini
[STT]
server_url=ws://localhost:8766
model=large-v3
language=fr
backend=whispercpp
beam_size=5
```

Variables d'environnement :
- `EXO_WHISPER_MODELS` : répertoire des modèles Whisper
- `EXO_WHISPERCPP_BIN` : répertoire de whisper-server.exe

---
*Retour à l'index : [docs/README.md](../README.md)*
