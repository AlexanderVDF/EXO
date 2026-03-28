# AIMemoryManager

> Mémoire intelligente 3 couches + bridge FAISS

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Propriétés QML](#propriétés-qml)
- [Conversations](#conversations)
- [Préférences utilisateur](#préférences-utilisateur)
- [Mémoire sémantique](#mémoire-sémantique)
  - [Paramètres d'un souvenir (MemoryEntry)](#paramètres-dun-souvenir-memoryentry)
- [Contexte Claude](#contexte-claude)
- [Détection automatique](#détection-automatique)
- [Import / Export](#import-export)
- [Nettoyage](#nettoyage)
- [Configuration avancée](#configuration-avancée)
- [Serveur sémantique (FAISS)](#serveur-sémantique-faiss)
- [Signaux](#signaux)
- [Persistance](#persistance)

<!-- /TOC -->

**Fichier** : `app/llm/AIMemoryManager.h` / `.cpp`
**Module** : LLM
**Hérite de** : `QObject`

---

## Description

`AIMemoryManager` implémente un système de mémoire à 3 couches pour l'assistant EXO :

1. **Conversations** : buffer circulaire de l'historique user ↔ assistant
2. **Préférences** : stockage clé/valeur persistant
3. **Souvenirs** : mémoire sémantique avec importance, tags, récence et détection automatique

En option, il se connecte à `memory_server.py` (FAISS + SentenceTransformers) pour la recherche vectorielle. En
fallback, il utilise une recherche regex locale.

**Persistance** : fichier JSON atomique dans `%APPDATA%/EXOAssistant/` (format v2).

---

## Propriétés QML

| Propriété | Type | Description |
|---|---|---|
| `memoryEnabled` | `bool` | Mémoire activée/désactivée |
| `conversationCount` | `int` | Nombre d'entrées de conversation |
| `memoryCount` | `int` | Nombre de souvenirs stockés |

---

## Conversations

| Méthode | Description |
|---|---|
| `addConversation(user, assistant)` | Ajouter un échange à l'historique |
| `getConversationContext(maxEntries)` | Contexte formaté des N dernières conversations |
| `getRecentConversations(count)` | Liste des conversations récentes |

---

## Préférences utilisateur

| Méthode | Description |
|---|---|
| `updateUserPreference(key, value)` | Définir/mettre à jour une préférence |
| `getUserPreference(key, default)` | Lire une préférence |

---

## Mémoire sémantique

| Méthode | Description |
|---|---|
| `addMemory(text, importance, tags, category, source)` | Ajouter un souvenir |
| `searchMemories(query, maxResults)` | Recherche sémantique (FAISS ou regex fallback) |
| `getMemoriesByTag(tag, maxResults)` | Filtrer par tag |
| `getAllMemories()` | Lister tous les souvenirs |
| `removeMemory(id)` | Supprimer un souvenir par UUID |

### Paramètres d'un souvenir (MemoryEntry)

| Champ | Type | Description |
|---|---|---|
| `id` | `QString` | UUID unique |
| `text` | `QString` | Contenu textuel |
| `importance` | `double` | Score 0.0 – 1.0 |
| `tags` | `QStringList` | Tags associés |
| `timestamp` | `qint64` | Horodatage (ms epoch) |
| `source` | `QString` | `"auto"` / `"user"` / `"system"` |
| `category` | `QString` | `"identité"`, `"préférence"`, etc. |

---

## Contexte Claude

```cpp
Q_INVOKABLE QString buildClaudeContext(int maxConversations = 5,
                                       int maxMemories = 5) const;
```

Construit un bloc de contexte formaté incluant conversations récentes et souvenirs pertinents, injecté dans le system
prompt de Claude.

---

## Détection automatique

```cpp
void analyzeAndMaybeStore(const QString &userMessage);
```

Analyse le message utilisateur et stocke automatiquement les informations identitaires, préférences ou faits importants
détectés.

---

## Import / Export

| Méthode | Description |
|---|---|
| `exportToFile(path)` | Exporter toute la mémoire en JSON |
| `importFromFile(path)` | Importer depuis un fichier JSON |
| `getStats()` | Statistiques (compteurs, taille) |

---

## Nettoyage

| Méthode | Description |
|---|---|
| `clearAllMemory()` | Tout effacer (conversations + préférences + souvenirs) |
| `clearConversationHistory()` | Effacer l'historique uniquement |
| `clearMemories()` | Effacer les souvenirs uniquement |

---

## Configuration avancée

| Méthode | Défaut | Description |
|---|---|---|
| `setMaxConversations(n)` | 200 | Taille max du buffer conversations |
| `setMaxMemories(n)` | 500 | Nombre max de souvenirs |
| `setImportanceThreshold(t)` | 0.4 | Seuil min d'importance pour stockage auto |
| `setHalfLifeDays(d)` | 30 jours | Demi-vie pour la décroissance temporelle |

---

## Serveur sémantique (FAISS)

```cpp
void initSemanticServer(const QString &url = "ws://localhost:8771");
bool isSemanticConnected() const;
```

Connexion WebSocket vers `memory_server.py` pour la recherche vectorielle haute performance.

---

## Signaux

| Signal | Description |
|---|---|
| `memoryEnabledChanged()` | État mémoire changé |
| `conversationCountChanged()` | Nombre de conversations changé |
| `memoryCountChanged()` | Nombre de souvenirs changé |
| `conversationAdded(user, assistant)` | Nouvelle conversation ajoutée |
| `memoryAdded(id, text)` | Nouveau souvenir ajouté |
| `userPreferenceUpdated(key, value)` | Préférence mise à jour |

---

## Persistance

- **Format** : JSON v2 (`{ version, conversations, preferences, memories }`)
- **Emplacement** : `%APPDATA%/EXOAssistant/`
- **Sauvegarde** : debounce 2000 ms (évite les écritures excessives)

---
Retour à l'index : [docs/README.md](../README.md)
