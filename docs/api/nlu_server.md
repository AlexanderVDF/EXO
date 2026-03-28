# nlu_server — Natural Language Understanding Server

> Classification d'intentions par regex avec fallback transformer

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Intents supportés (8)](#intents-supportés-8)
- [Protocole WebSocket](#protocole-websocket)
  - [Messages entrants (Client → Serveur)](#messages-entrants-client-serveur)
  - [Messages sortants (Serveur → Client)](#messages-sortants-serveur-client)
- [Seuil de confiance](#seuil-de-confiance)
- [Dépendances](#dépendances)

<!-- /TOC -->

**Fichier** : `python/nlu/nlu_server.py`
**Port** : `8772`
**Protocole** : WebSocket (JSON)

---

## Description

Serveur NLU local qui classe les phrases utilisateur en intentions à l'aide de patterns regex. Si la confiance est
insuffisante, le résultat indique que Claude doit prendre le relais. Un backend transformer optionnel est disponible
pour les cas complexes.

---

## Intents supportés (8)

| Intent | Exemples de déclencheurs | Entités extraites |
|---|---|---|
| `weather` | "quel temps fait-il", "météo" | — |
| `time` | "quelle heure est-il" | — |
| `timer` | "minuteur 5 minutes" | `duration` |
| `home_control` | "allume la lumière du salon" | `room`, `device`, `action` |
| `music` | "joue de la musique" | — |
| `reminder` | "rappelle-moi de..." | — |
| `greeting` | "bonjour", "salut" | — |
| `goodbye` | "au revoir", "bonne nuit" | — |

---

## Protocole WebSocket

### Messages entrants (Client → Serveur)

**Classifier une phrase :**
```json
{
  "action": "classify",
  "text": "allume la lumière du salon"
}
```

**Ping :**
```json
{ "action": "ping" }
```

**Lister les intents :**
```json
{ "action": "list_intents" }
```

### Messages sortants (Serveur → Client)

**Résultat NLU :**
```json
{
  "type": "nlu_result",
  "intent": "home_control",
  "entities": {
    "room": "salon",
    "device": "lumière",
    "action": "allumer"
  },
  "confidence": 0.85,
  "use_claude": false,
  "engine": "regex"
}
```

Quand la confiance est trop basse :
```json
{
  "type": "nlu_result",
  "intent": "unknown",
  "entities": {},
  "confidence": 0.3,
  "use_claude": true,
  "engine": "regex"
}
```

**Pong :**
```json
{ "type": "pong" }
```

**Liste des intents :**
```json
{
  "type": "intents",
  "intents": ["weather", "time", "timer", "home_control", "music", "reminder", "greeting", "goodbye"]
}
```

**Erreur :**
```json
{
  "type": "error",
  "message": "Classification failed"
}
```

---

## Seuil de confiance

| Seuil | Comportement |
|---|---|
| ≥ 0.65 | Action directe (intent reconnu) |
| < 0.65 | `use_claude: true` — délégation au LLM |

---

## Dépendances

| Package | Usage |
|---|---|
| `websockets` | Serveur WebSocket |
| `re` | Patterns regex |
| `transformers` | Backend NLU optionnel |

---
Retour à l'index : [docs/README.md](../README.md)
