Tu es chargé d’exécuter un audit complet d’EXO Assistant.
Tu dois effectuer les tâches suivantes dans cet ordre, sans en sauter une seule :

────────────────────────────────────────
1) COMPILATION GUI EN MODE RELEASE
────────────────────────────────────────
- Vérifie que le preset CMake "Release" existe.
- Vérifie que les chemins Qt, QML, include et libs sont corrects.
- Compile la GUI en mode Release.
- Vérifie que l’exécutable final est bien généré dans build/Release.

────────────────────────────────────────
2) VALIDATION DES CHEMINS DES SERVICES
────────────────────────────────────────
Pour chaque service (STT, TTS, VAD, Wakeword, Memory, NLU, Orchestrator) :
- Vérifie que les chemins configurés dans la GUI sont corrects.
- Vérifie que les ports WebSocket correspondent à ceux des scripts Python.
- Vérifie que les exécutables existent réellement.
- Vérifie que les .env sont chargés correctement.

────────────────────────────────────────
3) TEST DU TTS (XTTS v2 + DirectML)
────────────────────────────────────────
- Vérifie que le serveur XTTS v2 répond sur ws://localhost:8767.
- Vérifie que le handshake “OK” est reçu.
- Vérifie que la GUI envoie bien les messages TTS.
- Vérifie que le pipeline audio reçoit des PCM > 0 bytes.
- Vérifie que drainAndStop ne renvoie pas systématiquement 0 bytes.
- Vérifie que l’audio sort bien sur QAudioSink.

Si un problème est détecté :
→ Identifie la cause (socket, buffer, format audio, DSP, thread TTS, etc.)
→ Propose une correction.

────────────────────────────────────────
4) TEST DU STT
────────────────────────────────────────
- Vérifie que Silero, Builtin et Hybride fonctionnent.
- Vérifie que le VAD déclenche correctement.
- Vérifie que le STT ne time‑out pas.
- Vérifie que les transcripts arrivent bien dans la GUI.

────────────────────────────────────────
5) TEST DU PIPELINE COMPLET
────────────────────────────────────────
- Wakeword → VAD → STT → Claude → TTS → Audio Output
- Vérifie que chaque transition d’état est cohérente.
- Vérifie qu’aucun état ne reste bloqué (ex: Transcribing).
- Vérifie que les buffers ne se réinitialisent pas en boucle.

────────────────────────────────────────
6) AUDIT DE STABILITÉ
────────────────────────────────────────
- Analyse les risques de deadlocks Qt.
- Analyse les risques de freeze GUI (thread UI bloqué).
- Analyse les risques de saturation audio (buffer overflow).
- Analyse les risques de websocket bloqué.
- Analyse les risques de race conditions dans VoicePipeline.

────────────────────────────────────────
7) RAPPORT FINAL
────────────────────────────────────────
À la fin, génère un rapport structuré contenant :
- Les erreurs détectées
- Les causes probables
- Les correctifs recommandés
- Les fichiers à modifier
- Les lignes de code concernées
- Les tests à refaire après correction

────────────────────────────────────────

IMPORTANT :
- Ne propose pas de solutions vagues.
- Donne des corrections précises, avec code exact.
- Ne saute aucune étape.
- Ne réponds pas tant que l’analyse n’est pas complète.

---
Retour à l'index : [docs/README.md](../README.md)
