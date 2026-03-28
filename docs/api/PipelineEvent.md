# PipelineEvent — Bus d'événements du pipeline

> Système d'événements centralisé pour traçabilité temps-réel

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Énumérations](#énumérations)
  - [PipelineModule (12 modules)](#pipelinemodule-12-modules)
  - [ModuleState (5 états)](#modulestate-5-états)
  - [EventType (35+ types)](#eventtype-35-types)
- [Structures](#structures)
  - [PipelineEvent](#pipelineevent)
  - [ModuleStatus](#modulestatus)
  - [InteractionTrace](#interactiontrace)
- [PipelineEventBus (Singleton)](#pipelineeventbus-singleton)
  - [Accès](#accès)
  - [Gestion des interactions](#gestion-des-interactions)
  - [Émission d'événements](#émission-dévénements)
  - [Suivi des modules](#suivi-des-modules)
  - [Requêtes](#requêtes)
  - [Signaux](#signaux)
  - [Macros utilitaires](#macros-utilitaires)

<!-- /TOC -->

**Fichiers** : `app/core/PipelineEvent.h`, `app/core/PipelineTypes.h`
**Module** : Core
**Hérite de** : `QObject` (PipelineEventBus)

---

## Description

Le système d'événements du pipeline permet de suivre chaque interaction de bout en bout, depuis la détection vocale
jusqu'à la synthèse audio. Il repose sur trois composants :

1. **PipelineTypes** — Énumérations des types d'événements
2. **PipelineEvent** — Structure d'un événement
3. **PipelineEventBus** — Singleton de distribution et de suivi

---

## Énumérations

### PipelineModule (12 modules)

| Valeur | Description |
|---|---|
| `AudioCapture` | Capture audio |
| `Preprocessor` | Prétraitement audio |
| `VAD` | Détection d'activité vocale |
| `STT` | Speech-to-Text |
| `NLU` | Compréhension du langage |
| `Claude` | LLM (Claude API) |
| `TTS` | Text-to-Speech |
| `AudioOutput` | Sortie audio |
| `WakeWord` | Mot de réveil |
| `Memory` | Mémoire sémantique |
| `Orchestrator` | Orchestrateur central |
| `GUI` | Interface graphique |

### ModuleState (5 états)

| Valeur | Description |
|---|---|
| `Idle` | En attente |
| `Active` | Actif |
| `Processing` | Traitement en cours |
| `Error` | En erreur |
| `Unavailable` | Indisponible |

### EventType (35+ types)

| Catégorie | Types |
|---|---|
| **VAD** | `SpeechStarted`, `SpeechEnded` |
| **WakeWord** | `WakeWordDetected` |
| **STT** | `StreamStarted`, `PartialTranscript`, `FinalTranscript`, `UtteranceFinished`, `STTError` |
| **LLM** | `RequestStarted`, `FirstToken`, `PartialResponse`, `FinalResponse`, `SentenceReady`, `ReplyFinished`, `ToolCall`, `ToolCallDispatched`, `NetworkError`, `ResponseReceived` |
| **TTS** | `SynthesisRequested`, `SentenceQueued`, `SpeechCancelled`, `WorkerStarted`, `WorkerError`, `SpeechFinalized`, `SpeakRequested`, `SentenceEnqueued` |
| **AudioOutput** | `PcmChunk`, `PlaybackStarted`, `PlaybackFinished`, `TTSError` |
| **Orchestrator** | `TranscriptDispatched`, `SpeechTranscribed`, `StateChanged`, `OrphanInteractionClosed` |

La fonction `eventTypeToString(EventType)` fournit la représentation texte.

---

## Structures

### PipelineEvent

| Champ | Type | Description |
|---|---|---|
| `timestamp` | `qint64` | Timestamp en millisecondes |
| `module` | `PipelineModule` | Module émetteur |
| `eventType` | `EventType` | Type d'événement |
| `correlationId` | `QString` | ID de corrélation (UUID par interaction) |
| `payload` | `QVariantMap` | Données associées |
| `elapsedMs` | `double` | Temps écoulé depuis début interaction |

### ModuleStatus

| Champ | Type | Description |
|---|---|---|
| `module` | `PipelineModule` | Module |
| `state` | `ModuleState` | État courant |
| `lastEvent` | `qint64` | Timestamp dernier événement |

### InteractionTrace

| Champ | Type | Description |
|---|---|---|
| `correlationId` | `QString` | ID de corrélation |
| `events` | `QVector<PipelineEvent>` | Événements de l'interaction |
| `startTime` | `qint64` | Début |
| `active` | `bool` | En cours ? |

---

## PipelineEventBus (Singleton)

### Accès

```cpp
PipelineEventBus& bus = PipelineEventBus::instance();
```

### Gestion des interactions

| Méthode | Description |
|---|---|
| `beginInteraction() → QString` | Démarre une interaction, retourne le correlationId (UUID) |
| `endInteraction(correlationId)` | Termine une interaction |

### Émission d'événements

| Méthode | Description |
|---|---|
| `postEvent(event)` | Poster un PipelineEvent complet |
| `emitWithId(module, eventType, correlationId, payload)` | Émission simplifiée |

### Suivi des modules

| Méthode | Description |
|---|---|
| `setModuleState(module, state)` | Changer l'état d'un module |
| `setModuleMetrics(module, payload)` | Ajouter des métriques |
| `setModuleError(module, error)` | Signaler une erreur |
| `moduleStatus(module)` | Obtenir le statut d'un module |
| `allModuleStatuses()` | Statuts de tous les modules |

### Requêtes

| Méthode | Retour | Description |
|---|---|---|
| `recentTraces()` | `QList<InteractionTrace>` | Traces récentes |
| `getPipelineSnapshot()` | `QVariantMap` | Snapshot JSON du pipeline |
| `getRecentEvents(n)` | `QVariantList` | N derniers événements |
| `getModuleTimeline(module, correlationId)` | `QVariantList` | Timeline d'un module |

### Signaux

| Signal | Paramètres | Description |
|---|---|---|
| `eventEmitted` | `PipelineEvent` | Événement posté |
| `moduleStateChanged` | `PipelineModule, ModuleState` | Changement d'état module |
| `interactionStarted` | `correlationId: QString` | Nouvelle interaction |
| `interactionEnded` | `correlationId: QString` | Fin d'interaction |

### Macros utilitaires

```cpp
PIPELINE_EVENT(module, eventType, correlationId, payload)
PIPELINE_STATE(module, state)
```

---
Retour à l'index : [docs/README.md](../README.md)
