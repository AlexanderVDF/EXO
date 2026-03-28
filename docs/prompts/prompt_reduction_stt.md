> 🧭 [Index](../README.md) → [Prompts](../README.md#-prompts-historiques--prompts) → prompt_reduction_stt.md

---
Je veux que tu appliques l’Option B : réduire la charge STT en passant Whisper de large-v3 à medium.
Voici les modifications à effectuer dans EXO Assistant v4.2 :

====================================================================
🎯 OBJECTIF
====================================================================

Réduire la consommation RAM et CPU du STT en remplaçant :

- modèle actuel : "large-v3" (~2.0 GB RAM)
par
- modèle optimisé : "medium" (~700 MB RAM)

Objectifs :
- stabiliser le TTS (XTTS CPU saturait)
- réduire la latence STT
- éviter les saccades audio
- réduire la pression sur la RAM (16 GB)
- améliorer la fluidité globale du pipeline

====================================================================
🟦 1) MODIFIER LE .env
====================================================================

Dans le fichier `.env`, remplacer :

STT_MODEL=large-v3

par :

STT_MODEL=medium

Et s’assurer que :

STT_DEVICE=vulkan
STT_LANGUAGE=fr

====================================================================
🟩 2) PATCHER stt_server.py
====================================================================

Adapter le chargement du modèle :

- si STT_MODEL == "medium" → charger whisper-medium
- vérifier que le chemin du modèle est correct
- afficher dans les logs :
    "STT model: medium (700MB) — device: vulkan"

Optimiser les paramètres :
- beam_size = 3
- best_of = 3
- temperature = 0.0
- no_speech_threshold = 0.4
- logprob_threshold = -1.0

====================================================================
🟧 3) PATCHER L’ORCHESTRATEUR
====================================================================

Dans VoicePipeline / STTManager :

- mettre à jour le message de connexion :
    "STT server prêt — modèle: medium — device: vulkan"

- recalibrer le VAD :
    VAD threshold = 0.35
    VAD noise floor recalibration = true

====================================================================
🟨 4) OPTIMISATION LATENCE
====================================================================

Pour Whisper medium :
- chunk_size = 16000
- overlap = 0
- envoyer les buffers plus petits (512 frames)
- réduire la latence de streaming

====================================================================
🟫 5) TESTS À EFFECTUER
====================================================================

1. Vérifier que le STT démarre :
    "STT server prêt — modèle: medium"

2. Vérifier la RAM :
    whisper-server ≈ 700–800 MB

3. Vérifier la stabilité TTS :
    plus de saccades
    plus de changement de voix
    chunks réguliers

4. Vérifier la latence :
    STT final < 500 ms

====================================================================
🟪 6) RAPPORT FINAL
====================================================================

À la fin, produire un rapport contenant :
- modèle chargé
- RAM utilisée
- latence STT
- impact sur TTS
- stabilité audio
- recommandations éventuelles

====================================================================
Commence maintenant par modifier le .env et patcher stt_server.py.
====================================================================

---
*Retour à l'index : [docs/README.md](../README.md)*
