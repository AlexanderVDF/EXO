> 🧭 [Index](../README.md) → [Archives](../README.md#-documents-historiques) → archives_index.md

# EXO — Archives Documentation Historique

<!-- TOC -->
## Table des matières

- [Prompts de conception v4.0](#prompts-de-conception-v40)
  - [GUI VS Code Style](#gui-vs-code-style)
  - [Visualizer Waveform](#visualizer-waveform)
  - [Pipeline STT/TTS](#pipeline-stttts)
- [Audit v4.0 — Rapport](#audit-v40-rapport)
  - [Inventaire vérifié](#inventaire-vérifié)
  - [Corrections appliquées](#corrections-appliquées)
  - [Build vérifié](#build-vérifié)
- [Plan d'implémentation v4.1](#plan-dimplémentation-v41)
  - [Objectifs réalisés](#objectifs-réalisés)
  - [Choix techniques](#choix-techniques)
- [Plan d'optimisation v4.1](#plan-doptimisation-v41)
  - [Machine cible](#machine-cible)
  - [Optimisations appliquées](#optimisations-appliquées)
- [Intégration Premium Open-Source v4.2](#intégration-premium-open-source-v42)
  - [Composants remplacés/ajoutés](#composants-remplacésajoutés)
- [Intégration XTTS v2](#intégration-xtts-v2)
  - [Architecture](#architecture)
  - [Protocole WebSocket](#protocole-websocket)
- [Intégration RtAudio](#intégration-rtaudio)
  - [Architecture](#architecture)
  - [Configuration](#configuration)
- [Instructions de réparation (historique)](#instructions-de-réparation-historique)
  - [Contexte](#contexte)
  - [Actions documentées](#actions-documentées)
- [Automatisation Documentation & CleanUp (mars 2026)](#automatisation-documentation-cleanup-mars-2026)
- [Nettoyage Global EXO (mars 2026)](#nettoyage-global-exo-mars-2026)
- [Refactoring Massif (mars 2026)](#refactoring-massif-mars-2026)
- [Intégration XTTS v2 DirectML (mars 2026)](#intégration-xtts-v2-directml-mars-2026)
- [Stabilisation & Anti-Doublons (mars 2026)](#stabilisation-anti-doublons-mars-2026)
  - [Stabilisation finale](#stabilisation-finale)
  - [Fix RAM & Doublons](#fix-ram-doublons)
- [Inventaire des fichiers d'archive](#inventaire-des-fichiers-darchive)
  - [Prompts historiques (supersédés par `docs/prompts/`)](#prompts-historiques-supersédés-par-docsprompts)
  - [Fichiers fusionnés (mars 2026)](#fichiers-fusionnés-mars-2026)

<!-- /TOC -->

Ce fichier regroupe les plans, audits et prompts historiques des versions 4.0 à 4.2.
Pour la documentation technique à jour, voir [EXO_DOCUMENTATION.md](../core/EXO_DOCUMENTATION.md).

---

---

## Prompts de conception v4.0

*Source : PROMPTS_V4.md — Prompts utilisés pour concevoir EXO v4.0*

### GUI VS Code Style
- Reconception complète de l'interface QML en style VS Code Dark
- 10 composants : Sidebar, StatusIndicator, MicrophoneLevel, TranscriptView, ResponseView, Visualizer, BottomBar,
SettingsPanel, HistoryPanel, LogPanel
- Palette : fond #1E1E1E, accent #007ACC, texte #E0E0E0
- Police : Cascadia Code / Fira Code / Consolas

### Visualizer Waveform
- ShaderEffect GLSL pour rendu GPU 60 FPS
- Signal `audioLevel(float rms, float vadScore)` depuis VoicePipeline
- Chaîne : VoicePipeline → MainWindow → BottomBar → Visualizer

### Pipeline STT/TTS
- Refonte complète du pipeline vocal (VoicePipeline v4)
- FSM 6 états : Idle → DetectingSpeech → Listening → Transcribing → Thinking → Speaking
- Double backend STT : Whisper.cpp (GPU) / faster-whisper (CPU)
- Cascade TTS : XTTS v2 (Python) → Qt TTS (fallback)
- DSP 5 étages : EQ → Compresseur → Normalisation → Fade → Anti-clip

---

## Audit v4.0 — Rapport

*Source : AUDIT_REPORT_V4.md — Audit réalisé en juillet 2025*

### Inventaire vérifié
- 8 modules C++ (AssistantManager, ConfigManager, ClaudeAPI, VoicePipeline, TTSManager, WeatherManager, AIMemoryManager,
LogManager)
- 10 fichiers QML actifs (MainWindow + 9 vscode/)
- 3 serveurs Python (stt_server, tts_server, exo_server)

### Corrections appliquées
- Signal `micLevel` bloqué à 0.0 → câblage `audioLevel(rms, vadScore)` corrigé
- Visualizer utilisait `Math.random()` → remplacé par signal audio réel
- CMakeLists.txt nettoyé (fichiers inexistants retirés)
- 15 fichiers QML legacy archivés

### Build vérifié
- Compilation 0 erreurs sur MSVC 2022 / Qt 6.9.3

---

## Plan d'implémentation v4.1

*Source : Plan_implémentation_V4.1.txt — Réalisé en mars 2026*
**Statut : ✅ TERMINÉ**

### Objectifs réalisés
1. **STT GPU** — Whisper.cpp + Vulkan (RTF 0.08–0.23 sur AMD RX 6750 XT)
2. **Dual backend STT** — whispercpp (GPU) / faster-whisper (CPU fallback)
3. **whisper_cpp.py** — Wrapper HTTP pour whisper-server.exe, auto-restart
4. **stt_server.py refactorisé** — Classe STTEngine dual-backend, filtre anti-hallucination
5. **VoicePipeline** — SPEECH_HANG_FRAMES=30 (~600ms), min utterance 2s
6. **Documentation alignée** — audioSamplesUpdated → audioLevel corrigé partout

### Choix techniques
- Vulkan retenu (vs DirectML) pour compatibilité AMD + performance
- Modèle small (244 Mo) retenu comme défaut (compromis vitesse/qualité)

---

## Plan d'optimisation v4.1

*Source : Plan_optimisation_EXO_v4.1.txt — Réalisé en mars 2026*
**Statut : ✅ TERMINÉ**

### Machine cible
- Intel i9-11900KF, 48 Go RAM, AMD Radeon RX 6750 XT
- Windows 11 Pro

### Optimisations appliquées
- **STT GPU** : Vulkan backend, beam_size=5, RTF < 0.25
- **Threading** : TTSManager worker dédié, async I/O
- **Pipeline FSM** : latence < 200ms entre états
- **Logging catégorisé** : VOICE, CLAUDE, CONFIG, WEATHER, ASSISTANT
- **Benchmark** : scripts/benchmark_stt.py (mesure RTF)

---

## Intégration Premium Open-Source v4.2

*Source : INTEGRATION_PREMIUM_OPEN-SOURCE.txt — Réalisé en mars 2026*
**Statut : ✅ TERMINÉ**

### Composants remplacés/ajoutés
| Ancien | Nouveau | Port |
|--------|---------|------|
| Legacy TTS | XTTS v2 (Coqui) | 8767 |
| VAD energy seul | Silero VAD neural (+ hybrid) | 8768 |
| — | OpenWakeWord neural | 8770 |
| noisereduce (CPU) | DSP noisereduce intégré STT | — |
| Mémoire regex seule | FAISS + SentenceTransformers | 8771 |
| — | NLU local (regex + transformers) | 8772 |
| Canvas CPU | ShaderEffect GLSL GPU 60 FPS | — |

---

## Intégration XTTS v2

*Source : INTEGRATION_XTTS.txt — Réalisé en mars 2026*
**Statut : ✅ TERMINÉ**

### Architecture
- `tts_server.py` encapsule Coqui XTTS v2 sur ws://localhost:8767
- 58 voix intégrées, 17 langues
- Streaming PCM16 avec contrôle pitch/rate/style
- Modèle auto-téléchargé (~1.87 Go dans ~/AppData/Local/tts/)

### Protocole WebSocket
```json
→ {"type":"synthesize","text":"Bonjour","voice":"Claribel Dervla","lang":"fr","pitch":1.0,"rate":1.0}
← Binary PCM16 chunks (16kHz, mono)
← {"type":"end"}
```

---

## Intégration RtAudio

*Source : Integration_TRAudio.txt — Réalisé en mars 2026*
**Statut : ✅ TERMINÉ**

### Architecture
- Couche d'abstraction `AudioInput` (app/audio/AudioInput.h)
- Backend Qt Multimedia : `AudioInputQt` (app/audio/AudioInputQt.h/.cpp)
- Backend RtAudio WASAPI : `AudioInputRtAudio` (app/audio/AudioInputRtAudio.h/.cpp)
- Compilé conditionnellement via `ENABLE_RTAUDIO` CMake option (ON par défaut)
- RtAudio intégré comme sous-répertoire statique (rtaudio/)

### Configuration
- `[Audio] backend=qt` ou `backend=rtaudio` dans assistant.conf
- ComboBox dans SettingsPanel.qml pour sélection dynamique

---

## Instructions de réparation (historique)

*Source : REPARATION.txt — Prompt de réparation utilisé après la migration SSD*

### Contexte
Après la migration des données de `J:\EXO\` vers `D:\EXO\` (SSD), plusieurs problèmes ont été détectés dans les logs
EXO. Un prompt de réparation exhaustif a été utilisé pour corriger l'ensemble des problèmes.

### Actions documentées
1. **Réparation TTS Python (XTTS v2)** — Vérification serveur ws://localhost:8767, correction chemins modèles vers
`D:\EXO\models\xtts\`, logs "TTS server ready", interdiction fallback Qt sauf erreur critique
2. **Correction des chemins SSD** — Migration complète de tous les serveurs Python vers `D:\EXO\` (STT, TTS, Wakeword,
FAISS, Logs, Cache HF, Whisper.cpp)
3. **Durcissement wakeword** — Seuil augmenté, correspondance exacte, interdiction déclenchement pendant phrase en
cours, mode strict si OpenWakeWord actif
4. **Stabilisation pipeline** — Prévention transitions prématurées, interdiction chevauchement STT/TTS, playback garanti
avec données audio, req_id cohérent
5. **Vérification port 8767** — Test connexion TTS explicite dans C++, logs clairs, retry propre avant fallback
6. **Test interaction météo** — Validation chaîne complète (wakeword → STT → NLU → Claude → TTS → playback)
7. **Mise à jour COPILOT_MASTER_DIRECTIVE** — Ajout règles TTS Python prioritaire, wakeword strict, chemins D:\EXO\
obligatoires

> **Statut** : ✅ APPLIQUÉ — Les corrections ont été intégrées dans les sections 8–12 de `COPILOT_MASTER_DIRECTIVE.md`.

---

## Automatisation Documentation & CleanUp (mars 2026)

*Source : AutomatisationDocCleanUp.md — Archivé le 21 mars 2026*
**Statut : ✅ IMPLÉMENTÉ**

Système de maintenance automatique implémenté :
1. `scripts/auto_maintain.py` — 6 commandes : scan, docs, clean, context, check, all
2. Hooks Git (pre-commit, post-commit) dans `scripts/hooks/`
3. `.exo_context/context.md` pour optimiser le contexte Copilot
4. `scripts/setup_maintenance.ps1` — Installation automatique

---

## Nettoyage Global EXO (mars 2026)

*Source : Nettoyage.md — Archivé le 21 mars 2026*
**Statut : ✅ EXÉCUTÉ**

Plan de nettoyage complet en 8 phases :
1. Environnement Windows (PATH, venvs, caches)
2. Dépôt (\_\_pycache\_\_, .pytest_cache, dirs vides, .gitignore)
3. Code C++ (includes inutilisés, conventions, warnings)
4. Code Python (modules morts, imports, dépendances)
5. QML (composants inutilisés, signaux non connectés)
6. Microservices (ports, URLs, préparation CUDA RTX 3070)
7. Documentation (régénération auto)
8. Intégration auto_maintain.py

---

## Refactoring Massif (mars 2026)

*Source : RefactoringMassif.md — Archivé le 21 mars 2026*
**Statut : ✅ RÉALISÉ (phases 1-3)**

Plan de refactoring structurant :
1. Réorganisation `app/` (core, audio, llm, utils) + `python/` (7 microservices)
2. Module WebSocket unifié (`WebSocketClient.h/.cpp`)
3. Backend TTS abstrait (`TTSBackend.h` + Qt/XTTS implémentations)
4. Conventions de nommage PascalCase/camelCase

---

## Intégration XTTS v2 DirectML (mars 2026)

*Source : INTÉGRATION XTTS v2 DIRECTML.md — Archivé le 21 mars 2026*
**Statut : ⚠️ OBSOLÈTE — Remplacé par XTTS v2 natif Windows (DirectML/CUDA)**

Plan initial d'intégration XTTS v2 avec ONNX Runtime DirectML pour AMD GPU.
AbandonnÃ© au profit de :
- Phase actuelle : XTTS v2 natif Windows (DirectML, port 8767)
- Phase future : XTTS v2 natif Windows + CUDA (RTX 3070 SUPRIM X)

---

## Stabilisation & Anti-Doublons (mars 2026)

*Sources : docs/archives/StabilisationFinale.md, CorrectionComplèteMicroservices.md, Fix_RAM_Doublons_Microservices.md,
Validation.md*
**Statut : ✅ TERMINÉ**

### Stabilisation finale
- Vérification complète des 7 microservices post-migration `src/` → `python/`
- Suppression WSL2/ROCm (scripts archivés dans `scripts/legacy_wsl2/`)
- Fix TTS CPU fallback (`.to("cpu")`), fix NLU protocole (`"action"` → `"type"`)
- Validation fonctionnelle des 8 ports (8765-8772)

### Fix RAM & Doublons
- Diagnostic : 21 processus zombies (14 Python + 7 whisper-server) = 8.7 GB RAM
- Protection : `python/shared/singleton_guard.py` — vérifie le port TCP avant chargement modèle
- 7/7 microservices protégés contre les doublons
- Script `scripts/auto_kill_zombies.py` pour nettoyage automatique (WMIC, `--kill`)
- Optimisation VS Code : `files.watcherExclude`, C++ intellisense limité
- Rapport détaillé : [fix_ram_doublons.md](../reports/fix_ram_doublons.md)

---

*Archives générées le 14 mars 2026 — EXO v4.2*
*Dernière mise à jour : 28 mars 2026 — Fusion des doublons documentaires*

---

## Inventaire des fichiers d'archive

> ℹ️ Ces fichiers sont conservés pour traçabilité. Les versions actives et maintenues se trouvent dans `docs/prompts/`, `docs/audits/` et `docs/reports/`.

### Prompts historiques (supersédés par `docs/prompts/`)

| Fichier archive | Remplacé par | Statut |
|----------------|--------------|--------|
| `AuditComplet_Prompt.md` | [prompt_audit_complet.md](../prompts/prompt_audit_complet.md) | 🔄 Supersédé |
| `CorrectionComplèteMicroservices.md` | [prompt_correction_microservices.md](../prompts/prompt_correction_microservices.md) | 🔄 Supersédé |
| `Fix_RAM_Doublons_Microservices.md` | [prompt_fix_ram_doublons.md](../prompts/prompt_fix_ram_doublons.md) | 🔄 Supersédé |
| `GestionMicro_Prompt.md` | [prompt_gestion_micro.md](../prompts/prompt_gestion_micro.md) | 🔄 Supersédé |
| `GUI_Release_Prompt.md` | [prompt_gui_release.md](../prompts/prompt_gui_release.md) | 🔄 Supersédé |
| `Reduction_STT_Prompt.md` | [prompt_reduction_stt.md](../prompts/prompt_reduction_stt.md) | 🔄 Supersédé |
| `RolePermanentMaitre_Prompt.md` | [prompt_role_permanent.md](../prompts/prompt_role_permanent.md) | 🔄 Supersédé |
| `StabilisationFinale.md` | [prompt_stabilisation_finale.md](../prompts/prompt_stabilisation_finale.md) | 🔄 Supersédé |
| `Validation.md` | [prompt_validation.md](../prompts/prompt_validation.md) | 🔄 Supersédé |

### Fichiers fusionnés (mars 2026)

| Fichier archive | Fusionné dans | Raison |
|----------------|---------------|--------|
| `audit_final_2025_07.md` | [audit_master_2026_03.md](../audits/audit_master_2026_03.md) (Annexe A) | Audit 2026 supersède + intègre les findings 2025 |
| `prompt_design_system.md` | [prompt_modernisation_ui.md](../prompts/prompt_modernisation_ui.md) | Chevauchement ~60% — fusionné en un seul prompt UI |
| `prompt_modernisation_ui_old.md` | [prompt_modernisation_ui.md](../prompts/prompt_modernisation_ui.md) | Version pré-fusion |

---
*Retour à l'index : [docs/README.md](../README.md)*
