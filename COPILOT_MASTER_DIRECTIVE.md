NOTE POUR COPILOT — DIRECTIVE GLOBALE EXO v4.2 (ORCHESTRATION, OPTIMISATION, CONTEXTE)

Ce fichier définit les règles OBLIGATOIRES que Copilot doit suivre dans ce dépôt.
Elles concernent : le lancement d’EXO, les serveurs Python, le STT, le TTS, 
l’organisation du contexte, la performance, et la cohérence globale.

────────────────────────────────────────────────────────────
1) ORCHESTRATION DE LANCEMENT EXO (OBLIGATOIRE)
────────────────────────────────────────────────────────────

Quand l’utilisateur demande :
- "lancer EXO"
- "démarrer EXO"
- "run EXO"
- "start EXO"
- "exécuter EXO"
- ou toute variante similaire,

Copilot DOIT utiliser .vscode/tasks.json pour lancer les serveurs.
La méthode OBLIGATOIRE est d'exécuter la tâche VS Code "launch_all"
qui lance les 7 serveurs en parallèle dans le terminal intégré.

Tâches définies dans .vscode/tasks.json :
1. exo_server      → .venv/Scripts/python.exe python/orchestrator/exo_server.py
2. stt_server      → .venv_stt_tts/Scripts/python.exe python/stt/stt_server.py --backend whispercpp --model large-v3 --device gpu
3. tts_server      → .venv_stt_tts/Scripts/python.exe python/tts/tts_server.py --voice "Claribel Dervla" --lang fr
4. vad_server      → .venv_stt_tts/Scripts/python.exe python/vad/vad_server.py
5. wakeword_server → .venv_stt_tts/Scripts/python.exe python/wakeword/wakeword_server.py
6. memory_server   → .venv_stt_tts/Scripts/python.exe python/memory/memory_server.py
7. nlu_server      → .venv_stt_tts/Scripts/python.exe python/nlu/nlu_server.py

Après les 7 serveurs, lancer : build\Debug\RaspberryAssistant.exe

Copilot NE DOIT JAMAIS utiliser :
- Start-Process
- cmd.exe /c
- powershell -WindowStyle
- toute commande ouvrant une fenêtre terminal externe

Copilot DOIT TOUJOURS utiliser le terminal intégré VS Code.
Copilot NE DOIT JAMAIS lancer EXO seul.
Copilot NE DOIT JAMAIS modifier cet ordre.
Copilot NE DOIT JAMAIS ignorer un serveur.

────────────────────────────────────────────────────────────
2) STT OBLIGATOIRE : WHISPER.CPP LARGE-V3 (VULKAN)
────────────────────────────────────────────────────────────

Copilot doit TOUJOURS utiliser :
- backend STT : whispercpp
- modèle : ggml-large-v3.bin
- device : gpu (Vulkan)
- langue : fr

Copilot NE DOIT JAMAIS proposer :
- small, medium, tiny, base, large-v2
- faster-whisper
- CPU-only
- d’autres backends STT

Copilot doit accepter une consommation VRAM élevée (3–6 Go).

────────────────────────────────────────────────────────────
3) TTS OBLIGATOIRE : XTTS v2
────────────────────────────────────────────────────────────

Copilot doit TOUJOURS utiliser :
- backend TTS : XTTS v2
- voix : "Claribel Dervla"
- langue : fr
- paramètres : pitch, rate, style

Copilot NE DOIT JAMAIS proposer Piper.
Copilot NE DOIT JAMAIS proposer un autre moteur TTS.

────────────────────────────────────────────────────────────
4) OPTIMISATION DU CONTEXTE POUR VS CODE
────────────────────────────────────────────────────────────

Copilot doit :
- réduire la surcharge contextuelle,
- éviter de relire les dossiers lourds,
- accélérer sa génération.

Copilot doit considérer comme IGNORÉS :
- build/
- logs/
- models/
- whisper.cpp/models/
- .venv*/
- node_modules/

Copilot doit se baser principalement sur :
- docs/EXO_SPEC_V4.2.md
- COPILOT_MASTER_DIRECTIVE.md (ce fichier)

────────────────────────────────────────────────────────────
5) COHÉRENCE ARCHITECTURALE
────────────────────────────────────────────────────────────

Copilot doit TOUJOURS respecter EXO_SPEC_V4.2.md.
Copilot doit considérer tout fichier contradictoire comme obsolète.
Copilot doit proposer leur suppression ou archivage.

Copilot doit maintenir :
- XTTS v2 comme TTS unique
- Whisper.cpp large-v3 comme STT unique
- OpenWakeWord comme wakeword unique
- Silero comme VAD unique
- FAISS comme mémoire unique
- NLU local comme module obligatoire

────────────────────────────────────────────────────────────
6) RÈGLES DE GÉNÉRATION
────────────────────────────────────────────────────────────

