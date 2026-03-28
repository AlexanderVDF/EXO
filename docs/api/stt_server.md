# stt_server — Speech-to-Text Streaming Server

> Transcription audio temps-réel avec double backend

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Paramètres Cli](#paramètres-cli)
- [Modèles disponibles](#modèles-disponibles)
- [Protocole WebSocket](#protocole-websocket)
  - [Données audio (binaire)](#données-audio-binaire)
  - [Commandes JSON](#commandes-json)
  - [Messages sortants (Serveur → Client)](#messages-sortants-serveur-client)
- [Fonctionnalités avancées](#fonctionnalités-avancées)
  - [Réduction de bruit](#réduction-de-bruit)
  - [Filtre d'hallucinations](#filtre-dhallucinations)
- [Dépendances](#dépendances)

<!-- /TOC -->

**Fichier** : `python/stt/stt_server.py`
**Port** : `8766`
**Protocole** : WebSocket (binaire + JSON)

---

## Description

Serveur de transcription streaming avec deux backends interchangeables :

| Backend | Accélération | Modèles | Usage |
|---|---|---|---|
| **whisper.cpp** (défaut) | Vulkan GPU | GGML (`.bin`) | Principal, haute performance |
| **faster-whisper** | CPU (CTranslate2) | CTranslate2 | Fallback |

## Paramètres Cli

| Argument | Défaut | Description |
|---|---|---|
| `--host` | `0.0.0.0` | Adresse d'écoute |
| `--port` | `8766` | Port WebSocket |
| `--backend` | `whispercpp` | Backend (`whispercpp` \| `faster_whisper`) |
| `--model` | `medium` | Taille de modèle |
| `--beam-size` | `3` | Taille du beam search |
| `--device` | `gpu` | Appareil (`gpu` \| `cpu`) |
| `--lang` | `fr` | Langue de transcription |

## Modèles disponibles

| Taille | Fichier GGML |
|---|---|
| `tiny` | `ggml-tiny.bin` |
| `base` | `ggml-base.bin` |
| `small` | `ggml-small.bin` |
| `medium` | `ggml-medium.bin` |
| `large` | `ggml-large-v3.bin` |
| `large-v3` | `ggml-large-v3.bin` |

Répertoire des modèles : `$EXO_WHISPER_MODELS` (défaut : `D:\EXO\models\whisper`)

---

## Protocole WebSocket

### Données audio (binaire)

```
[PCM16 mono 16kHz, little-endian]
```

Envoi de chunks audio bruts en binaire.

### Commandes JSON

**Démarrer la transcription :**
```json
{ "type": "start" }
```

**Arrêter la transcription :**
```json
{ "type": "end" }
```

**Configurer :**
```json
{
  "type": "config",
  "language": "fr",
  "beam_size": 3,
  "model": "medium"
}
```

**Annuler :**
```json
{ "type": "cancel" }
```

### Messages sortants (Serveur → Client)

**Prêt :**
```json
{
  "type": "ready",
  "backend": "whispercpp",
  "model": "medium",
  "device": "gpu"
}
```

**Transcription partielle :**
```json
{
  "type": "partial",
  "text": "Bonjour je voudr"
}
```

**Transcription finale :**
```json
{
  "type": "final",
  "text": "Bonjour, je voudrais connaître la météo.",
  "language": "fr",
  "duration": 2.45
}
```

**Erreur :**
```json
{
  "type": "error",
  "message": "Model not found"
}
```

---

## Fonctionnalités avancées

### Réduction de bruit

Utilise la bibliothèque `noisereduce` pour filtrer le bruit ambiant avant transcription.

### Filtre d'hallucinations

30+ patterns regex détectent les hallucinations typiques de Whisper (phrases répétées, textes génériques, artefacts de
sous-titrage) et les filtrent automatiquement du résultat final.

---

## Dépendances

| Package | Usage |
|---|---|
| `websockets` | Serveur WebSocket |
| `numpy` | Manipulation audio |
| `noisereduce` | Réduction de bruit |
| `faster-whisper` | Backend CTranslate2 (optionnel) |

Binaire whisper.cpp : `$EXO_WHISPERCPP_BIN`

---
Retour à l'index : [docs/README.md](../README.md)
