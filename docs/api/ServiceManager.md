# ServiceManager

> Lancement automatique et supervision des microservices Python

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Configuration](#configuration)
- [Structure ServiceInfo](#structure-serviceinfo)
  - [ServiceStatus](#servicestatus)
- [Propriétés QML](#propriétés-qml)
- [Méthodes Q_INVOKABLE](#méthodes-q_invokable)
- [Signaux](#signaux)
- [Séquence de démarrage](#séquence-de-démarrage)

<!-- /TOC -->

**Fichier** : `app/core/ServiceManager.h` / `.cpp`
**Module** : Core
**Hérite de** : `QObject`

---

## Description

`ServiceManager` gère le cycle de vie complet des microservices Python (STT, TTS, VAD, WakeWord, Memory, NLU). Il lance
chaque service via `QProcess`, sonde leur disponibilité par connexion WebSocket, et expose la progression côté QML pour
l'écran de démarrage (splash screen).

---

## Configuration

Les services sont déclarés dans `config/services.json` :

```json
{
  "services": [
    {
      "name": "STT",
      "port": 8766,
      "venv": ".venv_stt_tts",
      "script": "python/stt/stt_server.py",
      "args": ["--backend", "whispercpp", "--model", "medium"]
    }
  ]
}
```

---

## Structure ServiceInfo

| Champ | Type | Description |
|---|---|---|
| `name` | `QString` | Nom du service |
| `port` | `int` | Port WebSocket |
| `venv` | `QString` | Chemin du virtualenv |
| `script` | `QString` | Script Python à lancer |
| `args` | `QStringList` | Arguments CLI |
| `status` | `ServiceStatus` | État courant |
| `process` | `QProcess*` | Processus système |
| `probe` | `WebSocketClient*` | Client de sondage |

### ServiceStatus

| Valeur | Description |
|---|---|
| `Unknown` | Pas encore vérifié |
| `Checking` | Vérification en cours |
| `Running` | Processus lancé |
| `Launching` | En cours de lancement |
| `Ready` | Service opérationnel (WebSocket répond) |
| `Failed` | Échec de lancement |

---

## Propriétés QML

| Propriété | Type | Description |
|---|---|---|
| `allReady` | `bool` | Tous les services sont prêts ? |
| `totalServices` | `int` | Nombre total de services |
| `readyCount` | `int` | Nombre de services prêts |
| `currentAction` | `QString` | Action en cours (pour le splash) |
| `serviceStatuses` | `QVariantList` | Statuts détaillés par service |

---

## Méthodes Q_INVOKABLE

| Méthode | Description |
|---|---|
| `start(servicesJsonPath)` | Charger la config et lancer tous les services |
| `shutdownAll()` | Arrêter proprement tous les processus |

---

## Signaux

| Signal | Paramètres | Description |
|---|---|---|
| `allServicesReady` | — | Tous les services sont `Ready` |
| `serviceStatusChanged` | `name: QString, status: ServiceStatus` | Changement d'état d'un service |
| `currentActionChanged` | — | Mise à jour de l'action courante |
| `startupFailed` | `reason: QString` | Échec global du démarrage |

---

## Séquence de démarrage

```
start(services.json)
    │
    ├── Pour chaque service :
    │   ├── Checking  → Vérifier si le port est déjà occupé
    │   ├── Launching → QProcess::start(venv/python, script, args)
    │   ├── Running   → Processus démarré
    │   └── Ready     → WebSocketClient probe connectée (timeout 30s)
    │
    └── allServicesReady signal quand readyCount == totalServices
```

En cas d'échec de la sonde après 30 secondes, le service passe en état `Failed`.

---
Retour à l'index : [docs/README.md](../README.md)
