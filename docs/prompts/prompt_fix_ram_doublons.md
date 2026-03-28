> 🧭 [Index](../README.md) → [Prompts](../README.md#-prompts-historiques--prompts) → prompt_fix_ram_doublons.md

---
Je veux que tu réalises une stabilisation complète de l’environnement EXO pour éliminer l’utilisation excessive de RAM
et empêcher les doublons de microservices. Voici les tâches à effectuer :

====================================================================
🎯 OBJECTIF GLOBAL
====================================================================

1. Empêcher qu’il y ait plusieurs instances des microservices Python.
2. Empêcher qu’il y ait plusieurs instances de whisper-server.
3. Ajouter une protection anti-doublons dans launch_all et dans chaque script microservice.
4. Générer un script auto_kill_zombies.py pour tuer automatiquement :
   - les processus Python zombies
   - les watchers Node inutiles
   - les instances VS Code Helper en excès
5. Nettoyer l’environnement pour réduire l’utilisation RAM de 80% à un niveau normal.
6. Vérifier que launch_all ne relance pas plusieurs fois les mêmes services.
7. Vérifier que chaque microservice écoute sur un seul port et qu’une seule instance existe.
8. Générer un rapport final de stabilité.

====================================================================
🧹 1) ANALYSE DES DOUBLONS
====================================================================

Tu vas analyser les processus suivants :
- python.exe
- whisper-server
- node.exe
- code.exe

Et identifier :
- les doublons
- les processus zombies
- les watchers de fichiers inutiles
- les microservices lancés plusieurs fois

====================================================================
🛠️ 2) PROTECTION ANTI-DOUBLONS
====================================================================

Tu vas modifier :
- launch_all
- chaque script microservice (exo_server, stt_server, tts_server, vad_server, wakeword_server, memory_server,
nlu_server)
- whisper-server interne

Pour ajouter :
- une vérification de port déjà utilisé
- une vérification de processus déjà en cours
- un message clair si le service est déjà lancé
- un exit propre si doublon détecté

====================================================================
🧨 3) SCRIPT auto_kill_zombies.py
====================================================================

Tu vas générer un script Python qui :
- détecte les processus Python zombies
- détecte les watchers Node inutiles
- détecte les processus Code Helper en excès
- tue automatiquement les doublons
- affiche un rapport clair

Le script doit :
- fonctionner sous Windows
- utiliser psutil si disponible, sinon fallback en subprocess
- être sûr, propre, sans risque pour le système

====================================================================
🔧 4) OPTIMISATION VS CODE
====================================================================

Tu vas :
- proposer une configuration VS Code pour réduire l’indexation
- désactiver les watchers inutiles
- réduire la charge Copilot
- optimiser les LSP Python et C++
- éviter les réindexations massives après refactoring

====================================================================
🧪 5) VALIDATION DES MICROSERVICES
====================================================================

Tu vas vérifier que :
- une seule instance de chaque microservice tourne
- whisper-server n’a qu’une seule instance
- les ports 8765–8772 ne sont utilisés qu’une fois
- launch_all ne crée plus jamais de doublons

====================================================================
📊 6) RAPPORT FINAL
====================================================================

Tu vas générer un rapport contenant :
- les doublons trouvés
- les corrections appliquées
- les protections ajoutées
- les scripts générés
- l’état final de la RAM
- l’état final des microservices

====================================================================
Commence maintenant par analyser les risques de doublons dans launch_all et les scripts microservices, puis propose les
patchs.
====================================================================

---
*Retour à l'index : [docs/README.md](../README.md)*
