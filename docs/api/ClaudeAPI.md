# ClaudeAPI

> Client Anthropic Messages v1 avec streaming SSE et function calling

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Propriétés QML](#propriétés-qml)
- [Configuration](#configuration)
- [API principale](#api-principale)
  - [`sendMessage`](#sendmessage)
  - [`sendMessageFull`](#sendmessagefull)
  - [`sendToolResult`](#sendtoolresult)
  - [`cancelCurrentRequest`](#cancelcurrentrequest)
  - [`clearConversationHistory`](#clearconversationhistory)
- [Function calling (Tool Use)](#function-calling-tool-use)
  - [`buildToolSchema`](#buildtoolschema)
  - [`buildEXOTools`](#buildexotools)
- [Signaux](#signaux)
- [Streaming SSE](#streaming-sse)
  - [Sentence splitting](#sentence-splitting)
- [Robustesse](#robustesse)
- [ContentBlock](#contentblock)

<!-- /TOC -->

**Fichier** : `app/llm/ClaudeAPI.h` / `.cpp`
**Module** : LLM
**Hérite de** : `QObject`

---

## Description

`ClaudeAPI` encapsule la communication avec l'API Anthropic Claude. Il gère le streaming SSE (Server-Sent Events) token
par token, le function calling (tool use), le retry exponentiel, le rate limiting, et le sentence splitting pour le
pipelining TTS. Il maintient un historique de conversation multi-tour.

---

## Propriétés QML

| Propriété | Type | Accès | Description |
|---|---|---|---|
| `ready` | `bool` | lecture | API configurée et prête |
| `streaming` | `bool` | lecture | Requête streaming en cours |
| `model` | `QString` | lecture/écriture | Modèle Claude actif |

---

## Configuration

| Méthode | Description |
|---|---|
| `setApiKey(apiKey)` | Clé API Anthropic |
| `setModel(model)` | Modèle (défaut : `claude-sonnet-4-20250514`) |
| `setTemperature(temp)` | Température de génération |
| `setMaxTokens(tokens)` | Nombre max de tokens en sortie |
| `setTopP(topP)` | Top-P sampling |
| `setTopK(topK)` | Top-K sampling |
| `setTimeout(timeoutMs)` | Timeout réseau en ms |

---

## API principale

### `sendMessage`

```cpp
Q_INVOKABLE void sendMessage(const QString &userMessage);
```

Envoi simplifié compatible QML. Utilise le system prompt et les outils par défaut.

### `sendMessageFull`

```cpp
void sendMessageFull(const QString &userMessage,
                     const QString &systemPrompt,
                     const QJsonArray &tools = {},
                     bool stream = true);
```

Envoi complet avec contexte personnalisé, outils function calling et option streaming.

### `sendToolResult`

```cpp
void sendToolResult(const QString &toolUseId, const QJsonObject &result);
```

Envoie le résultat d'un tool call à Claude pour continuer la conversation.

### `cancelCurrentRequest`

```cpp
Q_INVOKABLE void cancelCurrentRequest();
```

Annule la requête réseau en cours.

### `clearConversationHistory`

```cpp
void clearConversationHistory();
```

Efface l'historique de conversation multi-tour.

---

## Function calling (Tool Use)

### `buildToolSchema`

```cpp
static QJsonObject buildToolSchema(const QString &name,
                                   const QString &description,
                                   const QJsonObject &inputSchema);
```

Construit un schéma d'outil au format Anthropic.

### `buildEXOTools`

```cpp
static QJsonArray buildEXOTools();
```

Retourne la liste complète des outils EXO (météo, mémoire, domotique, etc.).

---

## Signaux

| Signal | Paramètres | Description |
|---|---|---|
| `partialResponse` | `text: QString` | Token reçu en streaming |
| `finalResponse` | `fullText: QString` | Réponse complète accumulée |
| `sentenceReady` | `sentence: QString` | Phrase complète détectée (pour pipelining TTS) |
| `responseReceived` | `response: QString` | Alias QML de `finalResponse` |
| `toolCallDetected` | `toolUseId, toolName, arguments` | Tool call détecté dans la réponse |
| `errorOccurred` | `error: QString` | Erreur réseau / API / JSON |
| `requestStarted` | — | Début de requête |
| `requestFinished` | — | Fin de requête |
| `readyChanged` | — | Changement de l'état `ready` |
| `streamingChanged` | — | Changement de l'état `streaming` |
| `modelChanged` | — | Changement du modèle |

---

## Streaming SSE

Le parsing SSE gère les événements Anthropic suivants :

| Événement SSE | Traitement |
|---|---|
| `message_start` | Initialisation des accumulateurs |
| `content_block_start` | Nouveau bloc texte ou tool_use |
| `content_block_delta` | Accumulation de texte/JSON |
| `content_block_stop` | Finalisation d'un bloc |
| `message_delta` | Métadonnées (stop_reason, usage) |
| `message_stop` | Fin de message → émission signaux finaux |

### Sentence splitting

Pendant le streaming, le texte est découpé en phrases (`.`, `!`, `?`, `:`) et émis via `sentenceReady()` pour permettre
au TTS de commencer la synthèse avant la fin de la réponse complète.

---

## Robustesse

- **Retry exponentiel** : jusqu'à N tentatives avec backoff croissant
- **Rate limiting** : vérification avant chaque requête
- **Validation JSON** : vérification de la structure des réponses
- **Timeout** : timer configurable par requête

---

## ContentBlock

Structure interne pour l'accumulation des blocs de contenu pendant le streaming :

```cpp
struct ContentBlock {
    QString type;           // "text" ou "tool_use"
    QString text;           // contenu texte accumulé
    QString toolUseId;      // ID de l'outil
    QString toolName;       // Nom de l'outil
    QString toolInputJson;  // JSON des arguments accumulé
};
```

---
Retour à l'index : [docs/README.md](../README.md)
