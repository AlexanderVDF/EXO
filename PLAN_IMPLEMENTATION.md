# PLAN D'IMPLÉMENTATION — EXO v5.2

> Dernière mise à jour : 29 mars 2026
> Source de vérité : `PROMPT_MAITRE.md`

---

## État actuel

EXO v5.2 est **opérationnel**. Tous les modules compilent, les 7 services démarrent, le pipeline vocal fonctionne.

---

## Correctifs appliqués (v5.2)

| # | Module | Correction | Fichier |
|---|--------|-----------|---------|
| 1 | ServiceSupervisor | Fix SIGSEGV : `deleteLater()` au lieu de `delete` dans `cleanupProbe()` | `ServiceSupervisor.cpp` |
| 2 | ServiceSupervisor | Ordre shutdown : stop timers AVANT delete client | `ServiceSupervisor.cpp` |
| 3 | ServiceSupervisor | Suppression `close()` avant `open()` sur poll timer | `ServiceSupervisor.cpp` |
| 4 | WebSocketClient | `deleteLater()` dans `destroySocket()` au lieu de `delete` | `WebSocketClient.cpp` |
| 5 | LogManager | Filtre wildcard disconnect warnings | `LogManager.cpp` |
| 6 | TTSManager | Fix volume jump : `kSmooth = 0.7` (était 0.3) | `TTSManager.cpp` |
| 7 | TTSManager | Suppression double appel `setXTTSVoice()` dans `setVoice()` | `TTSManager.cpp` |
| 8 | TTSManager | Log DSP corrigé : `norm -14dBFS` (était -16) | `TTSManager.cpp` |
| 9 | TTSBackendXTTS | `qWarning → qInfo` pour "Connexion Python réinitialisée" | `TTSBackendXTTS.cpp` |
| 10 | TTSBackendXTTS | `qWarning → qInfo` pour backend/URL/voice/language | `TTSBackendXTTS.cpp` |
| 11 | ConfigManager | Géolocalisation désactivée par défaut (IP donne ville ISP) | `ConfigManager.cpp` |
| 12 | ConfigManager | `detectLocation()` ne surcharge plus les villes non-default | `ConfigManager.cpp` |
| 13 | SettingsPage | 10+ contrôles GUI synchronisés (VAD, TTS, audio, etc.) | `SettingsPage.qml` |
| 14 | WeatherManager | Fix localisation FR (réponse API lang=fr) | `WeatherManager.cpp` |
| 15 | AssistantManager | Application pitch/rate/noiseGate/AGC au startup | `AssistantManager.cpp` |

---

## Tâches restantes (v5.2 → v5.3)

### Priorité haute

| # | Tâche | Module | Détail |
|---|-------|--------|--------|
| 1 | Appliquer Noise Reduction live | SettingsPage.qml | Le toggle sauvegarde en config mais n'appelle pas `voiceManager` pour appliquer |
| 2 | Aligner constante `DEFAULT_STT_MODEL` | ConfigManager.h | Constante dit `"large-v3"` mais la réalité est `medium` (via args tasks.json) |

### Priorité moyenne

| # | Tâche | Module | Détail |
|---|-------|--------|--------|
| 3 | Tests E2E pipeline | tests/integration | Tester le cycle complet wake→STT→Claude→TTS |
| 4 | Monitoring VRAM | HealthCheck | Ajouter check VRAM GPU dans le health monitoring |

### Priorité basse

| # | Tâche | Module | Détail |
|---|-------|--------|--------|
| 5 | GUI responsive | QML | Supporter des résolutions autres que 1280×800 |
| 6 | Thème clair | Theme.qml | Ajouter un mode light |
| 7 | i18n | QML/C++ | Internationalisation des textes GUI |

---

## Modules stables (pas de refonte prévue)

| Module | Statut |
|--------|--------|
| VoicePipeline FSM | ✅ Stable |
| PipelineEvent (34 types) | ✅ Stable |
| ClaudeAPI (8 FC tools) | ✅ Stable |
| DSP sortie (5 étages) | ✅ Stable |
| AudioPreprocessor | ✅ Stable |
| ServiceSupervisor | ✅ Stable (post-fix) |
| WebSocketClient | ✅ Stable (post-fix) |
| 7 microservices Python | ✅ Stable |
| Design System (19 composants) | ✅ Stable |

---

## Migration v6 (planifié)

| Objectif | Impact |
|----------|--------|
| Raspberry Pi 5 | Cross-compilation ARM, modèles quantifiés |
| Docker | Containerisation des 7 services Python |
| Mobile companion | Nouvelle GUI (Flutter ou React Native) |
| Google Calendar | Nouveau FC tool Claude |
| Spotify/Tidal | Nouveau FC tool + media player |
| CUDA TTS full GPU | GPT autorégressif sur GPU (actuellement CPU) |

---

> Ce plan est mis à jour à chaque itération. Seules les tâches **actives** y figurent.
