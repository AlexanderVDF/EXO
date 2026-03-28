# wakeword_server — Wake Word Detection Server

> Détection du mot de réveil via OpenWakeWord

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Protocole WebSocket](#protocole-websocket)
  - [Messages entrants (Client → Serveur)](#messages-entrants-client-serveur)
  - [Messages sortants (Serveur → Client)](#messages-sortants-serveur-client)
- [Paramètres](#paramètres)
- [Caractéristiques Audio](#caractéristiques-audio)
- [Répertoire des modèles](#répertoire-des-modèles)
- [Dépendances](#dépendances)

<!-- /TOC -->

**Fichier** : `python/wakeword/wakeword_server.py`
**Port** : `8770`
**Protocole** : WebSocket (binaire + JSON)

---

## Description

Serveur de détection du mot de réveil utilisant OpenWakeWord. Analyse en continu le flux audio pour détecter le mot-clé
configuré (défaut : "hey_jarvis") et notifie le client avec le score de confiance.

---

## Protocole WebSocket

### Messages entrants (Client → Serveur)

**Audio (binaire) :**
```
[PCM16 mono 16kHz, 1280 samples/chunk]
```

**Configuration :**
```json
{
  "type": "config",
  "threshold": 0.7,
  "model": "hey_jarvis"
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

**Mot de réveil détecté :**
```json
{
  "type": "wakeword",
  "word": "hey_jarvis",
  "score": 0.92
}
```

---

## Paramètres

| Paramètre | Défaut | Description |
|---|---|---|
| Modèle | `hey_jarvis` | Modèle de wake word |
| Seuil | `0.7` | Score minimum pour déclencher |
| Cooldown | 3 s | Délai entre deux détections |

---

## Caractéristiques Audio

| Paramètre | Valeur |
|---|---|
| Sample rate | 16 000 Hz |
| Taille de chunk | 1 280 samples (80 ms) |
| Format | PCM16 mono little-endian |

---

## Répertoire des modèles

`$EXO_WAKEWORD_MODELS` (défaut : `D:\EXO\models\wakeword`)

---

## Dépendances

| Package | Usage |
|---|---|
| `websockets` | Serveur WebSocket |
| `openwakeword` | Moteur de détection |
| `numpy` | Manipulation audio |

---
Retour à l'index : [docs/README.md](../README.md)
