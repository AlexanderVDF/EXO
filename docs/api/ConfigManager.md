# ConfigManager

> Gestionnaire de configuration EXO v4 — 3 couches de priorité

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Propriétés QML](#propriétés-qml)
- [Initialisation](#initialisation)
- [API générique (lecture)](#api-générique-lecture)
- [API générique (écriture)](#api-générique-écriture)
- [Raccourcis API](#raccourcis-api)
  - [Clés API](#clés-api)
  - [Paramètres courants](#paramètres-courants)
  - [Paramètres STT / TTS / VAD](#paramètres-stt-tts-vad)
- [Géolocalisation](#géolocalisation)
- [Thèmes UI](#thèmes-ui)
- [Signaux](#signaux)
- [Valeurs par défaut](#valeurs-par-défaut)

<!-- /TOC -->

**Fichier** : `app/core/ConfigManager.h` / `.cpp`
**Module** : Core
**Hérite de** : `QObject`

---

## Description

`ConfigManager` centralise toute la configuration d'EXO avec un système à 3 couches de priorité (haute → basse) :

1. **Variables d'environnement** (`.env` chargé au démarrage)
2. **Préférences utilisateur** (`user_config.ini`)
3. **Configuration par défaut** (`assistant.conf`)

L'écriture se fait toujours dans `user_config.ini`. Les lectures traversent les 3 couches.

---

## Propriétés QML

| Propriété | Type | Description |
|---|---|---|
| `loaded` | `bool` | Configuration chargée avec succès |
| `currentTheme` | `QString` | Thème UI actif (lecture/écriture) |

---

## Initialisation

```cpp
bool loadConfiguration(const QString &configPath = "config/assistant.conf");
```

Charge les 3 couches de configuration. Retourne `true` en cas de succès.

---

## API générique (lecture)

| Méthode | Retour | Description |
|---|---|---|
| `getString(section, key, default)` | `QString` | Valeur string |
| `getInt(section, key, default)` | `int` | Valeur entière |
| `getDouble(section, key, default)` | `double` | Valeur flottante |
| `getBool(section, key, default)` | `bool` | Valeur booléenne |

Toutes respectent l'ordre de priorité : `.env` > `user_config.ini` > `assistant.conf`.

## API générique (écriture)

```cpp
Q_INVOKABLE void setUserValue(const QString &section,
                               const QString &key,
                               const QVariant &value);
```

Écrit toujours dans `user_config.ini`.

---

## Raccourcis API

### Clés API

| Getter | Setter | Description |
|---|---|---|
| `getClaudeApiKey()` | `setClaudeApiKey(key)` | Clé Anthropic |
| `getClaudeModel()` | `setClaudeModel(model)` | Modèle Claude |
| `getWeatherApiKey()` | `setWeatherApiKey(key)` | Clé OpenWeatherMap |

### Paramètres courants

| Getter | Setter | Description |
|---|---|---|
| `getWeatherCity()` | `setWeatherCity(city)` | Ville météo |
| `getWakeWord()` | `setWakeWord(word)` | Mot de réveil |
| `getWeatherUpdateInterval()` | `setWeatherUpdateInterval(min)` | Intervalle météo (minutes) |

### Paramètres STT / TTS / VAD

| Getter | Setter | Description |
|---|---|---|
| `getSTTServerUrl()` | `setSTTServerUrl(url)` | URL du serveur STT |
| `getTTSServerUrl()` | `setTTSServerUrl(url)` | URL du serveur TTS |
| `getGUIServerUrl()` | — | URL du serveur GUI |
| `getSTTModel()` | — | Modèle STT |
| `getSTTLanguage()` | — | Langue STT |
| `getSTTBeamSize()` | — | Beam size STT |
| `getTTSVoice()` | `setTTSVoice(voice)` | Voix TTS |
| `getTTSEngine()` | `setTTSEngine(engine)` | Moteur TTS |
| `getTTSLanguage()` | — | Langue TTS |
| `getVADBackend()` | — | Backend VAD |
| `getVADThreshold()` | — | Seuil VAD |

---

## Géolocalisation

| Méthode | Description |
|---|---|
| `detectLocation()` | Détection automatique de la ville par IP |
| `isLocationDetectionEnabled()` | Détection activée ? |
| `setLocationDetectionEnabled(enabled)` | Activer/désactiver |
| `getCurrentLocation()` | Ville détectée |

---

## Thèmes UI

| Méthode | Description |
|---|---|
| `getAvailableThemes()` | Liste des thèmes disponibles |
| `getCurrentTheme()` | Thème actuel |
| `setCurrentTheme(name)` | Changer de thème |
| `getThemeColors(name)` | Palette de couleurs d'un thème |
| `saveCustomTheme(name, colors)` | Sauvegarder un thème personnalisé |
| `deleteCustomTheme(name)` | Supprimer un thème personnalisé |
| `isCustomTheme(name)` | Thème personnalisé ou prédéfini ? |

---

## Signaux

| Signal | Paramètres | Description |
|---|---|---|
| `configurationLoaded` | — | Configuration chargée avec succès |
| `configurationError` | `error: QString` | Erreur de chargement |
| `weatherConfigChanged` | `city, apiKey` | Configuration météo modifiée |
| `locationDetected` | `city, country` | Géolocalisation réussie |
| `locationDetectionError` | `error: QString` | Erreur de géolocalisation |
| `themeChanged` | `themeName, colors` | Thème UI changé |

---

## Valeurs par défaut

| Constante | Valeur |
|---|---|
| `DEFAULT_WAKE_WORD` | `"Exo"` |
| `DEFAULT_WEATHER_CITY` | `"Paris"` |
| `DEFAULT_CLAUDE_MODEL` | `"claude-sonnet-4-20250514"` |
| `DEFAULT_VOICE_LANGUAGE` | `"fr-FR"` |
| `DEFAULT_STT_SERVER_URL` | `"ws://localhost:8766"` |
| `DEFAULT_TTS_SERVER_URL` | `"ws://localhost:8767"` |
| `DEFAULT_GUI_SERVER_URL` | `"ws://localhost:8765"` |
| `DEFAULT_STT_MODEL` | `"large-v3"` |
| `DEFAULT_TTS_VOICE` | `"Claribel Dervla"` |
| `DEFAULT_TTS_ENGINE` | `"xtts_directml"` |
| `DEFAULT_VAD_BACKEND` | `"builtin"` |
| `DEFAULT_VAD_THRESHOLD` | `0.45` |

---
Retour à l'index : [docs/README.md](../README.md)
