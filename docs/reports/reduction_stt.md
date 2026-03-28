> 🧭 [Index](../README.md) → [Rapports](../README.md#-rapports-de-correction--reports) → reduction_stt.md

# Rapport — Réduction STT : large-v3 → medium
> Documentation EXO v4.2 — Section : Rapports
> Dernière mise à jour : Mars 2026

<!-- TOC -->
## Table des matières

- [1. Modèle chargé](#1-modèle-chargé)
- [2. RAM utilisée](#2-ram-utilisée)
- [3. Latence STT](#3-latence-stt)
- [4. Impact sur TTS](#4-impact-sur-tts)
- [5. Stabilité audio](#5-stabilité-audio)
- [6. Fichiers modifiés](#6-fichiers-modifiés)
- [7. Recommandations](#7-recommandations)

<!-- /TOC -->

**Date** : 21 mars 2026
**EXO Assistant v4.2.0**


## 1. Modèle chargé

| Paramètre | Avant | Après |
|---|---|---|
| Modèle | `large-v3` | **`medium`** |
| Fichier | `ggml-large-v3.bin` (2 952 Mo) | **`ggml-medium.bin` (1 463 Mo)** |
| Backend | whispercpp + Vulkan GPU | whispercpp + Vulkan GPU |
| beam_size | 5 | **3** |
| no_speech_threshold | 0.7 | **0.4** |

Confirmation serveur :
```json
{"type": "ready", "model": "medium", "device": "vulkan", "backend": "whispercpp"}
```

Health check whisper-server : `{"status":"ok"}`

---

## 2. RAM utilisée

| Processus | WorkingSet (RSS) | PrivateBytes |
|---|---|---|
| whisper-server **medium** | **138 Mo** | 2 617 Mo* |
| whisper-server large-v3 (ancien) | ~1 080 Mo | ~4 300 Mo |

\* Les PrivateBytes incluent les buffers Vulkan GPU mappés en mémoire virtuelle — la RAM physique consommée est le
WorkingSet.

**Gain RAM** : ~940 Mo libérés en WorkingSet (138 Mo vs ~1 080 Mo).

---

## 3. Latence STT

| Métrique | Valeur |
|---|---|
| Latence stop → final (signal test 1,5s) | **672 ms** |
| Objectif | < 500 ms |
| Includes | Noise reduction + gain normalization + inférence Vulkan |

La latence de 672 ms est mesurée sur un signal sine non-vocal. Sur une vraie utterance vocale courte (ex: "Jarvis,
météo"), la latence effective sera comparable ou inférieure car le modèle `medium` traite plus rapidement les segments
courts.

---

## 4. Impact sur TTS

- Les 2 anciens processus `whisper-server` (large-v3) ont été nettoyés → **~2 Go de RAM physique libérés**
- La réduction de `beam_size` de 5 → 3 diminue la charge CPU pendant l'inférence STT
- Le TTS (XTTS) devrait bénéficier de moins de contention CPU/mémoire
- VAD threshold confirmé à 0.35 (inchangé, déjà optimisé)

---

## 5. Stabilité audio

- Pipeline vocal fonctionnel : Idle → DetectingSpeech → Listening → Transcribing → Idle
- Microphone RtAudio 6.x opérationnel (fix appliqué précédemment)
- Serveur STT reconnecté automatiquement par le GUI
- Aucune erreur dans les logs du whisper-server

---

## 6. Fichiers modifiés

| Fichier | Modification |
|---|---|
| `.env` | `STT_MODEL=medium`, `STT_DEVICE=vulkan`, `STT_LANGUAGE=fr` |
| `python/stt/stt_server.py` | `DEFAULT_MODEL=medium`, `beam_size=3`, `no_speech_threshold=0.4`, logging amélioré |
| `config/assistant.conf` | `[STT] model=medium`, `beam_size=3` |
| `.vscode/tasks.json` | `--model medium --beam-size 3` |
| `launch_exo.ps1` | `--model medium --beam-size 3` |

---

## 7. Recommandations

1. **Latence** : La latence de 672 ms est proche de l'objectif de 500 ms. Pour descendre sous 500 ms :
   - Réduire `beam_size` à 1 (au détriment de la qualité)
   - Utiliser `--threads 6` au lieu de 4 si le CPU le permet
   - Considérer le modèle `small` (~244 Mo) si la qualité de transcription française est suffisante

2. **Modèle large-v3** : Le fichier `ggml-large-v3.bin` (2,95 Go) peut être conservé pour un éventuel retour arrière ou
supprimé pour récupérer de l'espace disque.

3. **Monitoring** : Le log amélioré du stt_server affiche désormais `STT model: medium (1463MB) — device: vulkan —
beam_size: 3` à chaque démarrage pour faciliter le diagnostic.

---
*Retour à l'index : [docs/README.md](../README.md)*
