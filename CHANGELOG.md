# CHANGELOG — EXO

> Minimal. Ce qui a changé, supprimé, ajouté, refactoré.
> Source de vérité : `PROMPT_MAITRE.md`

---

## v11.0 — NetworkMap v2 — 30 mars 2026

### Ajouté
- **ARPScanner** (`python/network/arp_scanner.py`) — scan ARP local, extraction IP+MAC, détection gateway, enrichissement vendor
- **MDNSScanner** (`python/network/mdns_scanner.py`) — résolution DNS inverse parallèle, inférence services/type mDNS
- **SSDPScanner** (`python/network/ssdp_scanner.py`) — découverte SSDP/UPnP M-SEARCH multicast, extraction manufacturer
- **PingScanner** (`python/network/ping_scanner.py`) — ping sweep ICMP parallèle (semaphore 20), mesure latence
- **VendorLookup** (`python/network/vendor_lookup.py`) — base OUI IEEE locale, lookup MAC → fabricant
- **DeviceClassifier** (`python/network/device_classifier.py`) — classification automatique par vendor, hostname, services mDNS, SSDP (12 types)
- **TopologyBuilder** (`python/network/topology_builder.py`) — reconstruction topologie étoile, détection gateway/EXO, liens typés (eth/wifi/iot), latence
- **NetworkMapManager** (`python/network/network_map_manager.py`) — orchestrateur unifié : scan_full (ARP+mDNS+SSDP+Ping), scan_fast (ARP), résilience fallback, 14 capabilities

### Modifié
- **NetworkMapService** (`python/network/network_map_service.py`) — réécriture complète : délègue au NetworkMapManager, 15 handlers WS (scan, scan_fast, list_nodes, list_links, get_node, get_topology, get_vendor, get_latency, classify, export, health, restart, metrics, capabilities, metadata)
- **HomeGraph v2** (`python/domotique/homegraph_server.py`) — ajout `run_network_scan()`, `get_network_topology()`, handlers WS "network_scan"/"network_topology"
- **ReseauPage.qml** (`qml/pages/ReseauPage.qml`) — réécriture complète : graphe dynamique Canvas, filtre par type, scan rapide/complet, latence couleur (vert <5ms, jaune <20ms, rouge), sélection nœud + panneau détail, liens typés (eth=bleu, wifi=gris, iot=orange)
- **81 nouveaux tests** — ARPScanner (6), MDNSScanner (9), SSDPScanner (6), PingScanner (8), VendorLookup (5), DeviceClassifier (14), TopologyBuilder (8), NetworkMapManager (12), NetworkMapService (13)
- Total tests : **689 passés** (608 existants + 81 nouveaux)

---

## v10.0 — Domotique v2 — 30 mars 2026

### Ajouté
- **DomoticCache** (`python/domotique/domotic_cache.py`) — cache d'état par device avec TTL, invalidation, stats (hits/misses/hit_rate), thread-safe
- **DiscoveryManager** (`python/domotique/discovery_manager.py`) — moteur de découverte réseau (ARP + mDNS + SSDP + vendor lookup OUI), fusion et dédup
- **EventManager** (`python/domotique/event_manager.py`) — événements push + polling intelligent, subscriptions par device/wildcard, intervalles adaptatifs
- **ScenarioManager** (`python/domotique/scenario_manager.py`) — 6 scénarios prédéfinis (cinéma, nuit, absence, réveil, sécurité, éco), scénarios custom, exécution parallèle, wildcards
- **ScenariosPage.qml** (`qml/pages/ScenariosPage.qml`) — page GUI scénarios (liste, exécution, built-in vs custom)
- **models.py v2** — Protocol (8 valeurs), Connectivity (4 valeurs), DeviceEvent, champs v2 Device (protocol, connectivity, signal_strength, last_event, energy, tags)

### Modifié
- **HomeGraph v2** (`python/domotique/homegraph_server.py`) — intégration DomoticCache, EventManager, ScenarioManager, DiscoveryManager ; nouvelles API : `refresh_device`, `list_by_type`, `get_capabilities`, `get_vendor`, `list_scenarios`, `run_scenario`, `discovery`, `cache_stats`, `event_stats`, `capabilities`, `metadata`
- **5 services domotiques → v2** — samsung, voltalis, echo, domotic, camera : ajout `capabilities()`, `metadata()`, version bump "v2", handlers WS
- **NetworkMapService → v2** (`python/network/network_map_service.py`) — ajout `capabilities()`, `metadata()`
- **MaisonPage.qml** — v2 : section scénarios rapides, signal `scenarioRequested`
- **ReseauPage.qml** — v2 : commentaire header mis à jour
- **43 nouveaux tests** — DomoticCache (8), EventManager (7), ScenarioManager (7), Models v2 (5), HomeGraph v2 (8), Service capabilities (8)
- Total tests : **608 passés** (565 existants + 43 nouveaux)

---

## v9.0 — Observability, Resilience & Security — 30 mars 2026

### Ajouté
- **LogManager** (`python/shared/log_manager.py`) — structured JSON logging, correlation IDs (request_id, session_id), RotatingFileHandler, singleton par service
- **MetricsManager** (`python/shared/metrics_manager.py`) — Counter, Gauge, Histogram, Timer, built-in uptime/requests/errors, snapshot export
- **TraceManager** (`python/shared/trace_manager.py`) — Span/Trace model, distributed tracing, 200-entry history, JSON export
- **ErrorManager** (`python/shared/error_manager.py`) — ErrorCategory (10 catégories), ExoError + sous-classes typées, RETRY_POLICIES, TIMEOUT_POLICIES, with_retry/with_timeout/with_fallback decorators
- **ConfigManager** (`python/shared/config_manager.py`) — config centralisée, dot-notation get/set, hot-reload file watcher, deep merge avec defaults, 12 sections
- **SecurityManager** (`python/shared/security_manager.py`) — PERMISSION_DEFAULTS (4 modules × 10+ actions), AuditLog JSONL append-only, check_permission/authorize/export
- **Resilience** (`python/shared/resilience.py`) — CircuitBreaker (closed→open→half_open), @resilient combined decorator (retry+backoff+timeout+fallback+circuit_breaker)
- **BaseService** (`python/shared/base_service.py`) — classe unifiée intégrant tous les modules v9, health_check(), handle_ws_message() pour protocol v9, begin_request()/end_request() instrumentation, init_v9() one-liner factory
- **Intégration v9 dans 25 microservices** — import + init_v9() dans tous les serveurs (8765–8790)
- **125 nouveaux tests** — test_v9_observability (40), test_v9_resilience (31), test_v9_security (22), test_v9_config (15), test_v9_integration (17)
- Total tests : **565 passés** (440 existants + 125 nouveaux)

### Modifié
- Tous les 25 serveurs Python : ajout `from shared.base_service import init_v9` + `_v9 = init_v9(...)` dans main()
- `python/shared/__init__.py` — docstring v9

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
