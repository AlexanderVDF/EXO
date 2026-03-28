> 🧭 [Index](../README.md) → [Guides](../README.md#-guides-techniques--guides) → tts.md

# TTS — Text-to-Speech (XTTS v2)
> Documentation EXO v4.2 — Section : Guides
> Dernière mise à jour : Mars 2026

---

<!-- TOC -->
## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture cascade](#architecture-cascade)
- [Protocole WebSocket](#protocole-websocket)
  - [Messages entrants (C++ → Python)](#messages-entrants-c-python)
  - [Messages sortants (Python → C++)](#messages-sortants-python-c)
- [Chaîne DSP sortie (5 étages)](#chaîne-dsp-sortie-5-étages)
- [Moteur XTTS v2](#moteur-xtts-v2)
  - [Configuration GPU](#configuration-gpu)
  - [Caractéristiques](#caractéristiques)
  - [Cache de phrases](#cache-de-phrases)
- [Configuration](#configuration)

<!-- /TOC -->

## Vue d'ensemble

Le module TTS convertit le texte en parole via **Coqui XTTS v2**, exécuté sur GPU (DirectML/CUDA) ou CPU fallback, avec
fallback Qt TextToSpeech.

- **Serveur principal** : `python/tts/tts_server.py` (port 8767)
- **Client C++** : `TTSBackendXTTS` dans `app/audio/TTSBackendXTTS.cpp`
- **Orchestrateur** : `TTSManager` dans `app/audio/ttsmanager.cpp`

## Architecture cascade

```
TTSManager (C++)
    │
    │ 1. Essayer XTTS v2 (WebSocket)
    ▼
┌──────────────────────────┐     ┌──────────────────────┐
│ TTSBackendXTTS           │────▶│ tts_server.py        │
│ WebSocket ws://...:8767  │     │ XTTS v2 GPU/CPU      │
│ Timeout: 12s             │     │ DirectML / CUDA      │
└──────────────────────────┘     └──────────────────────┘
    │
    │ 2. Échec → Fallback Qt
    ▼
┌──────────────────────────┐
│ TTSBackendQt             │
│ Qt TextToSpeech (local)  │
│ Voix système Windows     │
└──────────────────────────┘
    │
    │ 3. Échec → État erreur
    ▼
   Erreur signalée à l'UI
```

## Protocole WebSocket

### Messages entrants (C++ → Python)

| Type | Payload | Description |
|------|---------|-------------|
| `synthesize` | `{"type":"synthesize", "text":"...", "voice":"Claribel Dervla", "lang":"fr", "rate":1.0, "pitch":1.0, "style":"neutral"}` | Synthétiser du texte |
| `cancel` | `{"type":"cancel"}` | Annuler la synthèse en cours |
| `list_voices` | `{"type":"list_voices"}` | Lister les voix disponibles |
| `ping` | `{"type":"ping"}` | Health check |

### Messages sortants (Python → C++)

| Type | Payload | Description |
|------|---------|-------------|
| `ready` | `{"type":"ready", "voice":"...", "sample_rate":24000}` | Moteur prêt |
| `start` | `{"type":"start", "text":"...", "estimated_duration":float}` | Début synthèse |
| Binaire | PCM16 24kHz mono chunks | Données audio streamées |
| `end` | `{"type":"end", "duration":float}` | Fin de la synthèse |
| `voices` | `{"type":"voices", "available":[...]}` | Liste des voix |
| `pong` | `{"type":"pong"}` | Réponse health check |
| `error` | `{"type":"error", "message":"..."}` | Erreur |

## Chaîne DSP sortie (5 étages)

L'audio synthétisé passe par un traitement DSP avant la lecture :

```
PCM16 24kHz (XTTS)
    │
    ▼ Rééchantillonnage → 16kHz
    │
    ├─ 1. TTSEqualizer
    │     Fréquence: 3 kHz
    │     Gain: +3 dB (boost présence/clarté)
    │     Type: peak/bell
    │
    ├─ 2. TTSCompressor
    │     Seuil: -12 dBFS
    │     Ratio: 3:1
    │     Knee: soft
    │     → Réduit la dynamique pour écoute constante
    │
    ├─ 3. TTSNormalizer
    │     Cible: -16 dBFS
    │     → Uniformise le volume global
    │
    ├─ 4. Fade (enveloppe)
    │     Durée: 15-20 ms
    │     → Anti-click en début/fin de chunk
    │
    └─ 5. Anti-clip (peak limiter)
          → Empêche la saturation numérique
    │
    ▼
QAudioSink (16 kHz mono)
```

## Moteur XTTS v2

### Configuration GPU

Le serveur détecte automatiquement le GPU disponible :
- **CUDA** (NVIDIA RTX 3070) — accélération complète
- **DirectML** (AMD/Intel) — accélération partielle (vocodeur HiFi-GAN)
- **CPU** — fallback automatique

### Caractéristiques

| Propriété | Valeur |
|-----------|--------|
| Modèle | XTTS v2 (Coqui TTS) |
| Voix par défaut | Claribel Dervla |
| Langues | 17 (fr, en, de, es, it, pt, pl, tr, ru, nl, cs, ar, zh, ja, hu, ko, hi) |
| Sample rate natif | 24 kHz |
| Streaming | Oui (chunks PCM16) |
| Cache phrases | LRU (phrases courtes pré-synthétisées) |
| Voix disponibles | 58 |

### Cache de phrases

Le serveur TTS maintient un cache LRU pour les phrases courtes fréquentes :
- Clé : hash(texte + voix + langue + paramètres)
- Taille : configurable
- Bénéfice : réponse instantanée pour « oui », « d'accord », « bonjour »

## Configuration

```ini
[TTS]
server_url=ws://localhost:8767
backend=xtts
voice=Claribel Dervla
language=fr
pitch=1.0
rate=1.0
style=neutral
sample_rate=16000
```

Variables d'environnement :
- `EXO_XTTS_MODELS` : répertoire des modèles XTTS v2

---
*Retour à l'index : [docs/README.md](../README.md)*
