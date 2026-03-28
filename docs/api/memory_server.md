# memory_server — Semantic Memory Server

> Mémoire sémantique FAISS avec recherche vectorielle

<!-- TOC -->
## Table des matières

- [Description](#description)
  - [Modèle d'embedding](#modèle-dembedding)
- [Protocole WebSocket](#protocole-websocket)
  - [Messages entrants (Client → Serveur)](#messages-entrants-client-serveur)
  - [Messages sortants (Serveur → Client)](#messages-sortants-serveur-client)
- [Persistance](#persistance)
- [Limites et éviction](#limites-et-éviction)
- [Dépendances](#dépendances)

<!-- /TOC -->

**Fichier** : `python/memory/memory_server.py`
**Port** : `8771`
**Protocole** : WebSocket (JSON)

---

## Description

Serveur de mémoire sémantique utilisant FAISS pour l'indexation vectorielle et SentenceTransformers pour l'encodage des
embeddings. Permet au C++ (`AIMemoryManager`) de stocker et rechercher des souvenirs par similarité sémantique.

### Modèle d'embedding

| Paramètre | Valeur |
|---|---|
| Modèle | `all-MiniLM-L6-v2` |
| Dimensions | 384 |
| Cache | `$HF_HOME` |

---

## Protocole WebSocket

### Messages entrants (Client → Serveur)

**Ajouter un souvenir :**
```json
{
  "action": "add",
  "text": "L'utilisateur préfère la musique classique",
  "importance": 0.8,
  "tags": ["preference", "music"],
  "source": "conversation",
  "category": "preference"
}
```

**Rechercher par similarité :**
```json
{
  "action": "search",
  "query": "musique",
  "top_k": 5,
  "min_score": 0.3
}
```

**Supprimer :**
```json
{
  "action": "remove",
  "id": "uuid-..."
}
```

**Lister tous :**
```json
{ "action": "list" }
```

**Vider :**
```json
{ "action": "clear" }
```

**Statistiques :**
```json
{ "action": "stats" }
```

### Messages sortants (Serveur → Client)

**Prêt :**
```json
{ "type": "ready" }
```

**Souvenir ajouté :**
```json
{
  "type": "added",
  "id": "uuid-...",
  "total": 42
}
```

**Résultats de recherche :**
```json
{
  "type": "results",
  "results": [
    {
      "id": "uuid-...",
      "text": "L'utilisateur préfère la musique classique",
      "score": 0.89,
      "importance": 0.8,
      "tags": ["preference", "music"],
      "timestamp": "2025-01-15T10:30:00"
    }
  ]
}
```

**Supprimé :**
```json
{
  "type": "removed",
  "id": "uuid-..."
}
```

**Statistiques :**
```json
{
  "type": "stats",
  "total_memories": 42,
  "index_size": 384,
  "disk_usage_mb": 1.2
}
```

**Erreur :**
```json
{
  "type": "error",
  "message": "Memory not found"
}
```

---

## Persistance

| Fichier | Emplacement |
|---|---|
| Index FAISS | `$EXO_FAISS_DIR/embeddings.faiss` |
| Métadonnées | `$EXO_FAISS_DIR/metadata.json` |

Défaut : `D:\EXO\faiss\semantic_memory/`

---

## Limites et éviction

| Paramètre | Valeur |
|---|---|
| Capacité max | 10 000 souvenirs |
| Stratégie d'éviction | `importance × recency` |

Quand la capacité maximale est atteinte, les souvenirs les moins importants et les plus anciens sont supprimés.

---

## Dépendances

| Package | Usage |
|---|---|
| `websockets` | Serveur WebSocket |
| `faiss-cpu` | Index vectoriel |
| `sentence-transformers` | Encodage des embeddings |
| `numpy` | Manipulation de vecteurs |

---
Retour à l'index : [docs/README.md](../README.md)
