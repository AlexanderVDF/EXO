# WebSocketClient

> Client WebSocket réutilisable avec auto-reconnexion

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Machine d'état](#machine-détat)
- [Cycle de vie](#cycle-de-vie)
- [Politique de reconnexion](#politique-de-reconnexion)
- [Envoi de données](#envoi-de-données)
- [Accesseurs](#accesseurs)
- [Signaux](#signaux)

<!-- /TOC -->

**Fichier** : `app/core/WebSocketClient.h` / `.cpp`
**Module** : Core
**Hérite de** : `QObject`

---

## Description

`WebSocketClient` encapsule `QWebSocket` avec une machine d'état de connexion et une reconnexion automatique
configurable. Chaque microservice Python (STT, TTS, VAD, WakeWord, Memory) utilise une instance dédiée, éliminant le
code boilerplate dupliqué.

---

## Machine d'état

```
Disconnected ──▶ Connecting ──▶ Connected
                                    │
                                    ▼
                              Reconnecting ──▶ Connecting
```

| État | Description |
|---|---|
| `Disconnected` | Pas de connexion |
| `Connecting` | Tentative de connexion en cours |
| `Connected` | Connexion active |
| `Reconnecting` | Reconnexion en attente (après déconnexion) |

---

## Cycle de vie

| Méthode | Description |
|---|---|
| `open(url)` | Ouvrir une connexion WebSocket |
| `close()` | Fermer proprement la connexion |

---

## Politique de reconnexion

| Méthode | Description |
|---|---|
| `setReconnectEnabled(enabled)` | Activer/désactiver la reconnexion auto |
| `setReconnectParams(baseMs, maxAttempts, exponential)` | Configurer les paramètres |

- **baseMs** : délai de base entre tentatives (défaut : 3000 ms)
- **maxAttempts** : 0 = tentatives illimitées
- **exponential** : backoff exponentiel vs délai fixe

---

## Envoi de données

| Méthode | Description |
|---|---|
| `sendText(msg)` | Envoyer un message texte |
| `sendJson(obj)` | Envoyer un `QJsonObject` sérialisé |
| `sendBinary(data)` | Envoyer des données binaires (audio PCM) |

---

## Accesseurs

| Méthode | Retour | Description |
|---|---|---|
| `isConnected()` | `bool` | État connecté ? |
| `state()` | `State` | État actuel de la machine |
| `name()` | `QString` | Nom du client (ex : "STT", "VAD") |
| `url()` | `QUrl` | URL de connexion |
| `socket()` | `QWebSocket*` | Accès direct au socket sous-jacent |

---

## Signaux

| Signal | Paramètres | Description |
|---|---|---|
| `connected` | — | Connexion établie |
| `disconnected` | — | Connexion perdue |
| `textReceived` | `message: QString` | Message texte reçu |
| `binaryReceived` | `data: QByteArray` | Données binaires reçues |
| `stateChanged` | `newState: State` | Transition d'état |
| `errorOccurred` | `description: QString` | Erreur WebSocket |

---
Retour à l'index : [docs/README.md](../README.md)
