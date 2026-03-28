# 📘 EXO Assistant v4.2 — Index Documentation
> **Version** : 4.2 "Premium Open-Source Edition"
> **Dernière mise à jour** : 28 mars 2026
> **Fichiers** : 42 documents · 7 catégories

---

<!-- TOC -->
## Table des matières

- [Comment naviguer](#comment-naviguer)
- [Documents essentiels](#documents-essentiels)
- [Architecture & Spécifications — `core/`](#architecture-spécifications-core)
- [Guides Techniques — `guides/`](#guides-techniques-guides)
- [Interface — `ui/`](#interface-ui)
- [Audits — `audits/`](#audits-audits)
- [Rapports Techniques — `reports/`](#rapports-techniques-reports)
- [Prompts Historiques — `prompts/`](#prompts-historiques-prompts)
- [Archives — `archives/`](#archives-archives)
- [Versioning documentaire](#versioning-documentaire)
- [Mises à jour récentes](#mises-à-jour-récentes)

<!-- /TOC -->

## 🧭 Comment naviguer

```
docs/
├── README.md                          ← vous êtes ici
├── core/          (9 fichiers)        Architecture, specs, modules
├── guides/        (4 fichiers)        Guides techniques par module
├── ui/            (1 fichier)         Design system & composants QML
├── audits/        (2 fichiers)        Rapports d'audit complets
├── reports/       (3 fichiers)        Rapports techniques ponctuels
├── prompts/       (12 fichiers)       Prompts Copilot historiques
└── archives/      (11+ fichiers)      Legacy, scripts diag, backups
```

**Navigation :**
- Chaque fichier `.md` contient un **lien retour** vers cet index en pied de page
- Les fichiers marqués *(auto-généré)* sont produits par `scripts/auto_maintain.py`
- Les prompts dans `prompts/` documentent les sessions Copilot qui ont construit EXO

---

## ⭐ Documents essentiels

Les 5 documents à lire en priorité pour comprendre EXO :

| # | Document | Pourquoi |
|---|----------|----------|
| 1 | [EXO_SPEC.md](core/EXO_SPEC.md) | **Source de vérité** — spécification officielle v4.2 |
| 2 | [architecture.md](core/architecture.md) | Vue d'ensemble C++ + 7 microservices Python |
| 3 | [EXO_DOCUMENTATION.md](core/EXO_DOCUMENTATION.md) | Référence technique exhaustive (57 Ko) |
| 4 | [audio_pipeline.md](guides/audio_pipeline.md) | Pipeline audio complet (capture → TTS → lecture) |
| 5 | [design_system.md](ui/design_system.md) | Design system UI — VS Code + Fluent Design |

---

## 🏗 Architecture & Spécifications — `core/`

Fondations du projet : architecture, spécifications, index des modules.

| Document | Description | Taille |
|----------|-------------|--------|
| [EXO_DOCUMENTATION.md](core/EXO_DOCUMENTATION.md) | Documentation technique complète — référence principale | 57 Ko |
| [EXO_SPEC.md](core/EXO_SPEC.md) | Spécification officielle v4.2 (source de vérité) | 5 Ko |
| [architecture.md](core/architecture.md) | Vue d'ensemble architecture (C++ + Python + WebSocket) | 7 Ko |
| [architecture_modules.md](core/architecture_modules.md) | Diagramme des modules C++ (arbre de dépendances) | 3 Ko |
| [architecture_graph.md](core/architecture_graph.md) | Graphe de dépendances C++ — matrice d'inclusion *(auto-généré)* | 5 Ko |
| [pipeline.md](core/pipeline.md) | Pipeline événements — 34 événements *(auto-généré)* | 2 Ko |
| [services.md](core/services.md) | Index des 7 microservices *(auto-généré)* | 2 Ko |
| [modules.md](core/modules.md) | Index des modules Python & C++ *(auto-généré)* | 3 Ko |
| [limitations.md](core/limitations.md) | Limitations connues et contournements | 5 Ko |

---

## 📖 Guides Techniques — `guides/`

Guides pratiques pour chaque sous-système audio.

| Document | Description | Taille |
|----------|-------------|--------|
| [audio_pipeline.md](guides/audio_pipeline.md) | Pipeline audio complet : capture → VAD → STT → LLM → TTS → lecture | 12 Ko |
| [stt.md](guides/stt.md) | Speech-to-Text — Whisper.cpp avec backend Vulkan GPU | 5 Ko |
| [tts.md](guides/tts.md) | Text-to-Speech — XTTS v2 sur DirectML GPU | 5 Ko |
| [tests.md](guides/tests.md) | Guide des tests — 180 tests (7 CTest + 173 pytest) | 6 Ko |

---

## 🎨 Interface — `ui/`

Design system et composants visuels Qt/QML.

| Document | Description | Taille |
|----------|-------------|--------|
| [design_system.md](ui/design_system.md) | EXO Design System v4.2 — VS Code + Fluent Design + Copilot | 17 Ko |

---

## 🔍 Audits — `audits/`

Rapports d'audit complets couvrant compilation, chemins, pipeline, stabilité.

| Document | Description | Date | Taille |
|----------|-------------|------|--------|
| [audit_master_2026_03.md](audits/audit_master_2026_03.md) | Audit maître — sections 1–6 + Annexe A historique 2025 | Mars 2026 | 28 Ko |
| ~~audit_final_2025_07.md~~ | *(Fusionné dans audit_master_2026_03.md — Annexe A)* → [archive](archives/audit_final_2025_07.md) | Juillet 2025 | — |

---

## 📊 Rapports Techniques — `reports/`

Rapports ponctuels de corrections et optimisations.

| Document | Description | Date | Taille |
|----------|-------------|------|--------|
| [fix_ram_doublons.md](reports/fix_ram_doublons.md) | Fix RAM & doublons microservices — processus zombies | Mars 2025 | 6 Ko |
| [reduction_stt.md](reports/reduction_stt.md) | Réduction STT : large-v3 → medium (−1,5 Go VRAM) | Mars 2026 | 4 Ko |
| [last_update.md](reports/last_update.md) | Dernière mise à jour *(auto-généré par hook post-commit)* | — | 1 Ko |

---

## 💬 Prompts Historiques — `prompts/`

Prompts utilisés lors des sessions GitHub Copilot pour construire, auditer et stabiliser EXO. Conservés comme référence
et traçabilité.

| Document | Description |
|----------|-------------|
| [prompt_role_permanent.md](prompts/prompt_role_permanent.md) | Rôle permanent maître — directive Copilot |
| [prompt_audit_complet.md](prompts/prompt_audit_complet.md) | Audit complet du projet |
| ~~prompt_design_system.md~~ | *(Fusionné dans prompt_modernisation_ui.md)* → [archive](archives/prompt_design_system.md) |
| [prompt_modernisation_ui.md](prompts/prompt_modernisation_ui.md) | Modernisation visuelle UI |
| [prompt_stabilisation_finale.md](prompts/prompt_stabilisation_finale.md) | Stabilisation finale v4.2 |
| [prompt_validation.md](prompts/prompt_validation.md) | Validation end-to-end |
| [prompt_correction_microservices.md](prompts/prompt_correction_microservices.md) | Correction des 7 microservices |
| [prompt_gestion_micro.md](prompts/prompt_gestion_micro.md) | Gestion microservices (ports, health, relance) |
| [prompt_gui_release.md](prompts/prompt_gui_release.md) | Build GUI Release + windeployqt |
| [prompt_fix_ram_doublons.md](prompts/prompt_fix_ram_doublons.md) | Fix RAM & doublons processus |
| [prompt_reduction_stt.md](prompts/prompt_reduction_stt.md) | Réduction modèle STT |
| [prompt_nettoyage.md](prompts/prompt_nettoyage.md) | Nettoyage avant nouveau GPU |

---

## 📦 Archives — `archives/`

Fichiers historiques, scripts de diagnostic legacy, et sauvegardes. Non maintenus activement.

| Contenu | Description |
|---------|-------------|
| [archives_index.md](archives/archives_index.md) | Index complet des archives (plans v4.0–v4.2) |
| `diagnostic_scripts/` | 13 scripts Python de diagnostic TTS/STT/pipeline |
| `legacy_gpu/legacy_amd/` | Scripts test DirectML / ROCm (obsolètes) |
| `legacy_gpu/legacy_wsl2/` | Setup TTS WSL2 (abandonné au profit de DirectML natif) |
| 9 prompts `.md` | Copies originales des prompts (versions pré-renommage) |

---

## 📌 Versioning documentaire

| Document | Description |
|----------|-------------|
| [VERSIONS.md](VERSIONS.md) | Historique complet des versions documentaires (v4.0 → v4.2 → v4.3) |

---

## 🕐 Mises à jour récentes

| Date | Changement |
|------|------------|
| 28 mars 2026 | Ajout `VERSIONS.md` — versioning documentaire v4.0 → v4.2 → v4.3 |
| 28 mars 2026 | Réorganisation complète `docs/` — 7 catégories, index, normalisation en-têtes |
| 28 mars 2026 | Fix audio (crackling, saccades) — TTSManager sink chaining + gain smoothing |
| 28 mars 2026 | Ajout POST_BUILD windeployqt dans CMakeLists.txt |
| 22 mars 2026 | Audit maître v4.2 — 6 sections, 100% conformité |
| 21 mars 2026 | Réduction STT large-v3 → medium (−1,5 Go VRAM) |
| 21 mars 2026 | Fix RAM & doublons microservices |

---

*EXO Assistant v4.2 — C++ / Qt 6.9.3 · Python · XTTS v2 · Whisper.cpp (Vulkan GPU) · FAISS · Silero · OpenWakeWord*
