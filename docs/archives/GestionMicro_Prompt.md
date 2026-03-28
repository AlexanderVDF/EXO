Je veux que tu ajoutes un système complet de gestion du microphone dans EXO Assistant v4.2.
Voici les fonctionnalités à implémenter, dans cet ordre, avec code C++ + QML + intégration pipeline :

====================================================================
🎯 OBJECTIF GLOBAL
====================================================================

Créer un système robuste, modulaire et complet pour gérer les microphones :

1. Détection automatique du micro (RtAudio)
2. Sélection manuelle du micro dans l’UI (QML)
3. Message d’erreur clair si aucun micro n’est disponible
4. Fallback automatique en mode clavier
5. Test audio intégré (vumètre + enregistrement + playback)
6. HealthCheck audio (comme STT/TTS/VAD)
7. Module C++ dédié : AudioDeviceManager
8. Intégration dans VoicePipeline
9. Mise à jour de SettingsPanel.qml

====================================================================
🟦 1) MODULE C++ : AudioDeviceManager
====================================================================

Créer un module C++ :

src/audio/AudioDeviceManager.h
src/audio/AudioDeviceManager.cpp

Fonctionnalités :

- Scanner tous les devices RtAudio
- Filtrer ceux avec inputChannels > 0
- Fournir au QML :
    QStringList inputDevices()
    int defaultInputDevice()
    bool setInputDevice(int index)
    bool hasValidInputDevice()
    QString lastError()
- Signaux :
    inputDeviceChanged()
    audioError(QString)

Le module doit :
- détecter automatiquement un micro valide
- stocker l’index du micro sélectionné
- exposer les erreurs RtAudio
- être enregistré dans QML sous "AudioDeviceManager"

====================================================================
🟩 2) INTÉGRATION DANS VoicePipeline (C++)
====================================================================

Avant d’ouvrir le stream audio :

if (!audioDeviceManager->hasValidInputDevice()) {
    emit audioError("Aucun microphone détecté");
    emit audioUnavailable();
    return;
}

Si l’utilisateur change de micro :
- fermer le stream
- rouvrir avec le nouveau device
- émettre audioReady()

Ajouter un signal :
- audioUnavailable()
- audioReady()

====================================================================
🟧 3) HEALTHCHECK AUDIO
====================================================================

Créer un HealthCheck "audio" comme les autres microservices :

- ping du stream RtAudio
- vérifier que le stream est ouvert
- statut : healthy / down

Exposer dans QML :
- audioStatus : "healthy" | "down"

====================================================================
🟨 4) UI QML : SettingsPanel.qml
====================================================================

Ajouter :

- ComboBox listant les devices audio :
    model: audioDeviceManager.inputDevices()

- Bouton "Définir comme micro par défaut"
- Bouton "Tester le micro"
- Vumètre (Rectangle + binding sur niveau RMS)
- Message d’erreur si aucun micro :
    "Aucun microphone détecté — vérifiez vos paramètres Windows."

- Bouton "Ouvrir les paramètres Windows"
    Qt.openUrlExternally("ms-settings:sound")

====================================================================
🟫 5) FALLBACK CLAVIER
====================================================================

Si aucun micro n’est disponible :

- désactiver l’écoute permanente
- afficher un champ texte dans la zone de chat
- afficher un message :
    "Mode vocal indisponible — passage en mode clavier."

- ne pas tenter de rouvrir le stream tant qu’un micro n’est pas sélectionné

====================================================================
🟪 6) TEST AUDIO
====================================================================

Dans AudioDeviceManager :

- ouvrir un stream input
- mesurer RMS → envoyer au QML pour vumètre
- enregistrer 1 seconde dans un buffer
- rejouer via RtAudio output
- renvoyer un booléen success/failure

====================================================================
🟫 7) BANNIÈRE D’ERREUR DANS L’UI
====================================================================

Ajouter un composant QML :

Rectangle {
    visible: !audioDeviceManager.hasValidInputDevice()
    color: "#FF5555"
    Text { text: "Aucun microphone détecté — vérifiez vos paramètres audio Windows." }
    Button { text: "Ouvrir les paramètres"; onClicked: Qt.openUrlExternally("ms-settings:sound") }
}

====================================================================
🟦 8) EXPOSITION AU QML
====================================================================

Dans main.cpp :

qmlRegisterSingletonInstance("EXO.Audio", 1, 0, "AudioDeviceManager", audioDeviceManager);

====================================================================
🟩 9) COMPORTEMENT ATTENDU
====================================================================

- Si un micro existe → EXO démarre normalement
- Si aucun micro → EXO affiche une bannière + fallback clavier
- Si l’utilisateur sélectionne un micro → EXO redémarre le stream
- Si le micro disparaît → HealthCheck audio passe en "down"
- Si le micro revient → HealthCheck audio passe en "healthy"
- Le test audio fonctionne depuis les paramètres
- Le vumètre réagit en temps réel

====================================================================
Commence maintenant par générer le module C++ AudioDeviceManager complet (header + cpp), puis propose les patchs
VoicePipeline et QML.
====================================================================

---
Retour à l'index : [docs/README.md](../README.md)
