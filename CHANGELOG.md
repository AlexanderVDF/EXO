# CHANGELOG — EXO

> Minimal. Ce qui a changé, supprimé, ajouté, refactoré.
> Source de vérité : `PROMPT_MAITRE.md`

---

## v8.1 — Ultra-Low Latency — 30 mars 2026

### Ajouté
- **ContextCache** (`app/core/ContextCache.h/.cpp`) — cache in-process avec TTL par clé, éviction automatique (timer 10 s), refresh en arrière-plan via signaux Qt, thread-safe (QMutex)
- **LatencyMetrics** (`app/core/LatencyMetrics.h/.cpp`) — singleton d'instrumentation pipeline, 9 timestamps (sttStart → responseDone), 6 métriques dérivées (perceivedLatency, endToEnd…), historique rolling 100 snapshots, `getLatencyReport()` exposé au QML
- **ClaudeAPI warmup** — `initWarmup()` envoie un ping léger non-streaming au démarrage (1 token max), `startKeepAlive()` maintient la connexion TCP chaude (timer 240 s)
- **Instrumentation pipeline** — marks LatencyMetrics dans VoicePipeline (sttStart, sttPartialFirst, sttFinal), ClaudeAPI (llmRequest, llmFirstToken, llmComplete), TTSManager (ttsFirstChunk, ttsFirstAudio, responseDone + finalize)
- **Cache tool calls** — AssistantManager wrappe `get_weather` (TTL 60 s) et `get_datetime` (TTL 10 s) via ContextCache, évite les appels réseau redondants
- **27 nouveaux tests** (`tests/python/test_ull.py`) — TestContextCache (11), TestLatencySnapshot (5), TestWarmupKeepAlive (6), TestCacheIntegration (5)
- Total tests : **440 passés** (413 existants + 27 nouveaux)

### Modifié
- `ClaudeAPI.h/.cpp` — ajout warmup/keepalive + 3 marks latency
- `VoicePipeline.cpp` — ajout 3 marks latency (sttStart, sttPartialFirst, sttFinal)
- `TTSManager.h/.cpp` — ajout `m_firstAudioPumped` flag + 3 marks latency + finalize
- `AssistantManager.h/.cpp` — intégration ContextCache + warmup/keepalive init
- `CMakeLists.txt` — ajout ContextCache.cpp/.h et LatencyMetrics.cpp/.h

---

## v5.2 — 29 mars 2026

### Corrigé
- **SIGSEGV startup** : `cleanupProbe()` utilise `deleteLater()` au lieu de `delete` (use-after-free)
- **Wildcards disconnect** : `destroySocket()` via `deleteLater()`, poll timer sans `close()`, filtre LogManager
- **Volume TTS** : crossfade `kSmooth = 0.7` (était 0.3, causait des sauts)
- **Double log TTS** : suppression appel redondant `setXTTSVoice()` dans `TTSManager::setVoice()`
- **Log DSP** : `norm -14dBFS` dans le message (correspondait pas à la vraie valeur)
- **Géolocalisation** : désactivée par défaut (IP retournait ville ISP, pas ville réelle)
- **Config overwrite** : `detectLocation()` ne surcharge plus les villes non-default
- **TTS WARN→INFO** : "Connexion Python réinitialisée" + 3 autres messages backend
- **Météo FR** : localisation forcée `lang=fr` dans l'appel API
- **Startup apply** : pitch, rate, noiseGate, AGC appliqués au démarrage depuis la config

### Ajouté
- 10+ bindings GUI↔Config synchronisés (VAD threshold, audio backend, TTS style/pitch/rate, etc.)

### Supprimé
- Code mort : 7 fichiers QML legacy, 2 backends TTS inutilisés, `handleVoiceCommand()`
- Renommage logging `henri` → `exo`
- **75 fichiers de documentation obsolètes** (archives, doublons, prompts historiques, site HTML)
- Dossiers `docs/`, `docs_site/`, `COPILOT_MASTER_DIRECTIVE.md`

### Refactoré
- Documentation vivante : 3 documents uniques (`PROMPT_MAITRE.md`, `PLAN_IMPLEMENTATION.md`, `CHANGELOG.md`)

---

## v4.2 — 28 mars 2026

### Ajouté
- Design System complet : 19 composants QML, tokens couleur/typo/espacement
- Migration QML pages, panels, components
- ServiceManager auto-launch + SplashScreen + launcher Python

### Refactoré
- Refactoring massif, anti-doublons, documentation (v4.2.1)

---

## v4.1 — Mars 2026

### Ajouté
- STT GPU Vulkan (passage CPU → GPU)
- Dual backend STT (whispercpp + faster-whisper fallback)
- Pipeline FSM 6 états

---

## v4.0 — Juillet 2025

### Ajouté
- Reconception complète depuis zéro
- GUI VS Code dark theme (QML)
- Pipeline FSM initial
- 3 premiers microservices Python (STT, TTS, VAD)
- Claude API avec Function Calling
- Home Assistant integration
