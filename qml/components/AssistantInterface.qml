import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

// Interface principale de l'assistant optimisée pour écran tactile
Item {
    id: root
    
    // Propriétés d'état
    property bool isListening: false
    property bool isProcessing: false
    property string lastResponse: ""
    
    // Signaux pour interaction
    signal startListening()
    signal stopListening()
    signal sendTextQuery(string text)
    
    // Configuration tactile
    property int touchMargin: 20
    property int animationDuration: 300
    
    // Animation de fond réactive
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        
        // Effet de pulsation pendant l'écoute
        Rectangle {
            anchors.centerIn: parent
            width: isListening ? parent.width : 0
            height: isListening ? parent.height : 0
            radius: Math.min(width, height) / 2
            color: "#2196F3"
            opacity: isListening ? 0.1 : 0
            
            Behavior on width { NumberAnimation { duration: animationDuration } }
            Behavior on height { NumberAnimation { duration: animationDuration } }
            Behavior on opacity { NumberAnimation { duration: animationDuration } }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: touchMargin
        spacing: 30
        
        // Zone d'affichage principale
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 300
            
            color: "#1e1e1e"
            radius: 20
            border.color: isListening ? "#2196F3" : "#333333"
            border.width: 2
            
            Behavior on border.color { ColorAnimation { duration: animationDuration } }
            
            // Effet de brillance
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#ffffff"; opacity: 0.1 }
                    GradientStop { position: 1.0; color: "#ffffff"; opacity: 0.0 }
                }
            }
            
            ScrollView {
                anchors.fill: parent
                anchors.margins: 20
                
                clip: true
                
                ColumnLayout {
                    width: parent.width
                    spacing: 20
                    
                    // Message d'accueil ou état
                    Label {
                        Layout.fillWidth: true
                        text: getStatusMessage()
                        font.pixelSize: 24
                        font.weight: Font.Light
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        
                        function getStatusMessage() {
                            if (isProcessing) {
                                return "🤖 Claude réfléchit..."
                            } else if (isListening) {
                                return "🎤 Je vous écoute..."
                            } else if (lastResponse !== "") {
                                return "💬 Dernière réponse:"
                            } else {
                                return "👋 Bonjour ! Comment puis-je vous aider aujourd'hui ?"
                            }
                        }
                    }
                    
                    // Affichage de la dernière réponse
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumHeight: lastResponseText.contentHeight + 40
                        visible: lastResponse !== ""
                        
                        color: "#2a2a2a"
                        radius: 15
                        border.color: "#2196F3"
                        border.width: 1
                        
                        Label {
                            id: lastResponseText
                            anchors.fill: parent
                            anchors.margins: 20
                            
                            text: lastResponse
                            font.pixelSize: 18
                            color: "#ffffff"
                            wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                        }
                    }
                    
                    // Suggestions d'actions rapides
                    Flow {
                        Layout.fillWidth: true
                        spacing: 15
                        visible: !isListening && !isProcessing
                        
                        Repeater {
                            model: [
                                "Quelle heure est-il ?",
                                "Météo d'aujourd'hui",
                                "Nouvelles du jour",
                                "Aide-moi à...",
                                "Raconte-moi une blague"
                            ]
                            
                            Button {
                                text: modelData
                                flat: true
                                
                                Material.background: "#333333"
                                Material.foreground: "#ffffff"
                                
                                font.pixelSize: 16
                                
                                // Optimisation tactile
                                implicitHeight: 50
                                leftPadding: 20
                                rightPadding: 20
                                
                                onClicked: {
                                    root.sendTextQuery(text)
                                }
                                
                                // Effet hover tactile
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#2196F3"
                                    opacity: parent.pressed ? 0.2 : 0
                                    radius: 5
                                    
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Indicateurs visuels d'état
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            
            // Indicateur d'écoute
            Rectangle {
                Layout.preferredWidth: 60
                Layout.fillHeight: true
                
                color: isListening ? "#4caf50" : "#424242"
                radius: 30
                
                Behavior on color { ColorAnimation { duration: animationDuration } }
                
                Label {
                    anchors.centerIn: parent
                    text: "🎤"
                    font.pixelSize: 24
                    color: "white"
                }
                
                // Animation de pulsation pendant l'écoute
                SequentialAnimation on scale {
                    running: isListening
                    loops: Animation.Infinite
                    
                    NumberAnimation { to: 1.1; duration: 500; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                }
            }
            
            // Barre de progression d'état
            ProgressBar {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                
                indeterminate: isProcessing
                value: isListening ? 1.0 : 0.0
                
                Material.accent: isProcessing ? "#ff9800" : "#4caf50"
                
                Behavior on value { NumberAnimation { duration: animationDuration } }
            }
            
            // Indicateur de traitement
            Rectangle {
                Layout.preferredWidth: 60
                Layout.fillHeight: true
                
                color: isProcessing ? "#ff9800" : "#424242"
                radius: 30
                
                Behavior on color { ColorAnimation { duration: animationDuration } }
                
                Label {
                    anchors.centerIn: parent
                    text: "🤖"
                    font.pixelSize: 24
                    color: "white"
                }
                
                // Animation de rotation pendant le traitement
                RotationAnimation on rotation {
                    running: isProcessing
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 2000
                }
            }
        }
    }
    
    // Gestes tactiles avancés
    PinchArea {
        anchors.fill: parent
        enabled: true
        
        onPinchStarted: {
            // Commencer un zoom/dézoom sur la réponse
        }
        
        onPinchUpdated: {
            // Ajuster la taille de police dynamiquement
            if (pinch.scale > 1.0) {
                lastResponseText.font.pixelSize = Math.min(24, lastResponseText.font.pixelSize + 1)
            } else if (pinch.scale < 1.0) {
                lastResponseText.font.pixelSize = Math.max(12, lastResponseText.font.pixelSize - 1)
            }
        }
    }
    
    // Feedback haptique (si supporté par le hardware)
    Timer {
        id: hapticTimer
        interval: 100
        onTriggered: {
            // Ici on pourrait déclencher un retour haptique
            // via un module natif ou GPIO
        }
    }
    
    // Animations d'entrée/sortie  
    PropertyAnimation {
        id: opacityAnim
        target: root
        property: "opacity"
        to: 1.0
        duration: 500
        easing.type: Easing.OutCubic
    }
    
    PropertyAnimation {
        id: scaleAnim
        target: root
        property: "scale" 
        to: 1.0
        duration: 500
        easing.type: Easing.OutBack
    }
    
    Component.onCompleted: {
        // Animation d'apparition douce
        opacity = 0
        scale = 0.9
        opacityAnim.start()
        scaleAnim.start()
    }
}