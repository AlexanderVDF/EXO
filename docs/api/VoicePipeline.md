# VoicePipeline

> Pipeline audio complet : capture → prétraitement → VAD → STT → TTS

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Classes auxiliaires](#classes-auxiliaires)
  - [CircularAudioBuffer](#circularaudiobuffer)
  - [AudioPreprocessor](#audiopreprocessor)
  - [VADEngine](#vadengine)
  - [StreamingSTT](#streamingstt)
- [Architecture du pipeline](#architecture-du-pipeline)

<!-- /TOC -->

**Fichier** : `app/audio/VoicePipeline.h` / `.cpp`
**Module** : Audio
**Hérite de** : `QObject`

---

## Description

`VoicePipeline` est le cœur du traitement audio temps réel d'EXO. Il orchestre la chaîne complète : capture microphone
(Qt ou RtAudio), prétraitement DSP, détection d'activité vocale (VAD builtin/Silero/hybride), transcription streaming
(STT via WebSocket), et détection de wake word. Le pipeline fonctionne en continu et émet des événements structurés via
`PipelineEventBus`.

---

## Classes auxiliaires

### CircularAudioBuffer

Buffer circulaire pour les échantillons PCM16.

| Méthode | Description |
|---|---|
| `write(data, count)` | Écrire des échantillons dans le buffer |
| `read(dest, count)` | Lire et consommer des échantillons |
| `peek(dest, count)` | Lire sans consommer |
| `available()` | Nombre d'échantillons disponibles |
| `clear()` | Vider le buffer |
| `capacity()` | Capacité totale (défaut : 16000 × 30 = 30s) |

### AudioPreprocessor

Chaîne DSP appliquée aux chunks audio bruts.

| Méthode | Description |
|---|---|
| `process(samples, count)` | Appliquer la chaîne DSP complète |
| `setHighPassCutoff(hz)` | Filtre passe-haut Butterworth 2nd ordre (défaut : 150 Hz) |
| `setNoiseGateThreshold(rms)` | Seuil du noise gate (défaut : 0.001) |
| `setAGCEnabled(on)` | Activer/désactiver le contrôle automatique de gain |
| `setNormalizationTarget(rms)` | Cible de normalisation RMS (0 = désactivé) |
| `setSampleRate(sr)` | Définir le taux d'échantillonnage |

**Pipeline DSP** : Filtre passe-haut → Noise gate → AGC → Normalisation RMS

### VADEngine

Détection d'activité vocale avec 3 backends.

| Backend | Description |
|---|---|
| `Builtin` | Heuristique énergie + ZCR (toujours disponible) |
| `SileroONNX` | Silero VAD via WebSocket → `vad_server.py` |
| `Hybrid` | Combinaison Builtin + Silero |

| Méthode | Description |
|---|---|
| `initialize(backend, sileroUrl)` | Initialiser avec le backend choisi |
| `processChunk(samples, count)` | Traiter un chunk, retourner le score VAD |
| `isSpeech()` | État actuel : parole détectée ? |
| `setThreshold(t)` | Seuil de détection (défaut : 0.45) |
| `resetNoiseEstimate()` | Réinitialiser l'estimation du bruit ambiant |

**Signaux** : `speechStarted()`, `speechEnded()`

**Paramètres internes** :
- Fenêtre de calibration : 30 frames (~600 ms)
- Hang frames : 30 frames (~600 ms après fin de parole)
- Start frames : 2 frames consécutives requises

### StreamingSTT

Client WebSocket vers `stt_server.py` pour la transcription streaming.

**Protocole** :

| Direction | Type | Format |
|---|---|---|
| → serveur | JSON | `{"type": "start"}` — début d'utterance |
| → serveur | Binaire | Chunks PCM16 en temps réel |
| → serveur | JSON | `{"type": "end"}` — finaliser l'utterance |
| ← client | JSON | `{"type": "partial", "text": "..."}` |
| ← client | JSON | `{"type": "final", "text": "...", "segments": [...]}` |

| Méthode | Description |
|---|---|
| `initialize(serverUrl)` | Se connecter au serveur STT (défaut : `ws://localhost:8766`) |
| `startUtterance()` | Signaler le début d'une utterance |
| `feedAudio(samples, count)` | Envoyer un chunk audio en streaming |
| `endUtterance()` | Finaliser et obtenir la transcription |
| `cancelUtterance()` | Annuler l'utterance en cours |
| `transcribeBuffer(pcm)` | Transcrire un buffer complet (fallback non-streaming) |
| `setLanguage(lang)` | Langue de transcription |
| `setBeamSize(beam)` | Taille du beam search |

**Signaux** : `partialTranscript(text)`, `finalTranscript(text)`, `error(msg)`, `connected()`, `disconnected()`

---

## Architecture du pipeline

```
Microphone (AudioInputQt / AudioInputRtAudio)
  │
  ▼
AudioPreprocessor (HP filter → noise gate → AGC → norm)
  │
  ▼
CircularAudioBuffer (ring buffer 30s)
  │
  ├──▶ VADEngine (speech detection)
  │       │
  │       ├── speechStarted → StreamingSTT.startUtterance()
  │       └── speechEnded   → StreamingSTT.endUtterance()
  │
  └──▶ StreamingSTT (WebSocket → stt_server.py)
          │
          ├── partialTranscript → QML
          └── finalTranscript → AssistantManager.sendMessage()
```

---
Retour à l'index : [docs/README.md](../README.md)
