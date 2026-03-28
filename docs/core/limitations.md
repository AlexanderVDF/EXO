> 🧭 [Index](../README.md) → [Architecture](../README.md#-architecture--spécifications--core) → limitations.md
# Limitations connues — EXO v4.2
> Documentation EXO v4.2 — Section : Architecture
> Dernière mise à jour : Mars 2026

---

<!-- TOC -->
## Table des matières

- [STT (Whisper.cpp)](#stt-whispercpp)
- [TTS (XTTS v2)](#tts-xtts-v2)
- [VAD (Silero)](#vad-silero)
- [WakeWord (OpenWakeWord)](#wakeword-openwakeword)
- [NLU (Classifieur regex)](#nlu-classifieur-regex)
- [Claude LLM](#claude-llm)
- [Mémoire sémantique (FAISS)](#mémoire-sémantique-faiss)
- [Infrastructure](#infrastructure)
- [GUI (QML)](#gui-qml)

<!-- /TOC -->

## STT (Whisper.cpp)

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| Hallucinations Whisper | Transcriptions fantômes (crédits, sous-titres) | Filtre `_is_hallucination()` actif, mais pas 100% fiable |
| Latence premier mot | 500ms–2s selon longueur utterance | Normal pour Whisper large-v3, réduire à medium si besoin |
| Pas de streaming natif | Résultat final uniquement (pas mot à mot) | Affichage "partial" simulé côté serveur |
| Langue unique par session | Pas de détection automatique multi-langue | Configurer `language=fr` explicitement |
| Bruit de fond | Transcriptions parasites en environnement bruyant | DSP d'entrée (noise gate, high-pass) aide mais ne suffit pas toujours |

## TTS (XTTS v2)

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| Latence premier chunk | 200–500ms avant le premier audio | Cache LRU pour phrases courtes |
| Qualité variable selon texte | Mots techniques/noms propres mal prononcés | Pas de SSML supporté |
| Timeout 12s | Synthèse annulée si trop longue | Découpage en phrases côté TTSManager |

## VAD (Silero)

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| Faux positifs sur bruits | Sons non-vocaux détectés comme parole | Régler `threshold` (défaut 0.45) |
| Sensibilité à la musique | Musique de fond déclenche le VAD | Pas de filtre musical intégré |
| Chunks fixes 32ms | Pas de résolution temporelle plus fine | Contrainte du modèle Silero |

## WakeWord (OpenWakeWord)

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| Un seul modèle actif | Pas de multi-wakeword simultané | `hey_jarvis` par défaut |
| Faux positifs occasionnels | Mots phonétiquement proches déclenchent | Cooldown 3s entre détections |
| Modèle ONNX uniquement | Pas de format TensorFlow/PyTorch natif | Conversion ONNX requise pour modèles custom |

## NLU (Classifieur regex)

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| Regex uniquement | Pas de compréhension sémantique profonde | Routes vers Claude LLM si confiance < 0.7 |
| Français uniquement | Pas de support multi-langue | Extension regex nécessaire pour autres langues |
| Intents limités (8) | Pas de reconnaissance d'intentions complexes | Claude prend le relais |
| Dispatch via "action" | Incohérence avec les autres serveurs (qui utilisent "type") | Documenter, gérer dans HealthCheck |

## Claude LLM

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| Nécessite internet | Pas de mode hors-ligne pour le LLM | NLU local gère les commandes simples |
| Coût API | Facturation Anthropic par token | Routage NLU local pour commandes simples |
| Latence variable | 200ms–5s selon complexité | Streaming SSE pour réponse progressive |
| Pas de mémoire long-terme native | Contexte limité à la fenêtre | AIMemoryManager + FAISS compense |

## Mémoire sémantique (FAISS)

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| Limite 10 000 entrées | Index ne scale pas pour gros volumes | Suffisant pour usage personnel |
| Modèle embedding léger | all-MiniLM-L6-v2 (384-dim) pas toujours précis | Compromis vitesse/qualité acceptable |
| Pas de suppression par lot | Suppression un par un uniquement | Commande `clear` pour tout supprimer |

## Infrastructure

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| 7 processus Python | Consommation mémoire élevée (~2-3 Go total) | Chaque serveur est isolé et léger |
| Pas de conteneurisation | Déploiement manuel | Scripts d'installation dans `scripts/` |
| Chemins hardcodés SSD | `D:\EXO\...` spécifique à la machine | Variables d'environnement dans tasks.json |
| Windows uniquement (prod) | Pas de build Linux natif | — |
| Pas de HTTPS | WebSocket non chiffré (localhost) | Acceptable en local uniquement |

## GUI (QML)

| Limitation | Impact | Contournement |
|------------|--------|---------------|
| Pas de responsive design | Taille fixe 1280×800 | Suffisant pour desktop |
| Pas d'internationalisation | Interface en français uniquement | Strings hardcodées dans QML |
| Pas de thème clair | Dark theme uniquement | VS Code aesthetic imposé |

---
*Retour à l'index : [docs/README.md](../README.md)*
