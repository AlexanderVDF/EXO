# HealthCheck

> Surveillance de santé des microservices par ping WebSocket

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Énumérations](#énumérations)
  - [ServiceHealth](#servicehealth)
  - [OverallHealth](#overallhealth)
- [Propriétés QML](#propriétés-qml)
- [Méthodes Q_INVOKABLE](#méthodes-q_invokable)
- [Signaux](#signaux)
- [Seuils de latence](#seuils-de-latence)

<!-- /TOC -->

**Fichier** : `app/core/HealthCheck.h` / `.cpp`
**Module** : Core
**Hérite de** : `QObject`

---

## Description

`HealthCheck` surveille périodiquement la santé de chaque microservice Python en envoyant des pings WebSocket et en
mesurant la latence de réponse. Les résultats sont exposés via des propriétés QML pour un affichage temps-réel dans
l'interface.

---

## Énumérations

### ServiceHealth

| Valeur | Description |
|---|---|
| `Unknown` | État inconnu (pas encore testé) |
| `Healthy` | Réponse < 2 000 ms |
| `Degraded` | Réponse entre 2 000 et 5 000 ms |
| `Down` | Pas de réponse ou timeout > 5 000 ms |

### OverallHealth

| Valeur | Description |
|---|---|
| `Unknown` | Pas encore évalué |
| `AllHealthy` | Tous les services `Healthy` |
| `Degraded` | Au moins un service `Degraded` |
| `Critical` | Au moins un service `Down` |

---

## Propriétés QML

| Propriété | Type | Description |
|---|---|---|
| `sttStatus` | `ServiceHealth` | Santé du service STT (port 8766) |
| `ttsStatus` | `ServiceHealth` | Santé du service TTS (port 8767) |
| `vadStatus` | `ServiceHealth` | Santé du service VAD (port 8768) |
| `wakewordStatus` | `ServiceHealth` | Santé du service WakeWord (port 8770) |
| `memoryStatus` | `ServiceHealth` | Santé du service Memory (port 8771) |
| `nluStatus` | `ServiceHealth` | Santé du service NLU (port 8772) |
| `overallStatus` | `OverallHealth` | État de santé global |
| `allHealthy` | `bool` | Tous les services sont sains ? |

---

## Méthodes Q_INVOKABLE

| Méthode | Description |
|---|---|
| `start(intervalMs)` | Démarrer la surveillance périodique |
| `stop()` | Arrêter la surveillance |
| `checkNow()` | Vérification immédiate de tous les services |

---

## Signaux

| Signal | Paramètres | Description |
|---|---|---|
| `healthChanged` | — | Changement d'état de santé |
| `serviceDown` | `serviceName: QString` | Un service est tombé |
| `serviceRecovered` | `serviceName: QString` | Un service est remonté |

---

## Seuils de latence

| Seuil | Valeur | Résultat |
|---|---|---|
| Réponse rapide | < 2 000 ms | `Healthy` |
| Réponse lente | 2 000 – 5 000 ms | `Degraded` |
| Timeout | > 5 000 ms | `Down` |

---
Retour à l'index : [docs/README.md](../README.md)
