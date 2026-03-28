# TTSManager

> Orchestrateur TTS avec queue, prosodie, DSP et playback streaming

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Propriétés QML](#propriétés-qml)
- [Méthodes publiques](#méthodes-publiques)
  - [Cycle de vie](#cycle-de-vie)
  - [API principale](#api-principale)
  - [Réglages](#réglages)
- [Signaux](#signaux)
- [Classes auxiliaires DSP](#classes-auxiliaires-dsp)
  - [TTSEqualizer](#ttsequalizer)
  - [TTSCompressor](#ttscompressor)
  - [TTSNormalizer](#ttsnormalizer)
  - [TTSFade](#ttsfade)
  - [TTSDSPProcessor](#ttsdspprocessor)
- [Backends TTS](#backends-tts)
  - [TTSBackend (interface abstraite)](#ttsbackend-interface-abstraite)
  - [TTSBackendXTTS](#ttsbackendxtts)
  - [TTSBackendQt](#ttsbackendqt)
- [Architecture thread](#architecture-thread)
- [Constantes](#constantes)

<!-- /TOC -->

**Fichier** : `app/audio/TTSManager.h` / `.cpp`
**Module** : Audio
**Hérite de** : `QObject`

---

## Description

`TTSManager` gère l'intégralité du pipeline de synthèse vocale : analyse prosodique, file d'attente, dispatch vers le
worker thread (XTTS v2 ou Qt TTS fallback), post-traitement DSP, et playback streaming via `QAudioSink` à 24 kHz. Il
expose une API QML complète et peut broadcaster l'état et les formes d'onde vers une GUI React via WebSocket.

---

## Propriétés QML

| Propriété | Type | Description |
|---|---|---|
| `isSpeaking` | `bool` | `true` pendant la synthèse/lecture audio |

---

## Méthodes publiques

### Cycle de vie

| Méthode | Description |
|---|---|
| `initTTS(pythonWsUrl)` | Initialiser le worker thread et les backends |
| `initDSP()` | Configurer la chaîne DSP (EQ, compresseur, normalisation) |

### API principale

| Méthode | Description |
|---|---|
| `speakText(text)` | Annuler la parole en cours et synthétiser immédiatement |
| `enqueueSentence(text)` | Ajouter une phrase à la file d'attente (cascade) |
| `cancelSpeech()` | Annuler toute synthèse en cours et vider la queue |

### Réglages

| Méthode | Description |
|---|---|
| `setVoice(name)` | Changer la voix (ex : "Claribel Dervla") |
| `setRate(r)` | Vitesse de parole (-1.0 à +1.0) |
| `setPitch(p)` | Hauteur de voix (-1.0 à +1.0) |
| `setEnergy(e)` | Énergie/volume (0.0 à 1.0) |
| `setStyle(s)` | Style prosodique ("neutral", "question", "exclamation") |
| `setLanguage(lang)` | Langue de synthèse (défaut : "fr") |
| `setDSPEnabled(on)` | Activer/désactiver le post-traitement DSP |
| `setCascadeEnabled(on)` | Activer/désactiver l'enchaînement automatique des phrases |
| `setPythonUrl(url)` | URL du serveur TTS Python |

Toutes ces méthodes sont `Q_INVOKABLE` (appelables depuis QML).

---

## Signaux

| Signal | Description |
|---|---|
| `ttsStarted()` | Début de synthèse d'une phrase |
| `ttsChunk(pcm)` | Chunk PCM16 reçu du worker |
| `ttsFinished()` | Fin de synthèse de la dernière phrase |
| `speakingChanged()` | Changement de l'état `isSpeaking` |
| `ttsError(msg)` | Erreur de synthèse |
| `statusChanged(status)` | Changement de statut interne |

---

## Classes auxiliaires DSP

### TTSEqualizer

EQ de présence (bande 3 kHz, +3 dB, Q=1.0).

### TTSCompressor

Compresseur soft-knee descendant (seuil -18 dB, ratio 2:1, attack 5 ms, release 50 ms).

### TTSNormalizer

Normalisation peak/RMS (cible : -14 dBFS).

### TTSFade

Fade-in (5 ms) / fade-out (10 ms) anti-click.

### TTSDSPProcessor

Chaîne DSP modulaire : **EQ → Compresseur → Normalisation → Fade**

| Méthode | Description |
|---|---|
| `configure(sampleRate)` | Initialiser la chaîne pour le taux donné |
| `process(pcm, count, isFinalChunk)` | Traiter un buffer PCM16 in-place |
| `setEnabled(on)` | Activer/désactiver globalement |
| `setEQGainDb(db)` | Gain EQ en dB |
| `setCompressorThreshold(db)` | Seuil du compresseur en dB |
| `setNormTarget(dBFS)` | Cible de normalisation en dBFS |

---

## Backends TTS

### TTSBackend (interface abstraite)

| Méthode | Description |
|---|---|
| `name()` | Nom du backend ("XTTS", "QtTTS") |
| `isAvailable()` | Le backend est-il disponible ? |
| `synthesize(req)` | Synthétiser une requête (bloquant) |
| `cancel()` | Annuler la synthèse en cours |

### TTSBackendXTTS

Backend principal via WebSocket vers `tts_server.py`. Protocole JSON + binaire PCM16.

### TTSBackendQt

Backend fallback via Qt TextToSpeech (Windows SAPI). Utilisé quand XTTS est indisponible.

---

## Architecture thread

```
Main thread (TTSManager)
  │  ← speakText() / enqueueSentence()
  │  → analyseProsody() → queue
  │  → signal _doRequest(TTSRequest)
  │
  ▼
Worker thread (TTSWorker)
  │  → TTSBackendXTTS.synthesize() [priorité 1]
  │  → TTSBackendQt.synthesize()   [fallback]
  │
  │  ← chunk(pcm) signals
  ▼
Main thread
  │  → TTSDSPProcessor.process()
  │  → QAudioSink playback (24kHz mono 16-bit)
  │  → broadcastWaveform() → React GUI
```

---

## Constantes

| Constante | Valeur | Description |
|---|---|---|
| `SAMPLE_RATE` | 24000 | Taux natif XTTS v2 |
| `CHANNELS` | 1 | Mono |
| `BITS_PER_SAMPLE` | 16 | PCM 16 bits |

---
Retour à l'index : [docs/README.md](../README.md)
