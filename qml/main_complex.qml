import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

import "components" as Components

ApplicationWindow {
    id: mainWindow
    
    visible: true
    width: 1920  // Résolution typique écran tactile 7" pour RPi
    height: 1080
    title: "Assistant Personnel - Raspberry Pi 5"
    
    // Configuration Material Design sombre pour écran tactile
    Material.theme: Material.Dark
    Material.accent: "#2196F3"
    Material.primary: "#1976D2"
    
    // Propriétés pour l'interface tactile
    property bool fullscreenMode: true
    property bool touchOptimized: true
    property int touchMargin: 20
    
    // Connexion au gestionnaire d'assistant
    property var assistant: assistantManager
    
    // État de l'interface
    property bool isListening: assistant ? assistant.isListening : false
    property bool isProcessing: assistant ? assistant.isProcessing : false
    property string currentStatus: assistant ? assistant.currentStatus : "Initialisation..."
    
    // Configuration plein écran pour Raspberry Pi
    Component.onCompleted: {
        if (fullscreenMode) {
            showFullScreen()
        }
    }
    
    // Fond dégradé moderne
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0d1421" }
            GradientStop { position: 0.5; color: "#1a237e" }
            GradientStop { position: 1.0; color: "#000051" }
        }
    }
    
    // Layout principal
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: touchMargin
        spacing: 30
        
        // Barre de statut système
        Components.StatusBar {
            id: statusBar
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            
            batteryLevel: assistant ? assistant.batteryLevel : 100
            cpuUsage: assistant ? assistant.cpuUsage : 0
            currentStatus: mainWindow.currentStatus
        }
        
        // Interface principale de l'assistant
        Components.AssistantInterface {
            id: assistantInterface
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            isListening: mainWindow.isListening
            isProcessing: mainWindow.isProcessing
            lastResponse: assistant ? assistant.lastResponse : ""
            
            onStartListening: assistant.startListening()
            onStopListening: assistant.stopListening()
            onSendTextQuery: assistant.sendTextQuery(text)
        }
        
        // Barre d'actions rapides
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            spacing: 20
            
            // Bouton micro principal
            Components.TouchButton {
                id: micButton
                Layout.preferredWidth: 120
                Layout.preferredHeight: 100
                
                icon: "qrc:/resources/icons/microphone.svg"
                text: isListening ? "Arrêter" : "Parler"
                primaryColor: isListening ? "#f44336" : "#4caf50"
                touchOptimized: true
                
                onClicked: {
                    if (isListening) {
                        assistant.stopListening()
                    } else {
                        assistant.startListening()
                    }
                }
            }
            
            // Zone de saisie texte tactile
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                
                TextArea {
                    id: textInput
                    placeholderText: "Tapez votre question ici..."
                    wrapMode: TextArea.Wrap
                    font.pixelSize: 18
                    selectByMouse: true
                    
                    Material.accent: "#2196F3"
                    
                    // Optimisation tactile
                    property int touchMargin: 15
                    leftPadding: touchMargin
                    rightPadding: touchMargin
                    topPadding: touchMargin
                    bottomPadding: touchMargin
                    
                    Keys.onReturnPressed: {
                        if (text.trim() !== "") {
                            assistant.sendTextQuery(text)
                            text = ""
                        }
                    }
                }
            }
            
            // Bouton d'envoi
            Components.TouchButton {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 100
                
                icon: "qrc:/resources/icons/send.svg"
                text: "Envoyer"
                primaryColor: "#2196F3"
                enabled: textInput.text.trim() !== "" && !isProcessing
                
                onClicked: {
                    if (textInput.text.trim() !== "") {
                        assistant.sendTextQuery(textInput.text)
                        textInput.text = ""
                    }
                }
            }
            
            // Bouton paramètres
            Components.TouchButton {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                
                icon: "qrc:/resources/icons/settings.svg"
                text: "Config"
                primaryColor: "#757575"
                
                onClicked: settingsDialog.open()
            }
        }
    }
    
    // Visualiseur vocal (affiché pendant l'écoute)
    Components.VoiceVisualizer {
        id: voiceVisualizer
        anchors.centerIn: parent
        width: 300
        height: 300
        visible: isListening
        opacity: isListening ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }
    
    // Indicateur de traitement
    BusyIndicator {
        anchors.centerIn: parent
        width: 100
        height: 100
        visible: isProcessing
        running: isProcessing
        
        Material.accent: "#2196F3"
    }
    
    // Dialog des paramètres
    Dialog {
        id: settingsDialog
        
        anchors.centerIn: parent
        width: Math.min(mainWindow.width * 0.8, 600)
        height: Math.min(mainWindow.height * 0.8, 500)
        
        title: "Paramètres de l'Assistant"
        modal: true
        
        Material.theme: Material.Dark
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 20
            
            // Contrôle du volume
            RowLayout {
                Layout.fillWidth: true
                
                Label {
                    text: "Volume:"
                    font.pixelSize: 16
                }
                
                Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0.0
                    to: 1.0
                    value: 0.7
                    
                    onValueChanged: {
                        if (assistant) {
                            assistant.adjustVolume(value)
                        }
                    }
                }
                
                Label {
                    text: Math.round(volumeSlider.value * 100) + "%"
                    font.pixelSize: 14
                }
            }
            
            // Informations système
            GroupBox {
                title: "Système"
                Layout.fillWidth: true
                
                ColumnLayout {
                    anchors.fill: parent
                    
                    Label {
                        text: "CPU: " + (assistant ? Math.round(assistant.cpuUsage) + "%" : "0%")
                        font.pixelSize: 14
                    }
                    
                    Label {
                        text: "Batterie: " + (assistant ? assistant.batteryLevel + "%" : "100%")
                        font.pixelSize: 14
                    }
                    
                    Label {
                        text: "Statut: " + currentStatus
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }
                }
            }
            
            // Actions système
            RowLayout {
                Layout.fillWidth: true
                
                Button {
                    text: "Redémarrer"
                    Material.background: "#ff9800"
                    Layout.fillWidth: true
                    
                    onClicked: {
                        settingsDialog.close()
                        assistant.reboot()
                    }
                }
                
                Button {
                    text: "Éteindre"
                    Material.background: "#f44336"
                    Layout.fillWidth: true
                    
                    onClicked: {
                        settingsDialog.close()
                        assistant.shutdown()
                    }
                }
            }
        }
    }
    
    // Gestion des erreurs
    Popup {
        id: errorPopup
        
        anchors.centerIn: parent
        width: Math.min(mainWindow.width * 0.7, 400)
        height: 150
        
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        Material.theme: Material.Dark
        Material.background: "#d32f2f"
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            
            Label {
                text: "Erreur"
                font.bold: true
                font.pixelSize: 18
                color: "white"
            }
            
            Label {
                id: errorText
                text: ""
                color: "white"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            
            Button {
                text: "OK"
                Layout.alignment: Qt.AlignRight
                
                onClicked: errorPopup.close()
            }
        }
    }
    
    // Connexions aux signaux de l'assistant
    Connections {
        target: assistant
        
        function onErrorOccurred(error) {
            errorText.text = error
            errorPopup.open()
        }
        
        function onResponseReceived(response) {
            // L'interface se met à jour automatiquement via les propriétés
        }
    }
    
    // Gestion des gestes tactiles
    MultiPointTouchArea {
        anchors.fill: parent
        enabled: touchOptimized
        
        // Geste de balayage vers le bas pour rafraîchir
        property real lastY: 0
        
        onPressed: {
            lastY = touchPoints[0].y
        }
        
        onUpdated: {
            if (touchPoints.length === 1) {
                var deltaY = touchPoints[0].y - lastY
                if (deltaY > 100 && touchPoints[0].y < 200) {
                    // Rafraîchissement par balayage
                    assistant.initialize()
                }
            }
        }
    }
}