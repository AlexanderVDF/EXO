import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Barre de statut système pour Raspberry Pi
Rectangle {
    id: root
    
    // Propriétés système
    property int batteryLevel: 100
    property real cpuUsage: 0.0
    property string currentStatus: "Prêt"
    
    // Configuration visuelle
    color: "#1a1a1a"
    radius: 15
    border.color: "#333333"
    border.width: 1
    
    // Effet de brillance
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#ffffff"; opacity: 0.05 }
            GradientStop { position: 1.0; color: "#ffffff"; opacity: 0.0 }
        }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 20
        
        // Horloge système
        Column {
            Layout.preferredWidth: 120
            
            Label {
                text: Qt.formatTime(new Date(), "hh:mm")
                font.pixelSize: 24
                font.weight: Font.Bold
                color: "#ffffff"
            }
            
            Label {
                text: Qt.formatDate(new Date(), "dd/MM/yyyy")
                font.pixelSize: 12
                color: "#cccccc"
            }
        }
        
        // Séparateur
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.margins: 10
            color: "#333333"
        }
        
        // Statut de l'assistant
        Column {
            Layout.fillWidth: true
            
            Label {
                text: "Assistant"
                font.pixelSize: 14
                color: "#cccccc"
                font.weight: Font.Medium
            }
            
            Label {
                text: currentStatus
                font.pixelSize: 16
                color: getStatusColor()
                width: parent.width
                elide: Text.ElideRight
                
                function getStatusColor() {
                    if (currentStatus.includes("Erreur")) return "#f44336"
                    if (currentStatus.includes("Traitement")) return "#ff9800"
                    if (currentStatus.includes("Écoute")) return "#4caf50"
                    return "#2196F3"
                }
                
                // Animation de clignotement pour états actifs
                SequentialAnimation on opacity {
                    running: currentStatus.includes("Écoute") || currentStatus.includes("Traitement")
                    loops: Animation.Infinite
                    
                    NumberAnimation { to: 0.5; duration: 1000 }
                    NumberAnimation { to: 1.0; duration: 1000 }
                }
            }
        }
        
        // Séparateur
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.margins: 10
            color: "#333333"
        }
        
        // Indicateurs système
        Row {
            Layout.preferredWidth: 200
            spacing: 15
            
            // CPU
            Column {
                width: 60
                
                Label {
                    text: "CPU"
                    font.pixelSize: 10
                    color: "#cccccc"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Rectangle {
                    width: parent.width
                    height: 20
                    radius: 10
                    color: "#333333"
                    
                    Rectangle {
                        width: (cpuUsage / 100) * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: getCpuColor()
                        
                        Behavior on width { 
                            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                        }
                        
                        function getCpuColor() {
                            if (cpuUsage > 80) return "#f44336"
                            if (cpuUsage > 60) return "#ff9800"
                            return "#4caf50"
                        }
                    }
                    
                    Label {
                        anchors.centerIn: parent
                        text: Math.round(cpuUsage) + "%"
                        font.pixelSize: 10
                        color: "#ffffff"
                        font.weight: Font.Bold
                    }
                }
            }
            
            // Batterie
            Column {
                width: 60
                
                Label {
                    text: "Batterie"
                    font.pixelSize: 10
                    color: "#cccccc"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Rectangle {
                    width: parent.width
                    height: 20
                    radius: 4
                    color: "#333333"
                    border.color: "#666666"
                    border.width: 1
                    
                    Rectangle {
                        width: (batteryLevel / 100) * (parent.width - 4)
                        height: parent.height - 4
                        x: 2
                        y: 2
                        radius: 2
                        color: getBatteryColor()
                        
                        Behavior on width { 
                            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                        }
                        
                        function getBatteryColor() {
                            if (batteryLevel < 15) return "#f44336"
                            if (batteryLevel < 30) return "#ff9800"
                            return "#4caf50"
                        }
                    }
                    
                    // Borne positive de la batterie
                    Rectangle {
                        width: 3
                        height: 8
                        x: parent.width
                        y: (parent.height - height) / 2
                        radius: 1
                        color: "#666666"
                    }
                    
                    Label {
                        anchors.centerIn: parent
                        text: batteryLevel + "%"
                        font.pixelSize: 10
                        color: "#ffffff"
                        font.weight: Font.Bold
                    }
                }
            }
            
            // Température (si disponible)
            Column {
                width: 50
                visible: false // À activer quand le monitoring température sera implémenté
                
                Label {
                    text: "Temp"
                    font.pixelSize: 10
                    color: "#cccccc"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Label {
                    text: "45°C"
                    font.pixelSize: 12
                    color: "#4caf50"
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.weight: Font.Medium
                }
            }
        }
        
        // Séparateur
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.margins: 10
            color: "#333333"
        }
        
        // Indicateurs de connexion
        Row {
            Layout.preferredWidth: 80
            spacing: 8
            
            // WiFi
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: "#4caf50" // Vert si connecté
                
                Label {
                    anchors.centerIn: parent
                    text: "📶"
                    font.pixelSize: 12
                }
                
                // Animation de pulsation si problème réseau
                SequentialAnimation on scale {
                    running: false // À activer selon l'état réseau
                    loops: Animation.Infinite
                    
                    NumberAnimation { to: 1.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }
            
            // Claude API
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: "#2196F3" // Bleu si connecté à Claude
                
                Label {
                    anchors.centerIn: parent
                    text: "🤖"
                    font.pixelSize: 12
                }
            }
            
            // Microphone
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: "#ff9800" // Orange si micro disponible
                
                Label {
                    anchors.centerIn: parent
                    text: "🎤"
                    font.pixelSize: 12
                }
            }
        }
    }
    
    // Timer pour mise à jour de l'horloge
    Timer {
        interval: 1000 // Mise à jour chaque seconde
        running: true
        repeat: true
        
        onTriggered: {
            // Force la mise à jour de l'affichage de l'heure
            // En changeant une propriété qui déclenche un rafraîchissement
            root.opacity = root.opacity
        }
    }
    
    // Animations d'alertes
    SequentialAnimation {
        id: lowBatteryAlert
        running: batteryLevel < 15
        loops: Animation.Infinite
        
        ColorAnimation {
            target: root
            property: "border.color"
            to: "#f44336"
            duration: 1000
        }
        ColorAnimation {
            target: root
            property: "border.color"
            to: "#333333"
            duration: 1000
        }
    }
    
    SequentialAnimation {
        id: highCpuAlert
        running: cpuUsage > 85
        loops: Animation.Infinite
        
        NumberAnimation {
            target: root
            property: "border.width"
            to: 3
            duration: 800
        }
        NumberAnimation {
            target: root
            property: "border.width"
            to: 1
            duration: 800
        }
    }
    
    // Gestion tactile pour accès rapide aux infos
    MouseArea {
        anchors.fill: parent
        
        onDoubleClicked: {
            // Ouvrir un popup avec infos détaillées du système
            detailsPopup.open()
        }
    }
    
    // Popup d'informations détaillées
    Popup {
        id: detailsPopup
        
        anchors.centerIn: parent
        width: 300
        height: 200
        
        modal: true
        Material.theme: Material.Dark
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            
            Label {
                text: "Informations Système"
                font.bold: true
                font.pixelSize: 18
                Layout.alignment: Qt.AlignHCenter
            }
            
            Label {
                text: "CPU: " + Math.round(cpuUsage) + "%"
                Layout.fillWidth: true
            }
            
            Label {
                text: "Batterie: " + batteryLevel + "%"
                Layout.fillWidth: true
            }
            
            Label {
                text: "Statut: " + currentStatus
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            
            Label {
                text: "Raspberry Pi 5 - Assistant Personnel"
                Layout.fillWidth: true
                font.italic: true
                color: "#cccccc"
            }
            
            Button {
                text: "Fermer"
                Layout.alignment: Qt.AlignHCenter
                onClicked: detailsPopup.close()
            }
        }
    }
}