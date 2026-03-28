> 🧭 [Index](../README.md) → [Prompts](../README.md#-prompts-historiques--prompts) → prompt_validation.md

---
Je veux que tu réalises une validation fonctionnelle complète du pipeline EXO maintenant que tous les microservices sont
en écoute.
L’objectif est de vérifier que chaque service répond correctement, que les WebSockets fonctionnent, que les ports sont
corrects, et que le pipeline audio complet est opérationnel.

Voici les tâches précises :

====================================================================
🎯 OBJECTIF GLOBAL
====================================================================

Valider le fonctionnement réel de tous les microservices EXO :

exo_server (8765)
stt_server (8766)
tts_server (8767, fallback CPU)
vad_server (8768)
whisper-server interne (8769)
wakeword_server (8770)
memory_server (8771)
nlu_server (8772)

Et vérifier que le pipeline complet fonctionne :
wakeword → VAD → STT → NLU → TTS → audio output

====================================================================
🧪 1) TEST DES PORTS ET DES WEBSOCKETS
====================================================================

Pour chaque service :
- tester la connexion WebSocket
- envoyer un message de test minimal
- vérifier la réponse JSON
- vérifier le délai de réponse
- vérifier que le service ne renvoie pas d’erreur
- générer un rapport clair

====================================================================
🧪 2) TEST DU WAKEWORD
====================================================================

- vérifier que le wakeword_server répond à un ping
- vérifier que le modèle est chargé
- vérifier que l’activation/désactivation fonctionne
- vérifier que le message “wakeword_detected” est bien émis

====================================================================
🧪 3) TEST DU VAD
====================================================================

- envoyer un court buffer audio silencieux
- vérifier que le VAD renvoie “no speech”
- envoyer un buffer audio contenant de la voix (synthetisé)
- vérifier que le VAD renvoie “speech detected”

====================================================================
🧪 4) TEST DU STT
====================================================================

- envoyer un petit échantillon audio (synthetisé)
- vérifier que le STT renvoie un texte cohérent
- vérifier que le serveur Whisper interne répond correctement

====================================================================
🧪 5) TEST DU TTS (fallback CPU)
====================================================================

- envoyer un texte simple
- vérifier que le TTS renvoie un buffer audio valide
- vérifier que le format audio est correct
- vérifier que le délai de réponse est raisonnable
- vérifier que le fallback CPU est bien actif

====================================================================
🧪 6) TEST DU MEMORY SERVER
====================================================================

- envoyer une requête “store”
- envoyer une requête “query”
- vérifier que la mémoire répond correctement

====================================================================
🧪 7) TEST DU NLU
====================================================================

- envoyer une phrase simple (“quelle heure est-il”)
- vérifier que le NLU renvoie une intention correcte
- vérifier que les entités sont extraites

====================================================================
🧪 8) TEST DU PIPELINE COMPLET
====================================================================

Simuler une interaction complète :
1. wakeword_detected
2. VAD active
3. STT transcrit
4. NLU interprète
5. TTS génère une réponse
6. audio renvoyé

Vérifier que :
- chaque étape renvoie un message valide
- aucune erreur n’apparaît
- les délais sont cohérents
- le pipeline complet fonctionne de bout en bout

====================================================================
🧪 9) RAPPORT FINAL
====================================================================

Générer un rapport clair contenant :
- les services testés
- les résultats
- les latences
- les erreurs éventuelles
- les corrections proposées

====================================================================
Commence maintenant par tester les WebSockets et les ports de tous les services, puis propose le plan de validation
complet.
====================================================================

---
*Retour à l'index : [docs/README.md](../README.md)*
