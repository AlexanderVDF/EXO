# AssistantManager

> Gestionnaire principal de l'assistant EXO

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Responsabilités](#responsabilités)
- [Dépendances](#dépendances)
- [Propriétés QML](#propriétés-qml)
- [Méthodes publiques](#méthodes-publiques)
  - [`initializeWithConfig`](#initializewithconfig)
  - [`sendMessage`](#sendmessage)
  - [`sendManualQuery`](#sendmanualquery)
  - [`startListening` / `stopListening`](#startlistening-stoplistening)
  - [`getWeatherSummary`](#getweathersummary)
  - [Accesseurs composants](#accesseurs-composants)
- [Signaux](#signaux)
- [Slots privés](#slots-privés)
- [Flux d'appel](#flux-dappel)

<!-- /TOC -->

**Fichier** : `app/core/AssistantManager.h` / `.cpp`
**Module** : Core
**Hérite de** : `QObject`

---

## Description

`AssistantManager` est le point d'entrée central de l'application EXO. Il coordonne tous les composants majeurs :
`ClaudeAPI`, `VoicePipeline`, `WeatherManager`, `AIMemoryManager`, `ConfigManager`, `HealthCheck` et
`AudioDeviceManager`. Il initialise le pipeline, expose les composants au moteur QML et orchestre les interactions
utilisateur.

## Responsabilités

- Charger la configuration et initialiser tous les sous-composants
- Exposer les composants au moteur QML (`setContextProperty`)
- Router les messages utilisateur vers Claude API
- Dispatcher les tool calls (function calling) vers les managers spécialisés
- Gérer les états d'écoute (listening on/off)

## Dépendances

| Composant | Rôle |
|---|---|
| `ConfigManager` | Configuration centralisée |
| `ClaudeAPI` | Communication avec l'API Anthropic |
| `VoicePipeline` | Pipeline audio complet (capture → STT → TTS) |
| `WeatherManager` | Données météorologiques |
| `AIMemoryManager` | Mémoire sémantique 3 couches |
| `HealthCheck` | Surveillance des microservices |
| `AudioDeviceManager` | Gestion des périphériques audio |

---

## Propriétés QML

| Propriété | Type | Accès | Description |
|---|---|---|---|
| `isListening` | `bool` | lecture | `true` si le pipeline écoute le microphone |
| `isInitialized` | `bool` | lecture | `true` après initialisation complète |
| `configManager` | `ConfigManager*` | lecture | Accès direct au gestionnaire de configuration |
| `healthCheck` | `HealthCheck*` | lecture | Accès direct au moniteur de santé |
| `audioDeviceManager` | `AudioDeviceManager*` | lecture | Accès direct au gestionnaire de périphériques audio |

---

## Méthodes publiques

### `initializeWithConfig`

```cpp
Q_INVOKABLE bool initializeWithConfig(const QString &configPath = "config/assistant.conf");
```

Charge la configuration depuis le fichier spécifié, initialise tous les composants et les connexions signal/slot.
Retourne `true` en cas de succès.

### `sendMessage`

```cpp
Q_INVOKABLE void sendMessage(const QString &message);
```

Envoie un message texte à Claude API avec le contexte mémoire. Utilisé par le pipeline vocal après transcription STT.

### `sendManualQuery`

```cpp
Q_INVOKABLE void sendManualQuery(const QString &text);
```

Envoie une requête textuelle manuelle (depuis l'interface QML). Similaire à `sendMessage` mais avec un chemin dédié pour
l'entrée clavier.

### `startListening` / `stopListening`

```cpp
Q_INVOKABLE void startListening();
Q_INVOKABLE void stopListening();
```

Active/désactive la capture audio et le pipeline vocal.

### `getWeatherSummary`

```cpp
Q_INVOKABLE QString getWeatherSummary() const;
```

Retourne un résumé textuel de la météo actuelle (délègue à `WeatherManager`).

### Accesseurs composants

```cpp
ClaudeAPI* claudeApi() const;
VoicePipeline* voicePipeline() const;
WeatherManager* weatherManager() const;
ConfigManager* configManager() const;
AIMemoryManager* memoryManager() const;
HealthCheck* healthCheck() const;
AudioDeviceManager* audioDeviceManager() const;
```

---

## Signaux

| Signal | Paramètres | Description |
|---|---|---|
| `messageReceived` | `sender: QString`, `message: QString` | Message reçu (utilisateur ou assistant) |
| `claudeResponseReceived` | `response: QString` | Réponse finale de Claude |
| `claudePartialResponse` | `partialText: QString` | Token partiel en streaming |
| `listeningStateChanged` | `isListening: bool` | Changement d'état d'écoute |
| `initializationComplete` | — | Tous les composants initialisés |
| `errorOccurred` | `error: QString` | Erreur système |

---

## Slots privés

| Slot | Description |
|---|---|
| `onClaudeResponse` | Traite la réponse finale de Claude |
| `onClaudePartial` | Relaye les tokens partiels au QML |
| `onToolCall` | Dispatche les tool calls (météo, mémoire, domotique) |
| `onWeatherUpdate` | Met à jour les données météo |
| `onError` | Centralise la gestion d'erreurs |
| `onConfigurationLoaded` | Finalise l'initialisation après chargement config |

---

## Flux d'appel

```
QML (sendManualQuery / startListening)
  → AssistantManager
    → ClaudeAPI.sendMessageFull(message, systemPrompt, tools)
      ← partialResponse → QML (streaming)
      ← toolCallDetected → onToolCall → WeatherManager / AIMemoryManager
      ← finalResponse → onClaudeResponse → QML
```

---
Retour à l'index : [docs/README.md](../README.md)
