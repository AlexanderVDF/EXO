> 🧭 [Index](README.md) → VERSIONS.md

# Documentation Versions — EXO

> Historique complet des versions documentaires du projet EXO Assistant.
> Dernière mise à jour : 28 mars 2026

---

<!-- TOC -->
## Table des matières

- [Version actuelle : v4.2](#version-actuelle-v42)
- [v4.2 — Premium Open-Source Edition (mars 2026)](#v42-premium-open-source-edition-mars-2026)
  - [Résumé des changements](#résumé-des-changements)
  - [Fichiers ajoutés](#fichiers-ajoutés)
  - [Fichiers modifiés](#fichiers-modifiés)
  - [Fichiers archivés](#fichiers-archivés)
  - [Prompts maîtres utilisés](#prompts-maîtres-utilisés)
  - [Audits réalisés](#audits-réalisés)
- [v4.1 — GPU + Optimisation (mars 2026)](#v41-gpu-optimisation-mars-2026)
  - [Résumé des changements](#résumé-des-changements)
  - [Fichiers ajoutés](#fichiers-ajoutés)
  - [Fichiers modifiés](#fichiers-modifiés)
  - [Fichiers archivés](#fichiers-archivés)
  - [Prompts maîtres utilisés](#prompts-maîtres-utilisés)
  - [Audits réalisés](#audits-réalisés)
- [v4.0 — Refonte complète (juillet 2025)](#v40-refonte-complète-juillet-2025)
  - [Résumé des changements](#résumé-des-changements)
  - [Fichiers ajoutés](#fichiers-ajoutés)
  - [Fichiers modifiés](#fichiers-modifiés)
  - [Fichiers archivés](#fichiers-archivés)
  - [Prompts maîtres utilisés](#prompts-maîtres-utilisés)
  - [Audits réalisés](#audits-réalisés)
- [Prochaine version : v4.3 (préparation)](#prochaine-version-v43-préparation)
  - [Objectifs planifiés](#objectifs-planifiés)
  - [Fichiers probables à créer](#fichiers-probables-à-créer)
  - [Fichiers probables à archiver](#fichiers-probables-à-archiver)

<!-- /TOC -->

## 🟢 Version actuelle : v4.2

> **EXO Assistant v4.2 "Premium Open-Source Edition"**
> Branche : `main` · Date : 28 mars 2026

---

## v4.2 — Premium Open-Source Edition (mars 2026)

### Résumé des changements

Remplacement complet de la stack audio par des composants open-source premium.
Ajout de la mémoire sémantique FAISS, du NLU local, du wakeword neural.
Migration SSD `J:\EXO\` → `D:\EXO\`. Refactoring massif de l'arborescence.
Réorganisation complète de `docs/` en 7 catégories avec navigation interne.
Fix audio (crackling, saccades), fix RAM & doublons, réduction STT.

### Fichiers ajoutés

| Fichier | Catégorie |
|---------|-----------|
| [EXO_SPEC.md](core/EXO_SPEC.md) | core — spécification officielle v4.2 |
| [limitations.md](core/limitations.md) | core — limitations connues |
| [architecture_graph.md](core/architecture_graph.md) | core — graphe dépendances *(auto-généré)* |
| [architecture_modules.md](core/architecture_modules.md) | core — diagramme modules C++ |
| [pipeline.md](core/pipeline.md) | core — événements pipeline *(auto-généré)* |
| [services.md](core/services.md) | core — index microservices *(auto-généré)* |
| [modules.md](core/modules.md) | core — index modules *(auto-généré)* |
| [audio_pipeline.md](guides/audio_pipeline.md) | guides — pipeline audio complet |
| [stt.md](guides/stt.md) | guides — Speech-to-Text |
| [tts.md](guides/tts.md) | guides — Text-to-Speech |
| [tests.md](guides/tests.md) | guides — tests (180 tests) |
| [design_system.md](ui/design_system.md) | ui — Design System v4.2 |
| [audit_master_2026_03.md](audits/audit_master_2026_03.md) | audits — audit maître mars 2026 |
| [fix_ram_doublons.md](reports/fix_ram_doublons.md) | reports — fix RAM & doublons |
| [reduction_stt.md](reports/reduction_stt.md) | reports — réduction modèle STT |
| [last_update.md](reports/last_update.md) | reports — dernière mise à jour |
| 12 fichiers `prompt_*.md` | prompts — historique sessions Copilot |
| [archives_index.md](archives/archives_index.md) | archives — index consolidé |
| [VERSIONS.md](VERSIONS.md) | racine — ce fichier |
| [README.md](README.md) | racine — index documentaire |

### Fichiers modifiés

| Fichier | Changement |
|---------|------------|
| [architecture.md](core/architecture.md) | Mise à jour 7 microservices, ports 8765-8772 |
| [EXO_DOCUMENTATION.md](core/EXO_DOCUMENTATION.md) | Alignement v4.2, XTTS v2, DSP chain, FAISS |

### Fichiers archivés

| Fichier d'origine | Destination |
|-------------------|-------------|
| PROMPTS_V4.md | `archives/` (fusionné dans archives_index.md §1) |
| AUDIT_REPORT_V4.md | `archives/` (fusionné dans archives_index.md §2) |
| Plan_implémentation_V4.1.txt | `archives/` (fusionné dans archives_index.md §3-4) |
| INTEGRATION_PREMIUM_OPEN-SOURCE.txt | `archives/` (fusionné dans archives_index.md §5) |
| INTEGRATION_XTTS.txt | `archives/` (fusionné dans archives_index.md §6) |
| Integration_TRAudio.txt | `archives/` (fusionné dans archives_index.md §7) |
| REPARATION.txt | `archives/` (fusionné dans archives_index.md §8) |
| AutomatisationDocCleanUp.md | `archives/` (§9) |
| Nettoyage.md | `archives/` (§10) |
| RefactoringMassif.md | `archives/` (§11) |
| StabilisationFinale.md | `archives/StabilisationFinale.md` |
| CorrectionComplèteMicroservices.md | `archives/CorrectionComplèteMicroservices.md` |
| Fix_RAM_Doublons_Microservices.md | `archives/Fix_RAM_Doublons_Microservices.md` |
| Validation.md | `archives/Validation.md` |
| 9 prompts legacy `.md` | `archives/` (copies pré-renommage) |

### Prompts maîtres utilisés

| Prompt | Rôle |
|--------|------|
| [prompt_role_permanent.md](prompts/prompt_role_permanent.md) | Directive Copilot permanente — Auditeur Technique Senior |
| [prompt_audit_complet.md](prompts/prompt_audit_complet.md) | Audit complet du projet (6 sections) |
| ~~prompt_design_system.md~~ | *(Fusionné dans prompt_modernisation_ui.md)* → [archive](archives/prompt_design_system.md) |
| [prompt_modernisation_ui.md](prompts/prompt_modernisation_ui.md) | Modernisation visuelle UI premium |
| [prompt_nettoyage.md](prompts/prompt_nettoyage.md) | Nettoyage ultra-strict (8 phases) |
| [prompt_stabilisation_finale.md](prompts/prompt_stabilisation_finale.md) | Stabilisation finale post-nettoyage |
| [prompt_validation.md](prompts/prompt_validation.md) | Validation end-to-end pipeline |
| [prompt_correction_microservices.md](prompts/prompt_correction_microservices.md) | Correction 7 microservices |
| [prompt_gestion_micro.md](prompts/prompt_gestion_micro.md) | Gestion microservices (ports, health) |
| [prompt_gui_release.md](prompts/prompt_gui_release.md) | Build GUI Release + windeployqt |
| [prompt_fix_ram_doublons.md](prompts/prompt_fix_ram_doublons.md) | Fix RAM & doublons processus |
| [prompt_reduction_stt.md](prompts/prompt_reduction_stt.md) | Réduction modèle STT large→medium |

### Audits réalisés

| Audit | Date | Résultat |
|-------|------|----------|
| [audit_master_2026_03.md](audits/audit_master_2026_03.md) | 22 mars 2026 | ✅ 100% conformité — 6 sections |
| Audit Design System QML | 28 mars 2026 | ✅ 19 composants, 3 corrections mineures |
| Fix audio (crackling) | 28 mars 2026 | ✅ 3 fixes TTSManager (sink chaining, gain smoothing, fade-out) |

---

## v4.1 — GPU + Optimisation (mars 2026)

### Résumé des changements

Passage STT sur GPU via Whisper.cpp + Vulkan. Dual backend STT.
Optimisation pipeline FSM (latence < 200ms). Benchmark STT.
Documentation technique initiale.

### Fichiers ajoutés

| Fichier | Description |
|---------|-------------|
| EXO_DOCUMENTATION.md | Documentation technique complète (première version) |
| architecture.md | Vue d'ensemble architecture |
| Plan_implémentation_V4.1.txt | Plan d'implémentation GPU *(archivé)* |
| Plan_optimisation_EXO_v4.1.txt | Plan d'optimisation *(archivé)* |
| scripts/benchmark_stt.py | Benchmark STT (mesure RTF) |

### Fichiers modifiés

| Fichier | Changement |
|---------|------------|
| python/stt/stt_server.py | Refactoring dual-backend (whispercpp + faster-whisper) |
| python/stt/whisper_cpp.py | Nouveau wrapper HTTP pour whisper-server.exe |
| app/audio/VoicePipeline | FSM 6 états, SPEECH_HANG_FRAMES=30, min utterance 2s |
| scripts/auto_maintain.py | Création — 6 commandes maintenance auto |
| scripts/hooks/ | Hooks Git pre-commit / post-commit |

### Fichiers archivés

Aucun — v4.1 était une version additive.

### Prompts maîtres utilisés

Aucun prompt structuré — développement direct.

### Audits réalisés

| Audit | Date | Résultat |
|-------|------|----------|
| Benchmark STT GPU | Mars 2026 | RTF 0.08–0.23, modèle small retenu |

---

## v4.0 — Refonte complète (juillet 2025)

### Résumé des changements

Reconception complète de l'assistant vocal. Nouvelle GUI style VS Code Dark.
Pipeline FSM 6 états. Architecture C++ Qt 6 + microservices Python.
Premier audit complet du projet.

### Fichiers ajoutés

| Fichier | Description |
|---------|-------------|
| PROMPTS_V4.md | Prompts de conception GUI + pipeline *(archivé)* |
| AUDIT_REPORT_V4.md | Rapport d'audit v4.0 *(archivé)* |
| 10 composants QML | MainWindow + 9 composants vscode/ |
| 8 modules C++ | AssistantManager, ConfigManager, ClaudeAPI, VoicePipeline, TTSManager, WeatherManager, AIMemoryManager, LogManager |
| 3 serveurs Python | stt_server, tts_server, exo_server |

### Fichiers modifiés

Aucun — v4.0 était une refonte from scratch.

### Fichiers archivés

| Fichier | Raison |
|---------|--------|
| 15 fichiers QML legacy | Remplacés par les composants vscode/ |
| GUI v3.x complète | Obsolète après refonte |

### Prompts maîtres utilisés

| Prompt | Rôle |
|--------|------|
| PROMPTS_V4.md §1 | GUI VS Code Style (10 composants QML) |
| PROMPTS_V4.md §2 | Visualizer Waveform (ShaderEffect GLSL GPU) |
| PROMPTS_V4.md §3 | Pipeline STT/TTS (FSM 6 états, DSP 5 étages) |

### Audits réalisés

| Audit | Date | Résultat |
|-------|------|----------|
| AUDIT_REPORT_V4.md | Juillet 2025 | ✅ Build 0 erreurs, 3 bugs corrigés (micLevel, Visualizer, CMake) |
| ~~audit_final_2025_07.md~~ | Juillet 2025 | *(Fusionné dans audit_master_2026_03.md — Annexe A)* → [archive](archives/audit_final_2025_07.md) |

---

## 🔮 Prochaine version : v4.3 (préparation)

### Objectifs planifiés

| Objectif | Statut |
|----------|--------|
| Migration GPU : AMD RX 6750 XT → NVIDIA RTX 3070 SUPRIM X | 🔜 Planifié |
| XTTS v2 sur CUDA (au lieu de DirectML) | 🔜 Planifié |
| Whisper.cpp backend CUDA (au lieu de Vulkan) | 🔜 Planifié |
| Home Assistant — intégration domotique complète | 🔜 Planifié |
| Mode conversation multi-turn (mémoire de session) | 🔜 Planifié |

### Fichiers probables à créer

- `guides/cuda_migration.md` — Guide migration CUDA
- `guides/home_assistant.md` — Guide intégration HA
- `reports/migration_gpu.md` — Rapport migration GPU

### Fichiers probables à archiver

- Scripts `legacy_gpu/legacy_amd/` — Deviendront obsolètes après migration NVIDIA
- Configurations Vulkan STT — Remplacées par CUDA

---

*Retour à l'index : [docs/README.md](README.md)*
