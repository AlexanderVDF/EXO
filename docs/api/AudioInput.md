# AudioInput

> Interface abstraite de capture audio + implémentations Qt et RtAudio

<!-- TOC -->
## Table des matières

- [Description](#description)
- [Interface abstraite : AudioInput](#interface-abstraite-audioinput)
- [AudioInputQt](#audioinputqt)
- [AudioInputRtAudio](#audioinputrtaudio)
- [AudioDeviceManager](#audiodevicemanager)
  - [Propriétés QML](#propriétés-qml)
  - [Méthodes Q_INVOKABLE](#méthodes-q_invokable)
  - [Méthodes internes (VoicePipeline)](#méthodes-internes-voicepipeline)
  - [Signaux](#signaux)

<!-- /TOC -->

**Fichiers** : `app/audio/AudioInput.h`, `AudioInputQt.h`, `AudioInputRtAudio.h`
**Module** : Audio
**Hérite de** : `QObject`

---

## Description

`AudioInput` définit l'interface abstraite pour la capture audio microphone. Deux implémentations sont fournies :
`AudioInputQt` (via Qt Multimedia) et `AudioInputRtAudio` (via RtAudio/WASAPI, low-latency). Le choix du backend est
fait au runtime par `VoicePipeline`.

---

## Interface abstraite : AudioInput

```cpp
class AudioInput : public QObject
{
    using AudioCallback = std::function<void(const int16_t *samples, int count)>;

    virtual bool open(int sampleRate, int channels) = 0;
    virtual bool start() = 0;
    virtual void stop() = 0;
    virtual void suspend() = 0;
    virtual void resume() = 0;
    virtual bool isRunning() const = 0;
    virtual QString backendName() const = 0;

    void setCallback(AudioCallback cb);
};
```

| Méthode | Description |
|---|---|
| `open(sampleRate, channels)` | Ouvrir le flux audio avec les paramètres donnés |
| `start()` | Démarrer la capture |
| `stop()` | Arrêter la capture |
| `suspend()` / `resume()` | Pause/reprise sans fermer le flux |
| `isRunning()` | État de la capture |
| `backendName()` | Identifiant du backend (`"qt"` ou `"rtaudio"`) |
| `setCallback(cb)` | Définir le callback appelé pour chaque chunk audio |

**Signal** : `error(msg: QString)`

---

## AudioInputQt

Backend Qt Multimedia (`QAudioSource`).

- **Nom** : `"qt"`
- **Mécanisme** : `QAudioSource` → `QIODevice::readyRead()` → callback
- **Plateformes** : Windows, Linux, macOS
- **Latence** : Moyenne (~50-100 ms)

---

## AudioInputRtAudio

Backend RtAudio/WASAPI (low-latency).

- **Nom** : `"rtaudio"`
- **Mécanisme** : Callback RtAudio sur thread interne → dispatch vers callback pipeline
- **Plateformes** : Windows (WASAPI shared mode)
- **Latence** : Faible (~20-30 ms)
- **Compilation** : Nécessite `ENABLE_RTAUDIO` défini dans CMake
- **Buffer** : 512 frames par défaut

---

## AudioDeviceManager

> Gestion complète des microphones avec health check et test audio

**Fichier** : `app/audio/AudioDeviceManager.h` / `.cpp`

### Propriétés QML

| Propriété | Type | Description |
|---|---|---|
| `inputDevices` | `QStringList` | Liste des noms de microphones disponibles |
| `selectedDeviceIndex` | `int` | Index du micro sélectionné |
| `defaultInputDevice` | `int` | Index du micro par défaut |
| `hasValidInputDevice` | `bool` | Un micro valide est-il disponible ? |
| `lastError` | `QString` | Dernière erreur audio |
| `audioStatus` | `QString` | `"healthy"` / `"down"` / `"unknown"` |
| `currentRmsLevel` | `float` | Niveau RMS actuel (VU-mètre) |
| `audioTestRunning` | `bool` | Test audio en cours ? |

### Méthodes Q_INVOKABLE

| Méthode | Description |
|---|---|
| `scanDevices()` | Scanner tous les périphériques d'entrée RtAudio |
| `setInputDevice(index)` | Sélectionner un micro par index |
| `startAudioTest()` | Lancer le test audio (1s enregistrement + lecture) |
| `stopAudioTest()` | Arrêter le test audio |
| `openWindowsSoundSettings()` | Ouvrir les paramètres son de Windows |

### Méthodes internes (VoicePipeline)

| Méthode | Description |
|---|---|
| `selectedRtAudioDeviceId()` | ID RtAudio du micro sélectionné |
| `startHealthCheck(intervalMs)` | Démarrer la surveillance périodique |
| `feedRmsSamples(samples, count)` | Mettre à jour le RMS (thread-safe) |
| `notifyStreamOpened()` / `notifyStreamClosed()` | Notifier l'état du flux |

### Signaux

| Signal | Description |
|---|---|
| `devicesChanged()` | Liste des micros mise à jour |
| `inputDeviceChanged()` | Micro sélectionné changé |
| `audioError(error)` | Erreur audio |
| `audioStatusChanged()` | Changement de statut (`healthy`/`down`) |
| `rmsLevelChanged()` | Niveau VU-mètre mis à jour |
| `audioTestFinished(success)` | Test audio terminé |
| `audioUnavailable()` / `audioReady()` | Disponibilité du flux audio |
| `deviceSwitchRequested(id)` | Demande de changement de micro |

---
Retour à l'index : [docs/README.md](../README.md)
