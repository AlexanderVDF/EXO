# PipelineTracer

> Analyse post-interaction et détection d'anomalies

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Structures](#structures)
  - [TimelineSegment](#timelinesegment)
  - [InteractionSummary](#interactionsummary)
  - [AnomalyType (8 types)](#anomalytype-8-types)
- [API publique](#api-publique)
  - [Analyse](#analyse)
  - [Requêtes](#requêtes)
  - [Configuration des seuils](#configuration-des-seuils)
- [Watchdog d'interactions orphelines](#watchdog-dinteractions-orphelines)
- [Intégration](#intégration)

<!-- /TOC -->

**Fichier** : `app/core/PipelineTracer.h` / `.cpp`
**Module** : Core
**Hérite de** : `QObject`
**Singleton** : Oui

---

## Description

`PipelineTracer` reconstruit la timeline de chaque interaction à partir des événements du `PipelineEventBus`, calcule
les latences par module, et détecte automatiquement les anomalies de performance. Un watchdog surveille les interactions
orphelines.

---

## Structures

### TimelineSegment

| Champ | Type | Description |
|---|---|---|
| `moduleName` | `QString` | Nom du module |
| `startMs` | `double` | Début (ms depuis début interaction) |
| `endMs` | `double` | Fin (ms) |

### InteractionSummary

| Champ | Type | Description |
|---|---|---|
| `correlationId` | `QString` | ID de corrélation |
| `totalMs` | `double` | Durée totale |
| `vadMs` | `double` | Temps VAD |
| `sttMs` | `double` | Temps STT |
| `llmMs` | `double` | Temps LLM |
| `llmFirstToken` | `double` | Time to first token |
| `ttsMs` | `double` | Temps TTS |
| `playbackMs` | `double` | Temps playback |
| `sentenceCount` | `int` | Nombre de phrases TTS |
| `eventCount` | `int` | Nombre d'événements |
| `anomalies` | `QStringList` | Liste des anomalies détectées |

### AnomalyType (8 types)

| Type | Seuil par défaut | Description |
|---|---|---|
| `SlowSTT` | > 5 000 ms | STT trop lent |
| `SlowLLM` | > 15 000 ms | LLM trop lent |
| `SlowTTS` | > 10 000 ms | TTS trop lent |
| `NoResponse` | — | Pas de réponse reçue |
| `DoubleTTS` | — | Double synthèse TTS |
| `OverlapSpeaking` | — | Chevauchement parole/écoute |
| `OrphanInteraction` | > 60 s | Interaction jamais terminée |
| `TotalTimeout` | > 30 000 ms | Durée totale excessive |

---

## API publique

### Analyse

| Méthode | Description |
|---|---|
| `assembleTimeline(correlationId)` | Construire la timeline d'une interaction |
| `detectAnomalies(correlationId)` | Détecter les anomalies |
| `buildSummary(correlationId)` | Générer le résumé complet |

### Requêtes

| Méthode | Retour | Description |
|---|---|---|
| `getRecentSummaries(n)` | `QList<InteractionSummary>` | N derniers résumés |
| `getLastSummary()` | `InteractionSummary` | Dernier résumé |

### Configuration des seuils

Les seuils de détection d'anomalies sont configurables via les propriétés du tracer.

---

## Watchdog d'interactions orphelines

Un timer interne (60 secondes) vérifie les interactions qui n'ont jamais reçu d'événement `endInteraction`. Elles sont
marquées avec l'anomalie `OrphanInteraction` et forcées à se terminer.

---

## Intégration

```
PipelineEventBus ──eventEmitted──▶ PipelineTracer
                                         │
                                    buildSummary()
                                         │
                                    InteractionSummary
                                    (latences + anomalies)
```

Le `LogManager` consomme également les résumés pour le panneau de logs QML.

---
Retour à l'index : [docs/README.md](../README.md)
