# tts_server — Text-to-Speech Streaming Server

> Synthèse vocale streaming XTTS v2

<!-- TOC -->
## Table des matières

- [Description](#description)
  - [Détection matérielle (ordre de priorité)](#détection-matérielle-ordre-de-priorité)
- [Paramètres Cli](#paramètres-cli)
- [Protocole WebSocket](#protocole-websocket)
  - [Messages entrants (Client → Serveur)](#messages-entrants-client-serveur)
  - [Messages sortants (Serveur → Client)](#messages-sortants-serveur-client)
- [Caractéristiques Audio](#caractéristiques-audio)
- [Fonctionnalités avancées](#fonctionnalités-avancées)
  - [PhraseCache](#phrasecache)
  - [Nettoyage du texte](#nettoyage-du-texte)
  - [Monkey-patches](#monkey-patches)
- [Dépendances](#dépendances)

<!-- /TOC -->

**Fichier** : `python/tts/tts_server.py`
**Port** : `8767`
**Protocole** : WebSocket (JSON + binaire)

---

## Description

Serveur de synthèse vocale basé sur XTTS v2 (Coqui TTS) avec détection automatique du meilleur accélérateur matériel.
Produit des chunks PCM16 en streaming pour une latence minimale.

### Détection matérielle (ordre de priorité)

1. **CUDA** — GPU NVIDIA
2. **DirectML** — GPU via DirectX 12 (AMD, Intel, NVIDIA sous Windows)
3. **CPU** — Fallback

---

## Paramètres Cli

| Argument | Défaut | Description |
|---|---|---|
| `--host` | `0.0.0.0` | Adresse d'écoute |
| `--port` | `8767` | Port WebSocket |
| `--voice` | `Claribel Dervla` | Voix par défaut |
| `--lang` | `fr` | Langue par défaut |
| `--model-dir` | `$EXO_XTTS_MODELS` | Répertoire des modèles |

---

## Protocole WebSocket

### Messages entrants (Client → Serveur)

**Synthétiser :**
```json
{
  "type": "synthesize",
  "text": "Bonjour, comment allez-vous ?",
  "voice": "Claribel Dervla",
  "lang": "fr",
  "rate": 1.0,
  "pitch": 1.0,
  "style": "default"
}
```

**Annuler :**
```json
{ "type": "cancel" }
```

**Lister les voix :**
```json
{ "type": "list_voices" }
```

### Messages sortants (Serveur → Client)

**Prêt :**
```json
{
  "type": "ready",
  "engine": "xtts_directml",
  "voices": ["Claribel Dervla", "Ana Florence", ...],
  "sample_rate": 24000
}
```

**Début de synthèse :**
```json
{ "type": "start" }
```

**Chunk audio (binaire) :**
```
[PCM16 mono 24kHz, little-endian]
```

**Fin de synthèse :**
```json
{ "type": "end" }
```

**Liste des voix :**
```json
{
  "type": "voices",
  "voices": ["Claribel Dervla", "Ana Florence", ...]
}
```

**Erreur :**
```json
{
  "type": "error",
  "message": "Synthesis failed: ..."
}
```

---

## Caractéristiques Audio

| Paramètre | Valeur |
|---|---|
| Sample rate | 24 000 Hz |
| Canaux | 1 (mono) |
| Format | PCM16 little-endian |

---

## Fonctionnalités avancées

### PhraseCache

Cache en mémoire des embeddings de locuteur pour éviter de les recalculer à chaque requête.

### Nettoyage du texte

Les emojis et caractères spéciaux sont automatiquement supprimés avant synthèse.

### Monkey-patches

Le serveur applique des patches de compatibilité pour `transformers` (gestion de `inference_mode`, `isin_mps_friendly`,
`_get_logits_warper`, tensors DirectML) afin de fonctionner avec les versions récentes.

---

## Dépendances

| Package | Usage |
|---|---|
| `websockets` | Serveur WebSocket |
| `TTS` (Coqui) | Moteur XTTS v2 |
| `torch` | Backend ML |
| `torch-directml` | Accélération DirectML (optionnel) |
| `numpy` | Manipulation audio |

---
Retour à l'index : [docs/README.md](../README.md)
