> 🧭 [Index](../README.md) → [Prompts](../README.md#-prompts-historiques--prompts) → prompt_correction_microservices.md

---

Je veux que tu corriges entièrement la configuration des microservices EXO suite au refactoring.
Actuellement, la tâche launch_all démarre 7 services, dont un service obsolète : tts_gpu_wsl2.
Ce service n’existe plus, ne doit plus être lancé, et bloque le port 8767.
Il provoque des erreurs HealthCheck ("down", "connexion refusée") et empêche EXO de fonctionner.

Voici les objectifs précis :

====================================================================
🎯 OBJECTIF GLOBAL
====================================================================

1. Supprimer totalement le service tts_gpu_wsl2 du projet.
2. Mettre à jour le script launch_all pour ne plus jamais lancer tts_gpu_wsl2.
3. Mettre à jour tous les chemins Python/C++/QML impactés par le refactoring.
4. Vérifier et corriger les chemins des microservices :
   - exo_server (:8765)
   - stt_server (:8766)
   - tts_server (placeholder temporaire, pas WSL2)
   - vad_server (:8768)
   - wakeword_server (:8770)
   - memory_server (:8771)
   - nlu_server (:8772)
5. Corriger les imports Python cassés suite au déplacement des modules.
6. Corriger les includes C++ cassés suite au refactoring.
7. Corriger les chemins QML si nécessaire.
8. Vérifier que chaque microservice démarre correctement et écoute sur le bon port.
9. Mettre à jour les scripts de lancement individuels si nécessaire.
10. Mettre à jour auto_maintain.py pour refléter la nouvelle structure.

====================================================================
🧹 SUPPRESSION TOTALE DE tts_gpu_wsl2
====================================================================

Tu vas :
- supprimer toute référence à tts_gpu_wsl2 dans launch_all
- supprimer les scripts Python associés
- supprimer les imports associés
- supprimer les dossiers associés
- supprimer les appels dans EXO côté C++
- supprimer les appels dans EXO côté QML
- supprimer les appels dans les scripts de maintenance
- supprimer les références dans la documentation

====================================================================
🛠️ MISE À JOUR DE launch_all
====================================================================

Tu vas :
- générer une version propre et cohérente de launch_all
- lancer uniquement les services valides
- ajouter des logs clairs
- gérer les erreurs proprement
- préparer un placeholder pour le futur TTS CUDA (mais ne rien lancer pour l’instant)

====================================================================
🔧 CORRECTION DES CHEMINS ET IMPORTS
====================================================================

Tu vas :
- analyser la structure actuelle du projet
- détecter les chemins cassés
- corriger les imports Python
- corriger les includes C++
- corriger les chemins QML
- corriger les chemins des scripts microservices
- corriger les chemins dans auto_maintain.py

====================================================================
🧠 MÉTHODOLOGIE
====================================================================

Pour chaque étape :
1. Analyse l’état actuel.
2. Propose un plan détaillé.
3. Génère les patchs complets.
4. Génère les fichiers mis à jour.
5. Attends ma validation avant d’appliquer.

====================================================================
Commence maintenant par analyser launch_all, détecter les incohérences, et proposer un plan de correction complet.
====================================================================

---
*Retour à l'index : [docs/README.md](../README.md)*
