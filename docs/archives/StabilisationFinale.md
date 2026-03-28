Je veux que tu réalises la phase finale de stabilisation du projet EXO après le nettoyage massif et la suppression de
tout le passif WSL2/ROCm.

Voici les tâches précises à effectuer :

====================================================================
🎯 OBJECTIF GLOBAL
====================================================================

Stabiliser complètement EXO après le refactoring :
- corriger tous les chemins cassés
- corriger tous les imports Python cassés
- corriger tous les includes C++ cassés
- corriger tous les imports QML cassés
- vérifier et corriger les scripts microservices
- vérifier et corriger launch_all
- vérifier que chaque microservice démarre correctement
- mettre à jour auto_maintain.py pour refléter la nouvelle structure
- préparer le pipeline pour le futur TTS CUDA (placeholder uniquement)
- garantir que plus aucune référence WSL2/ROCm n’existe dans le code

====================================================================
🧹 1) VÉRIFICATION ET CORRECTION DES CHEMINS
====================================================================

Tu vas analyser :
- les chemins Python (python/tts, python/stt, python/vad, python/wakeword, python/memory, python/nlu)
- les chemins C++ (src/core, src/audio, src/pipeline, src/services)
- les chemins QML (qml/components, qml/panels, qml/pipeline)
- les chemins des scripts (scripts/, tools/, tasks/)
- les chemins dans auto_maintain.py

Et corriger :
- les imports Python invalides
- les includes C++ invalides
- les imports QML invalides
- les chemins relatifs cassés
- les chemins absolus obsolètes

====================================================================
🧠 2) MICRO-SERVICES : VÉRIFICATION COMPLÈTE
====================================================================

Tu vas vérifier les services suivants :

exo_server (:8765)
stt_server (:8766)
tts_server (placeholder, pas de GPU pour l’instant)
vad_server (:8768)
wakeword_server (:8770)
memory_server (:8771)
nlu_server (:8772)

Pour chacun :
- vérifier que le script existe
- vérifier que les imports sont corrects
- vérifier que les chemins internes sont corrects
- vérifier que le port est correct
- vérifier que le lancement ne dépend plus de WSL2/ROCm
- corriger si nécessaire

====================================================================
🛠️ 3) launch_all : VÉRIFICATION ET CORRECTION
====================================================================

Tu vas :
- analyser launch_all
- vérifier que tts_gpu_wsl2 n’est plus référencé
- vérifier que tts_server est bien le placeholder actuel
- vérifier que les chemins des scripts sont corrects
- vérifier que les ports sont corrects
- corriger si nécessaire
- générer une version propre et cohérente

====================================================================
🔧 4) auto_maintain.py : MISE À JOUR FINALE
====================================================================

Tu vas :
- mettre à jour les chemins internes
- mettre à jour les commandes
- supprimer toute référence WSL2/ROCm
- ajouter la prise en charge du futur backend CUDA
- vérifier que les commandes scan / clean / docs / context fonctionnent

====================================================================
🧩 5) VALIDATION FINALE
====================================================================

Tu vas :
- générer un rapport listant tous les fichiers corrigés
- générer les patchs complets
- vérifier la cohérence globale du projet
- attendre ma validation avant d’appliquer

====================================================================
Commence maintenant par analyser l’état actuel des chemins et des microservices, et propose un plan de correction
complet.
====================================================================

---
Retour à l'index : [docs/README.md](../README.md)
