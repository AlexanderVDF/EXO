import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: chatSection
    
    property var assistant: null
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        
        // Zone de conversation
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Rectangle {
                width: parent.width
                height: Math.max(chatContent.height, parent.height)
                color: Qt.rgba(0, 0, 0, 0.2)
                radius: 10
                
                Column {
                    id: chatContent
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10
                    
                    // Message de bienvenue
                    Rectangle {
                        width: parent.width * 0.8
                        height: welcomeText.height + 20
                        color: "#00BCD4"
                        radius: 15
                        
                        Text {
                            id: welcomeText
                            anchors.centerIn: parent
                            anchors.margins: 10
                            text: "🤖 Bonjour ! Je suis EXO, votre assistant personnel.\nComment puis-je vous aider aujourd'hui ?"
                            color: "white"
                            font.pixelSize: 16
                            wrapMode: Text.Wrap
                            width: parent.width - 20
                            horizontalAlignment: Text.AlignHCenter
                        }
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
                
                // Bouton micro
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: "#FF5722"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🎙️"
                        font.pixelSize: 18
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // TODO: Démarrer reconnaissance vocale
                            console.log("Reconnaissance vocale")
                        }
                    }
                }
                
                // Bouton envoyer
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: "#4CAF50"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "➤"
                        font.pixelSize: 18
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: sendMessage()
                    }
                }
            }
        }
    }
    
    function sendMessage() {
        if (messageInput.text.trim() !== "") {
            // TODO: Envoyer message à Claude
            console.log("Message:", messageInput.text)
            messageInput.clear()
        }
    }
}