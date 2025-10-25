import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

ApplicationWindow {
    id: window
    width: 800
    height: 600
    visible: true
    title: qsTr("Assistant Raspberry Pi 5 - Claude IA")
    
    Material.theme: Material.Dark
    Material.accent: Material.Cyan
    
    // Fonctions pour Claude API
    function sendMessage() {
        var message = messageInput.text.trim()
        if (message === "") {
            message = "Bonjour Henri, présente-toi brièvement"
        }
        
        responseArea.text = "🤔 Claude réfléchit..."
        messageInput.text = ""
        
        // Appel à l'API Claude via notre backend C++
        if (typeof claudeAPI !== 'undefined') {
            claudeAPI.sendMessage(message)
        } else {
            responseArea.text = "❌ Erreur: Claude API non disponible"
        }
    }
    
    // Connexions aux signaux Claude
    Connections {
        target: typeof claudeAPI !== 'undefined' ? claudeAPI : null
        function onResponseReceived(response) {
            responseArea.text = "🤖 Claude: " + response
            // Si le VoiceManager est disponible, faire parler Henri
            if (typeof voiceManager !== 'undefined') {
                voiceManager.speak(response)
            }
        }
        function onErrorOccurred(error) {
            responseArea.text = "❌ Erreur Claude: " + error
            if (typeof voiceManager !== 'undefined') {
                voiceManager.speak("Désolé, j'ai rencontré un problème technique.")
            }
        }
    }
    
    Rectangle {
        anchors.fill: parent
        color: Material.backgroundColor
        
        Column {
            anchors.centerIn: parent
            spacing: 20
            
            Text {
                text: "🤖 Assistant Raspberry Pi 5"
                color: "white"
                font.pixelSize: 32
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Avec Claude Haiku API et commandes vocales 🎤"
                color: Material.accent
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Statut des fonctionnalités
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                
                Row {
                    spacing: 8
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: typeof claudeAPI !== 'undefined' ? Material.color(Material.Green) : Material.color(Material.Red)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Claude IA"
                        color: "lightgray"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                Row {
                    spacing: 8
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: typeof voiceManager !== 'undefined' ? Material.color(Material.Green) : Material.color(Material.Red)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Voice 'Exo'"
                        color: "lightgray"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            
            Rectangle {
                width: 500
                height: 200
                color: Material.color(Material.BlueGrey, Material.Shade800)
                radius: 8
                anchors.horizontalCenter: parent.horizontalCenter
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Row {
                        width: parent.width
                        spacing: 8
                        
                        Text {
                            text: "💬 Chat avec Claude"
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: typeof claudeAPI !== 'undefined' ? Material.color(Material.Green) : Material.color(Material.Red)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: typeof claudeAPI !== 'undefined' ? "En ligne" : "Hors ligne"
                            color: "lightgray"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    ScrollView {
                        width: parent.width
                        height: 80
                        clip: true
                        
                        TextArea {
                            id: responseArea
                            text: "🏠 Bonjour ! Je suis Henri, votre assistant domotique IA.\n💬 Cliquez sur 'Tester Claude' pour commencer une conversation !\n\n✨ Fonctionnalités disponibles :\n• Chat intelligent avec Claude Haiku\n• Interface Material Design adaptée\n• API clé configurée et prête"
                            color: "white"
                            wrapMode: TextArea.Wrap
                            readOnly: true
                            selectByMouse: true
                            background: Rectangle {
                                color: Material.color(Material.BlueGrey, Material.Shade900)
                                radius: 4
                                border.color: Material.color(Material.Cyan, Material.Shade700)
                                border.width: 1
                            }
                        }
                    }
                    
                    Row {
                        width: parent.width
                        spacing: 8
                        
                        TextField {
                            id: messageInput
                            width: parent.width - testButton.width - parent.spacing
                            placeholderText: "Tapez votre message..."
                            color: "white"
                            onAccepted: sendMessage()
                        }
                        
                        Column {
                            spacing: 4
                            
                            Button {
                                id: testButton
                                text: "Tester Claude"
                                Material.background: Material.accent
                                onClicked: sendMessage()
                            }
                            
                            Row {
                                spacing: 4
                                
                                Button {
                                    text: "💡"
                                    width: 30
                                    height: 30
                                    Material.background: Material.color(Material.Orange)
                                    onClicked: {
                                        messageInput.text = "Peux-tu m'aider à contrôler mes lumières ?"
                                        sendMessage()
                                    }
                                }
                                
                                Button {
                                    text: "🌡️"
                                    width: 30
                                    height: 30
                                    Material.background: Material.color(Material.Blue)
                                    onClicked: {
                                        messageInput.text = "Comment optimiser le chauffage de ma maison ?"
                                        sendMessage()
                                    }
                                }
                                
                                Button {
                                    text: "🏠"
                                    width: 30
                                    height: 30
                                    Material.background: Material.color(Material.Green)
                                    onClicked: {
                                        messageInput.text = "Quelles sont les possibilités domotiques avec un Raspberry Pi ?"
                                        sendMessage()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Contrôles vocaux
            Rectangle {
                width: 500
                height: 120
                color: Material.color(Material.Teal, Material.Shade800)
                radius: 8
                anchors.horizontalCenter: parent.horizontalCenter
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: "🎤 Commandes Vocales (mot d'activation: 'Exo')"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    Row {
                        width: parent.width
                        spacing: 12
                        
                        Button {
                            id: listenButton
                            text: voiceManager && voiceManager.isListening ? "🔴 Arrêter" : "🎤 Écouter"
                            Material.background: voiceManager && voiceManager.isListening ? Material.color(Material.Red) : Material.color(Material.Green)
                            onClicked: {
                                if (voiceManager) {
                                    if (voiceManager.isListening) {
                                        voiceManager.stopListening()
                                    } else {
                                        voiceManager.startListening()
                                    }
                                }
                            }
                        }
                        
                        Text {
                            text: {
                                if (typeof voiceManager === 'undefined') return "Voice Manager non disponible"
                                if (voiceManager.isSpeaking) return "🗣️ Henri parle..."
                                if (voiceManager.isListening) return "👂 En écoute du mot 'Exo'..."
                                return "💤 En attente"
                            }
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14
                        }
                    }
                    
                    Text {
                        text: voiceManager ? "Dernière commande: " + voiceManager.lastCommand : "Aucune commande"
                        color: "lightgray"
                        font.pixelSize: 12
                        width: parent.width
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
    
    // Connexions aux signaux du VoiceManager
    Connections {
        target: typeof voiceManager !== 'undefined' ? voiceManager : null
        function onCommandDetected(command) {
            responseArea.text = "🎯 Commande vocale: " + command + "\n🤔 Claude traite la demande..."
            // La commande sera automatiquement envoyée à Claude via le C++
        }
        function onWakeWordDetected() {
            responseArea.text = "👋 'Exo' détecté ! Dites votre commande..."
        }
        function onVoiceError(error) {
            responseArea.text = "❌ Erreur vocale: " + error
        }
    }
}