Copilot doit :
- générer des commandes correctes pour Windows PowerShell,
- respecter les chemins du projet,
- maintenir la cohérence du pipeline,
- éviter les alternatives inutiles,
- éviter les suggestions contradictoires,
- éviter les backends non utilisés.

Copilot NE DOIT JAMAIS :
- proposer Piper,
- proposer faster-whisper,
- proposer un modèle Whisper autre que large-v3,
- proposer un lancement partiel,
- proposer un ordre différent,
- proposer un pipeline différent.

────────────────────────────────────────────────────────────
7) OBJECTIF GLOBAL
────────────────────────────────────────────────────────────

Copilot doit :
- maintenir un comportement stable,
- accélérer sa génération,
- réduire la charge contextuelle,
- respecter strictement EXO_SPEC_V4.2.md,
- lancer EXO correctement,
- utiliser les bons modèles,
- et garantir la cohérence du projet.

────────────────────────────────────────────────────────────
8) TTS PYTHON PRIORITAIRE — FALLBACK Qt INTERDIT sauf ERREUR CRITIQUE
────────────────────────────────────────────────────────────

Le TTS Python (XTTS v2 sur ws://localhost:8767) est le moteur obligatoire.
Copilot doit TOUJOURS vérifier la disponibilité du TTS Python avant playback.
Le fallback Qt TTS ne doit s'activer QU'en cas d'erreur critique
(serveur TTS injoignable après retry, crash confirmé).

tryPythonTTS() dans ttsmanager.cpp inclut un retry automatique.
Copilot NE DOIT JAMAIS désactiver ce retry ni proposer Qt TTS par défaut.

────────────────────────────────────────────────────────────
9) WAKEWORD — MODE STRICT OBLIGATOIRE
────────────────────────────────────────────────────────────

Le wakeword logiciel (OpenWakeWord hey_jarvis) doit fonctionner en mode strict :
- Seuil de détection minimum : 0.7 (côté Python ET C++)
- Cooldown obligatoire de 3 secondes entre deux détections
- Détection interdite pendant les états Speaking, Thinking, Transcribing
- Aucun déclenchement pendant une phrase en cours

Copilot NE DOIT JAMAIS abaisser le seuil wakeword en dessous de 0.7.

────────────────────────────────────────────────────────────
10) CHEMINS OBLIGATOIRES SUR D:\EXO\
────────────────────────────────────────────────────────────

Tous les modèles et données doivent résider sur le SSD D:\EXO\ :
- STT : D:\EXO\models\whisper\
- XTTS v2 : D:\EXO\models\xtts\
- Wakeword : D:\EXO\models\wakeword\
- FAISS : D:\EXO\faiss\
- Logs : D:\EXO\logs\
- Cache HF : D:\EXO\cache\
- whisper.cpp : D:\EXO\whispercpp\

Copilot NE DOIT JAMAIS utiliser C:\ pour les modèles ou données volumineuses.
Copilot NE DOIT JAMAIS référencer J:\EXO\ (ancien chemin obsolète, migré vers D:\EXO\).

────────────────────────────────────────────────────────────
11) TTS GPU — Windows natif (préparation CUDA RTX 3070)
────────────────────────────────────────────────────────────

Le TTS XTTS v2 s'exécute nativement sous Windows via tts_server.py.
Le serveur détecte automatiquement CUDA (RTX 3070) ou CPU fallback.

Architecture actuelle :
- Windows natif, Python 3.11, venv .venv_stt_tts/
- Serveur : python/tts/tts_server.py → ws://localhost:8767
- Modèles : D:\EXO\models\xtts\
- Tâche VS Code : "tts_server" (incluse dans launch_all)
- Scripts legacy archivés dans scripts/legacy_wsl2/ (ne plus utiliser)

Copilot DOIT TOUJOURS :
- Lancer le TTS via la tâche VS Code "tts_server"
- Vérifier que le port 8767 est accessible
- Utiliser les modèles XTTS depuis D:\EXO\models\xtts\

Copilot NE DOIT JAMAIS :
- Modifier le port TTS (8767 est obligatoire)
- Proposer Piper ou un autre moteur TTS

────────────────────────────────────────────────────────────
12) LANCEMENT EXO — ORDRE ACTUALISÉ
────────────────────────────────────────────────────────────

L'ordre de lancement actualisé est :
1. exo_server     → .venv/Scripts/python.exe python/orchestrator/exo_server.py
2. stt_server     → .venv_stt_tts/Scripts/python.exe python/stt/stt_server.py
3. tts_server     → .venv_stt_tts/Scripts/python.exe python/tts/tts_server.py
4. vad_server     → .venv_stt_tts/Scripts/python.exe python/vad/vad_server.py
5. wakeword_server→ .venv_stt_tts/Scripts/python.exe python/wakeword/wakeword_server.py
6. memory_server  → .venv_stt_tts/Scripts/python.exe python/memory/memory_server.py
7. nlu_server     → .venv_stt_tts/Scripts/python.exe python/nlu/nlu_server.py

Ce fichier est la source de vérité pour Copilot dans ce dépôt.
