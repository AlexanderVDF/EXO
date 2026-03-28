# vad_server — Voice Activity Detection Server

> Détection d'activité vocale via Silero VAD

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Protocole WebSocket](#protocole-websocket)
  - [Messages entrants (Client → Serveur)](#messages-entrants-client-serveur)
  - [Messages sortants (Serveur → Client)](#messages-sortants-serveur-client)
- [Paramètres d'hystérésis](#paramètres-dhystérésis)
- [Caractéristiques Audio](#caractéristiques-audio)
- [Dépendances](#dépendances)

<!-- /TOC -->

**Fichier** : `python/vad/vad_server.py`
**Port** : `8768`
**Protocole** : WebSocket (binaire + JSON)

---

## Description

Serveur VAD utilisant le modèle Silero VAD pour détecter la présence de parole dans un flux audio. Renvoie un score de
probabilité pour chaque chunk audio reçu, avec hystérésis configurable pour éviter les faux positifs.

---

## Protocole WebSocket

### Messages entrants (Client → Serveur)

**Audio (binaire) :**
```
[PCM16 mono 16kHz, 512 samples/chunk]
```

**Configuration :**
```json
{
  "type": "config",
  "threshold": 0.5,
  "speech_start_frames": 2,
  "speech_hang_frames": 15
}
```

**Réinitialiser :**
```json
{ "type": "reset" }
```

**Ping :**
```json
{ "type": "ping" }
```

### Messages sortants (Serveur → Client)

**Prêt :**
```json
{ "type": "ready" }
```

**Résultat VAD :**
```json
{
  "type": "vad",
  "score": 0.87,
  "is_speech": true
}
```

**Pong :**
```json
{ "type": "pong" }
```

---

## Paramètres d'hystérésis

| Paramètre | Défaut | Description |
|---|---|---|
| `speech_start_frames` | 2 | Frames consécutifs > seuil pour déclarer parole |
| `speech_hang_frames` | 15 | Frames de maintien après fin de parole (~480 ms) |

---

## Caractéristiques Audio

| Paramètre | Valeur |
|---|---|
| Sample rate | 16 000 Hz |
| Taille de chunk | 512 samples (32 ms) |
| Format | PCM16 mono little-endian |

---

## Dépendances

| Package | Usage |
|---|---|
| `websockets` | Serveur WebSocket |
| `torch` | Modèle Silero VAD |
| `numpy` | Manipulation audio |

---
Retour à l'index : [docs/README.md](../README.md)
