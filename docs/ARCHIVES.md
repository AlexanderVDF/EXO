# EXO — Archives Documentation Historique

Ce fichier regroupe les plans, audits et prompts historiques des versions 4.0 à 4.2.
Pour la documentation technique à jour, voir [EXO_DOCUMENTATION.md](EXO_DOCUMENTATION.md).

---

## Table des matières

1. [Prompts de conception v4.0](#prompts-de-conception-v40)
2. [Audit v4.0 — Rapport](#audit-v40--rapport)
3. [Plan d'implémentation v4.1](#plan-dimplémentation-v41)
4. [Plan d'optimisation v4.1](#plan-doptimisation-v41)
5. [Intégration Premium Open-Source v4.2](#intégration-premium-open-source-v42)
6. [Intégration XTTS v2](#intégration-xtts-v2)
7. [Intégration RtAudio](#intégration-rtaudio)

---

## Prompts de conception v4.0

*Source : PROMPTS_V4.md — Prompts utilisés pour concevoir EXO v4.0*

### GUI VS Code Style
- Reconception complète de l'interface QML en style VS Code Dark
- 10 composants : Sidebar, StatusIndicator, MicrophoneLevel, TranscriptView, ResponseView, Visualizer, BottomBar, SettingsPanel, HistoryPanel, LogPanel
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
- 8 modules C++ (AssistantManager, ConfigManager, ClaudeAPI, VoicePipeline, TTSManager, WeatherManager, AIMemoryManager, LogManager)
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
- Couche d'abstraction `AudioInput` (src/audio/audioinput.h)
- Backend Qt Multimedia : `AudioInputQt` (audioinput_qt.h/.cpp)
- Backend RtAudio WASAPI : `AudioInputRtAudio` (audioinput_rtaudio.h/.cpp)
- Compilé conditionnellement via `ENABLE_RTAUDIO` CMake option (ON par défaut)
- RtAudio intégré comme sous-répertoire statique (rtaudio/)

### Configuration
- `[Audio] backend=qt` ou `backend=rtaudio` dans assistant.conf
- ComboBox dans SettingsPanel.qml pour sélection dynamique

---

## Instructions de réparation (historique)

*Source : REPARATION.txt — Prompt de réparation utilisé après la migration SSD*

### Contexte
Après la migration des données de `J:\EXO\` vers `D:\EXO\` (SSD), plusieurs problèmes ont été détectés dans les logs EXO. Un prompt de réparation exhaustif a été utilisé pour corriger l'ensemble des problèmes.

### Actions documentées
1. **Réparation TTS Python (XTTS v2)** — Vérification serveur ws://localhost:8767, correction chemins modèles vers `D:\EXO\models\xtts\`, logs "TTS server ready", interdiction fallback Qt sauf erreur critique
2. **Correction des chemins SSD** — Migration complète de tous les serveurs Python vers `D:\EXO\` (STT, TTS, Wakeword, FAISS, Logs, Cache HF, Whisper.cpp)
3. **Durcissement wakeword** — Seuil augmenté, correspondance exacte, interdiction déclenchement pendant phrase en cours, mode strict si OpenWakeWord actif
4. **Stabilisation pipeline** — Prévention transitions prématurées, interdiction chevauchement STT/TTS, playback garanti avec données audio, req_id cohérent
5. **Vérification port 8767** — Test connexion TTS explicite dans C++, logs clairs, retry propre avant fallback
6. **Test interaction météo** — Validation chaîne complète (wakeword → STT → NLU → Claude → TTS → playback)
7. **Mise à jour COPILOT_MASTER_DIRECTIVE** — Ajout règles TTS Python prioritaire, wakeword strict, chemins D:\EXO\ obligatoires

> **Statut** : ✅ APPLIQUÉ — Les corrections ont été intégrées dans les sections 8–12 de `COPILOT_MASTER_DIRECTIVE.md`.

---

*Archives générées le 14 mars 2026 — EXO v4.2*  
*Dernière mise à jour : consolidation documentation*
