# WeatherManager

> Gestionnaire météorologique via OpenWeatherMap API

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Propriétés QML](#propriétés-qml)
- [Configuration](#configuration)
- [Méthodes Q_INVOKABLE](#méthodes-q_invokable)
- [Signaux](#signaux)
- [Mise à jour automatique](#mise-à-jour-automatique)

<!-- /TOC -->

**Fichier** : `app/utils/WeatherManager.h` / `.cpp`
**Module** : Utils
**Hérite de** : `QObject`

---

## Description

`WeatherManager` fournit les données météorologiques en temps réel via l'API OpenWeatherMap. Il gère les conditions
actuelles, les prévisions sur 5 jours, les conseils vestimentaires automatiques et les alertes météo. Les données sont
exposées au QML via des propriétés réactives.

---

## Propriétés QML

| Propriété | Type | Description |
|---|---|---|
| `currentWeather` | `QString` | Condition météo actuelle (ex : "Ensoleillé") |
| `temperature` | `QString` | Température formatée |
| `humidity` | `QString` | Humidité relative |
| `windSpeed` | `QString` | Vitesse du vent |
| `description` | `QString` | Description détaillée |
| `clothingAdvice` | `QString` | Conseil vestimentaire automatique |
| `isLoading` | `bool` | Requête réseau en cours |
| `city` | `QString` | Ville configurée (lecture/écriture) |

---

## Configuration

| Méthode | Description |
|---|---|
| `setApiKey(apiKey)` | Clé API OpenWeatherMap |
| `setCity(city)` | Définir la ville |
| `initialize()` | Lancer le timer de mise à jour automatique |

---

## Méthodes Q_INVOKABLE

| Méthode | Retour | Description |
|---|---|---|
| `updateWeather()` | — | Forcer une mise à jour des conditions actuelles |
| `getForecast()` | — | Récupérer les prévisions 5 jours |
| `getWeatherSummary()` | `QString` | Résumé textuel complet de la météo |
| `getClothingAdvice()` | `QString` | Conseil vestimentaire basé sur les conditions |
| `handleVoiceCommand(command)` | `QString` | Traiter une commande vocale météo |

---

## Signaux

| Signal | Paramètres | Description |
|---|---|---|
| `weatherUpdated` | — | Données météo mises à jour |
| `forecastReceived` | `forecast: QJsonObject` | Prévisions reçues |
| `loadingStateChanged` | — | Changement d'état de chargement |
| `cityChanged` | — | Ville modifiée |
| `weatherError` | `error: QString` | Erreur de requête météo |
| `weatherResponse` | `response: QString` | Réponse formatée |

---

## Mise à jour automatique

- **Intervalle** : 10 minutes (`UPDATE_INTERVAL_MS = 600000`)
- **API** : `https://api.openweathermap.org/data/2.5`
- Les mises à jour sont automatiques après `initialize()`

---
Retour à l'index : [docs/README.md](../README.md)
