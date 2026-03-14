import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: chatSection
    objectName: "chatSection"
    
    property var assistant: null
    property alias messageModel: messageModel
    
    // Modèle pour les messages
    ListModel {
        id: messageModel
        // Le message d'accueil sera ajouté par AssistantManager
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        
        // Barre de statut vocal
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.3)
            visible: assistant && assistant.isListening
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                
                // Icône microphone animée
                Text {
                    text: "🎙️"
                    font.pixelSize: 20
                    
                    // Animation de rotation subtile
                    RotationAnimation on rotation {
                        running: assistant && assistant.isListening
                        loops: Animation.Infinite
                        from: -5
                        to: 5
                        duration: 1500
                    }
                }
                
                Text {
                    text: "EXO vous écoute... Dites votre commande"
                    color: "#00BCD4"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }
                
                // Indicateur de niveau sonore (simulation)
                Row {
                    spacing: 2
                    Repeater {
                        model: 5
                        Rectangle {
                            width: 3
                            height: 8 + (index * 4)
                            radius: 2
                            color: "#00BCD4"
                            opacity: (Math.random() * 0.7) + 0.3
                            
                            SequentialAnimation on opacity {
                                running: assistant && assistant.isListening
                                loops: Animation.Infinite
                                PropertyAnimation {
                                    to: 0.3
                                    duration: 300 + (index * 100)
                                }
                                PropertyAnimation {
                                    to: 1.0
                                    duration: 300 + (index * 100)
                                }
                            }
                        }
                    }
                }
            }
            
            // Animation d'apparition/disparition
            Behavior on visible {
                NumberAnimation { duration: 300 }
            }
        }
        
        // Zone de conversation
        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Rectangle {
                width: parent.width
                height: Math.max(messageListView.contentHeight + 30, scrollView.height)
                color: Qt.rgba(0, 0, 0, 0.2)
                radius: 10
                
                ListView {
                    id: messageListView
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10
                    model: messageModel
                    
                    delegate: Item {
                        width: messageListView.width
                        height: messageRect.height + 10
                        
                        Rectangle {
                            id: messageRect
                            width: Math.min(messageText.implicitWidth + 40, parent.width * 0.8)
                            height: messageText.implicitHeight + 20
                            radius: 15
                            
                            // Alignement des messages
                            anchors.right: model.isUser ? parent.right : undefined
                            anchors.left: model.isUser ? undefined : parent.left
                            
                            // Couleur selon l'expéditeur
                            color: model.isUser ? "#4CAF50" : "#00BCD4"
                            
                            Text {
                                id: messageText
                                anchors.centerIn: parent
                                anchors.margins: 20
                                text: model.message
                                color: "white"
                                font.pixelSize: 14
                                wrapMode: Text.Wrap
                                width: Math.min(implicitWidth, messageRect.width - 40)
                                horizontalAlignment: model.isUser ? Text.AlignRight : Text.AlignLeft
                            }
                        }
                    }
                    
                    // Auto-scroll vers le bas
                    onCountChanged: {
                        Qt.callLater(() => {
                            messageListView.positionViewAtEnd()
                        })
                    }
                }
            }
        }
        
        // Barre de saisie
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: Qt.rgba(0, 0, 0, 0.3)
            radius: 30
            border.color: "#00BCD4"
            border.width: 2
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                
                TextField {
                    id: messageInput
                    Layout.fillWidth: true
                    placeholderText: "Tapez votre message..."
                    background: Rectangle { color: "transparent" }
                    color: "white"
                    font.pixelSize: 16
                    
                    Keys.onReturnPressed: sendMessage()
                }
                
                // Bouton micro amélioré
                Rectangle {
                    id: micButton
                    width: 50
                    height: 50
                    radius: 25
                    color: assistant && assistant.isListening ? "#4CAF50" : "#FF5722"
                    border.width: 2
                    border.color: Qt.lighter(color, 1.3)
                    
                    // Effet hover
                    scale: micMouseArea.pressed ? 0.95 : (micMouseArea.containsMouse ? 1.05 : 1.0)
                    
                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: assistant && assistant.isListening ? "⏹️" : "🎙️"
                        font.pixelSize: 20
                    }
                    
                    MouseArea {
                        id: micMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            if (assistant) {
                                if (assistant.isListening) {
                                    assistant.stopListening()
                                } else {
                                    assistant.startListening()
                                    // Message visuel pour l'utilisateur
                                    messageModel.append({
                                        "sender": "Système",
                                        "message": "🎙️ Écoute manuelle activée - Dites 'EXO' puis votre commande",
                                        "timestamp": new Date(),
                                        "isUser": false
                                    })
                                }
                            }
                        }
                    }
                    
                    // Tooltip
                    ToolTip {
                        visible: micMouseArea.containsMouse
                        text: assistant && assistant.isListening ? "Arrêter l'écoute" : "Commencer l'écoute"
                        delay: 1000
                    }
                    
                    // Indicateur d'écoute plus subtil - animation de couleur uniquement
                    Rectangle {
                        id: listeningIndicator
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: parent.radius + 4
                        color: "transparent"
                        border.width: 3
                        border.color: assistant && assistant.isListening ? "#00BCD4" : "transparent"
                        opacity: assistant && assistant.isListening ? 1 : 0
                        
                        // Animation douce de l'opacité du contour
                        SequentialAnimation {
                            running: assistant && assistant.isListening
                            loops: Animation.Infinite
                            PropertyAnimation {
                                target: listeningIndicator
                                property: "opacity"
                                from: 0.3
                                to: 1.0
                                duration: 800
                            }
                            PropertyAnimation {
                                target: listeningIndicator
                                property: "opacity"
                                from: 1.0
                                to: 0.3
                                duration: 800
                            }
                        }
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 300 }
                        }
                        
                        Behavior on border.color {
                            ColorAnimation { duration: 300 }
                        }
                    }
                }
                
                // Bouton désactiver écoute automatique amélioré
                Rectangle {
                    id: autoListenButton
                    width: 50
                    height: 50
                    radius: 25
                    color: voiceListeningEnabled ? "#FF9800" : "#757575"
                    border.width: 2
                    border.color: Qt.lighter(color, 1.3)
                    
                    property bool voiceListeningEnabled: true
                    
                    // Effet hover
                    scale: autoListenMouseArea.pressed ? 0.95 : (autoListenMouseArea.containsMouse ? 1.05 : 1.0)
                    
                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: parent.voiceListeningEnabled ? "👂" : "🔇"
                        font.pixelSize: 18
                    }
                    
                    MouseArea {
                        id: autoListenMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            parent.voiceListeningEnabled = !parent.voiceListeningEnabled
                            if (assistant) {
                                if (!parent.voiceListeningEnabled && assistant.isListening) {
                                    assistant.stopListening()
                                }
                            }
                            
                            messageModel.append({
                                "sender": "Système", 
                                "message": parent.voiceListeningEnabled ? 
                                          "👂 Écoute automatique réactivée" : 
                                          "🔇 Écoute automatique désactivée",
                                "timestamp": new Date(),
                                "isUser": false
                            })
                        }
                    }
                    
                    // Tooltip
                    ToolTip {
                        visible: autoListenMouseArea.containsMouse
                        text: parent.voiceListeningEnabled ? 
                              "Désactiver l'écoute automatique" : 
                              "Réactiver l'écoute automatique"
                        delay: 1000
                    }
                }
                
                // Bouton envoyer amélioré
                Rectangle {
                    id: sendButton
                    width: 50
                    height: 50
                    radius: 25
                    color: messageInput.text.trim() !== "" ? "#4CAF50" : "#757575"
                    border.width: 2
                    border.color: Qt.lighter(color, 1.3)
                    enabled: messageInput.text.trim() !== ""
                    
                    // Effet hover
                    scale: sendMouseArea.pressed ? 0.95 : (sendMouseArea.containsMouse ? 1.05 : 1.0)
                    
                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "➤"
                        font.pixelSize: 20
                        color: "white"
                    }
                    
                    MouseArea {
                        id: sendMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: parent.enabled
                        
                        onClicked: sendMessage()
                    }
                    
                    // Tooltip
                    ToolTip {
                        visible: sendMouseArea.containsMouse
                        text: "Envoyer le message"
                        delay: 1000
                    }
                }
            }
        }
    }
    
    // Connexions aux signaux de l'assistant
    Connections {
        target: assistant
        function onMessageReceived(sender, message) {
            // Ajouter la réponse de l'assistant au modèle
            messageModel.append({
                "sender": sender,
                "message": message,
                "timestamp": new Date(),
                "isUser": false
            })
        }
    }
    
    // Connexion aux réponses de Claude
    Connections {
        target: assistant
        function onClaudeResponseReceived(response) {
            // Remplacer le message "je réfléchis" par la vraie réponse
            if (messageModel.count > 0 && 
                messageModel.get(messageModel.count - 1).message.includes("🤔 Je réfléchis")) {
                messageModel.remove(messageModel.count - 1)
            }
            
            // Ajouter la réponse de Claude
            messageModel.append({
                "sender": "EXO",
                "message": response,
                "timestamp": new Date(),
                "isUser": false
            })
        }
    }
    
    function sendMessage() {
        var userMessage = messageInput.text.trim()
        if (userMessage !== "") {
            // Ajouter le message de l'utilisateur au modèle
            messageModel.append({
                "sender": "Utilisateur",
                "message": userMessage,
                "timestamp": new Date(),
                "isUser": true
            })
            
            // Envoyer le message à l'assistant via l'API
            if (assistant) {
                console.log("Envoi du message à l'assistant:", userMessage)
                assistant.sendMessage(userMessage)
                
                // Message temporaire en attendant la réponse
                messageModel.append({
                    "sender": "EXO",
                    "message": "🤔 Je réfléchis à votre question...",
                    "timestamp": new Date(),
                    "isUser": false
                })
            } else {
                console.error("Assistant non disponible")
                // Message d'erreur si l'assistant n'est pas initialisé
                messageModel.append({
                    "sender": "Système",
                    "message": "❌ Assistant non disponible. Vérifiez la configuration.",
                    "timestamp": new Date(),
                    "isUser": false
                })
            }
            
            messageInput.clear()
        }
    }
}