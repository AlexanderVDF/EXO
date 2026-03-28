Je veux que tu exécutes toutes les étapes suivantes dans cet ordre précis, sans en sauter une seule, et en respectant
strictement la séquence.

===========================
1) COMPILATION GUI EN RELEASE
===========================

- Ouvre la solution ou le projet contenant RaspberryAssistant.
- Change la configuration de build : Debug → Release.
- Lance un "Rebuild Solution" complet.
- Vérifie que la compilation s’est bien déroulée.
- Confirme que l’exécutable suivant existe :
  bin/Release/RaspberryAssistant.exe

===========================
2) PRÉPARATION DU LANCEMENT EXO
===========================

- Ouvre 7 consoles séparées.
- Lance dans chaque console les services suivants :

  python services/stt_server.py
  python services/tts_server.py
  python services/vad_server.py
  python services/wakeword_server.py
  python services/orchestrator.py
  python services/audio_output.py
  python services/tools_server.py

- Attends 2 secondes pour laisser les services s’initialiser.

===========================
3) LANCEMENT DE LA GUI DESKTOP
===========================

- Lance l’exécutable Release :
  start bin/Release/RaspberryAssistant.exe

- Vérifie que la fenêtre GUI s’ouvre correctement.
- Vérifie que la GUI se connecte aux services (WebSocket OK).

===========================
4) CONFIRMATION
===========================

- Affiche un résumé clair :
  - Compilation Release OK / KO
  - Services lancés OK / KO
  - GUI desktop lancée OK / KO
  - Chemin de l’exécutable utilisé
  - Nombre de consoles ouvertes
  - Statut de connexion aux services

===========================
Respecte strictement cet ordre et exécute chaque étape complètement avant de passer à la suivante.
===========================

---
Retour à l'index : [docs/README.md](../README.md)
