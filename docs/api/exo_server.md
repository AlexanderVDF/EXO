# exo_server — Orchestrateur Principal

> Serveur WebSocket GUI + Bridge Home Assistant

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Messages entrants (GUI → Serveur)](#messages-entrants-gui-serveur)
  - [Commandes de navigation](#commandes-de-navigation)
  - [Configuration](#configuration)
  - [Réseau](#réseau)
  - [Pipeline vocal](#pipeline-vocal)
- [Messages sortants (Serveur → GUI)](#messages-sortants-serveur-gui)
  - [Snapshot initial](#snapshot-initial)
  - [Broadcasts](#broadcasts)
- [Intégrations Home Assistant](#intégrations-home-assistant)
  - [Composants](#composants)
  - [TOOL_DEFINITIONS](#tool_definitions)
- [Configuration](#configuration)
- [Dépendances](#dépendances)

<!-- /TOC -->

**Fichier** : `python/orchestrator/exo_server.py`
**Port** : `8765`
**Protocole** : WebSocket (JSON)

---

## Description

Serveur backend principal d'EXO. Il assure deux rôles :

1. **GUIServer** — Serveur WebSocket pour l'interface Qt/QML (état du pipeline, transcriptions, niveaux audio)
2. **HomeBridge** — Bridge vers Home Assistant pour le contrôle domotique

---

## Messages entrants (GUI → Serveur)

### Commandes de navigation

**Planifier un déplacement :**
```json
{
  "type": "plan_move",
  "area": "salon",
  "device": "lumière"
}
```

### Configuration

**Mise à jour des paramètres :**
```json
{
  "type": "settings_update",
  "settings": {
    "tts_voice": "Claribel Dervla",
    "stt_model": "medium"
  }
}
```

### Réseau

**Scanner le réseau :**
```json
{ "type": "network_scan" }
```

### Pipeline vocal

**Transcription finale :**
```json
{
  "type": "transcript",
  "text": "Bonjour, quelle est la météo ?"
}
```

**Transcription partielle :**
```json
{
  "type": "partial_transcript",
  "text": "Bonjour quelle est"
}
```

**État du pipeline :**
```json
{
  "type": "pipeline_state",
  "state": "listening"
}
```

**Niveau audio :**
```json
{
  "type": "audio_level",
  "level": 0.45
}
```

---

## Messages sortants (Serveur → GUI)

### Snapshot initial

À la connexion, le serveur envoie un snapshot complet de l'état :

```json
{
  "type": "initial_state",
  "areas": [...],
  "devices": [...],
  "entities": [...],
  "settings": {...}
}
```

### Broadcasts

Le serveur diffuse les changements d'état à tous les clients GUI connectés :

```json
{
  "type": "state_update",
  "module": "stt",
  "state": "processing"
}
```

---

## Intégrations Home Assistant

### Composants

| Composant | Rôle |
|---|---|
| `HomeBridge` | Connexion à l'API Home Assistant |
| `EntityManager` | Gestion des entités HA |
| `DeviceManager` | Gestion des appareils |
| `AreaManager` | Gestion des zones/pièces |
| `ActionDispatcher` | Dispatch des actions (avec `TOOL_DEFINITIONS`) |
| `SyncManager` | Synchronisation des états |

### TOOL_DEFINITIONS

L'`ActionDispatcher` expose des définitions d'outils compatibles avec le function calling de Claude, permettant au LLM
de contrôler les appareils domotiques via des appels de fonctions structurés.

---

## Configuration

Le serveur charge les variables depuis `.env` :

| Variable | Usage |
|---|---|
| `HA_URL` | URL de Home Assistant |
| `HA_TOKEN` | Token d'accès longue durée |
| `EXO_GUI_PORT` | Port WebSocket (défaut : 8765) |

---

## Dépendances

| Package | Usage |
|---|---|
| `websockets` | Serveur WebSocket |
| `python-dotenv` | Chargement `.env` |
| `aiohttp` | Client HTTP async (HA API) |

---
Retour à l'index : [docs/README.md](../README.md)
