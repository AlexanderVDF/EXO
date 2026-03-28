# LogManager

> Système de logging centralisé avec intégration pipeline

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Niveaux de log](#niveaux-de-log)
- [Catégories de logging (6)](#catégories-de-logging-6)
  - [Utilisation des macros](#utilisation-des-macros)
- [Méthodes Q_INVOKABLE](#méthodes-q_invokable)
- [Capacités](#capacités)
- [Intégration pipeline](#intégration-pipeline)

<!-- /TOC -->

**Fichier** : `app/core/LogManager.h` / `.cpp`
**Module** : Core
**Hérite de** : `QObject`
**Singleton** : Oui

---

## Description

`LogManager` centralise tous les messages de log de l'application et les événements du pipeline. Les logs sont
accessibles via QML pour le panneau de diagnostic intégré à l'interface.

---

## Niveaux de log

| Niveau | Description |
|---|---|
| `Debug` | Messages de débogage |
| `Info` | Informations générales |
| `Warning` | Avertissements |
| `Critical` | Erreurs critiques |

---

## Catégories de logging (6)

Chaque catégorie correspond à un `QLoggingCategory` Qt :

| Catégorie | Identifiant | Macro | Usage |
|---|---|---|---|
| Main | `henri.main` | `hLog` | Logs généraux |
| Config | `henri.config` | `hConfig` | Configuration |
| Claude | `henri.claude` | `hClaude` | API Claude |
| Voice | `henri.voice` | `hVoice` | Pipeline vocal |
| Weather | `henri.weather` | `hWeather` | Météo |
| Assistant | `henri.assistant` | `hAssistant` | Assistant |

### Utilisation des macros

```cpp
hLog()      << "Message général";
hClaude()   << "Réponse reçue en" << ms << "ms";
hVoice()    << "VAD: parole détectée";
```

---

## Méthodes Q_INVOKABLE

| Méthode | Retour | Description |
|---|---|---|
| `getRecentLogs(count)` | `QVariantList` | Derniers messages de log |
| `getLogsByFilter(level, category)` | `QVariantList` | Logs filtrés |
| `clearLogs()` | `void` | Vider le buffer de logs |
| `copyToClipboard()` | `void` | Copier les logs dans le presse-papiers |
| `getRecentPipelineEvents(count)` | `QVariantList` | Derniers événements pipeline |

---

## Capacités

| Paramètre | Valeur |
|---|---|
| Max entrées de log | 500 |
| Max événements pipeline | 200 |

---

## Intégration pipeline

`LogManager` écoute les événements de `PipelineEventBus` et les stocke dans un buffer circulaire dédié, séparé des logs
classiques. Cela permet d'afficher dans le panneau QML à la fois les logs texte et les événements pipeline avec
corrélation.

---
Retour à l'index : [docs/README.md](../README.md)
