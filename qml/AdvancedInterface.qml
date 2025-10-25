import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt3D.Core 2.15
import Qt3D.Render 2.15
import Qt3D.Extras 2.15

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 1920
    height: 1080
    title: "Assistant Domotique Intelligent - Raspberry Pi 5"
    
    Material.theme: Material.Dark
    Material.primary: Material.BlueGrey
    Material.accent: Material.Cyan
    
    // Propriétés principales
    property bool isVoiceActive: false
    property string currentRoom: "salon"
    property bool isStreaming: false
    property int currentView: 0 // 0=Accueil, 1=Domotique, 2=3D, 3=Musique, 4=Google
    
    // Header principal avec navigation
    header: Rectangle {
        height: 80
        color: Material.color(Material.BlueGrey, Material.Shade800)
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            
            // Logo et titre
            Row {
                spacing: 12
                
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: Material.accent
                    
                    Text {
                        anchors.centerIn: parent
                        text: "AI"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 18
                    }
                }
                
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        text: "Assistant Domotique"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    
                    Text {
                        text: "Raspberry Pi 5 • Henri Voice • Claude Haiku"
                        color: Material.color(Material.Grey, Material.Shade300)
                        font.pixelSize: 12
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Navigation principale
            Row {
                spacing: 8
                
                TabButton {
                    text: "🏠 Accueil"
                    checked: currentView === 0
                    onClicked: currentView = 0
                }
                
                TabButton {
                    text: "🏡 Domotique"
                    checked: currentView === 1
                    onClicked: currentView = 1
                }
                
                TabButton {
                    text: "🏗️ Plan 3D"
                    checked: currentView === 2
                    onClicked: currentView = 2
                }
                
                TabButton {
                    text: "🎵 Musique"
                    checked: currentView === 3
                    onClicked: currentView = 3
                }
                
                TabButton {
                    text: "📧 Google"
                    checked: currentView === 4
                    onClicked: currentView = 4
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Indicateurs d'état
            Row {
                spacing: 16
                
                // Indicateur vocal
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: isVoiceActive ? Material.accent : Material.color(Material.Grey, Material.Shade600)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🎤"
                        font.pixelSize: 16
                    }
                    
                    SequentialAnimation on opacity {
                        running: isVoiceActive
                        loops: Animation.Infinite
                        
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }
                
                // Status système
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        text: "CPU: 45°C • RAM: 2.1GB"
                        color: Material.color(Material.Grey, Material.Shade300)
                        font.pixelSize: 10
                    }
                    
                    Text {
                        text: "📶 WiFi • 🔗 Claude • 🎵 Tidal"
                        color: Material.color(Material.Cyan, Material.Shade300)
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
    
    // Contenu principal avec vue conditionnelle
    StackLayout {
        anchors.fill: parent
        currentIndex: currentView
        
        // Vue 0: Accueil avec résumé intelligent
        HomeView {
            id: homeView
        }
        
        // Vue 1: Contrôle domotique EZVIZ
        SmartHomeView {
            id: smartHomeView
        }
        
        // Vue 2: Designer de pièces 3D
        RoomDesigner3D {
            id: roomDesigner
        }
        
        // Vue 3: Streaming musical
        MusicStreamView {
            id: musicView
        }
        
        // Vue 4: Services Google
        GoogleServicesView {
            id: googleView
        }
    }
    
    // Panel vocal flottant (toujours visible)
    Rectangle {
        id: voicePanel
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        
        width: 320
        height: 80
        radius: 40
        color: Material.color(Material.BlueGrey, Material.Shade900)
        border.color: isVoiceActive ? Material.accent : "transparent"
        border.width: 2
        
        Row {
            anchors.centerIn: parent
            spacing: 16
            
            // Bouton micro principal
            RoundButton {
                width: 56
                height: 56
                
                Material.background: isVoiceActive ? Material.accent : Material.color(Material.BlueGrey, Material.Shade600)
                
                Text {
                    anchors.centerIn: parent
                    text: "🎤"
                    font.pixelSize: 20
                }
                
                onPressed: {
                    isVoiceActive = true
                    // TODO: Démarrer l'enregistrement vocal
                }
                
                onReleased: {
                    isVoiceActive = false
                    // TODO: Traiter la commande vocale
                }
            }
            
            Column {
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: isVoiceActive ? "🎙️ J'écoute..." : "Dites \"Hey Henri\" ou appuyez"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: isVoiceActive
                }
                
                Text {
                    text: isVoiceActive ? "Parlez maintenant" : "Assistant vocal avec Claude Haiku"
                    color: Material.color(Material.Grey, Material.Shade400)
                    font.pixelSize: 11
                }
            }
            
            // Visualiseur audio
            Row {
                spacing: 2
                visible: isVoiceActive
                
                Repeater {
                    model: 8
                    
                    Rectangle {
                        width: 3
                        height: Math.random() * 30 + 10
                        color: Material.accent
                        radius: 1.5
                        
                        SequentialAnimation on height {
                            running: isVoiceActive
                            loops: Animation.Infinite
                            
                            NumberAnimation { 
                                to: Math.random() * 30 + 10
                                duration: 200 + Math.random() * 200
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Panel de notifications intelligent
    Rectangle {
        id: notificationPanel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        
        width: 350
        height: Math.min(notificationColumn.implicitHeight + 20, 400)
        radius: 8
        color: Material.color(Material.BlueGrey, Material.Shade800)
        visible: notificationModel.count > 0
        
        Column {
            id: notificationColumn
            anchors.fill: parent
            anchors.margins: 10
            
            Text {
                text: "🔔 Notifications intelligentes"
                color: "white"
                font.pixelSize: 14
                font.bold: true
            }
            
            ListView {
                width: parent.width
                height: Math.min(contentHeight, 300)
                model: notificationModel
                
                delegate: Rectangle {
                    width: parent.width
                    height: 60
                    radius: 4
                    color: Material.color(Material.BlueGrey, Material.Shade700)
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12
                        
                        Text {
                            text: model.icon
                            font.pixelSize: 20
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: model.title
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            
                            Text {
                                text: model.message
                                color: Material.color(Material.Grey, Material.Shade300)
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Modèle de données pour les notifications
    ListModel {
        id: notificationModel
        
        ListElement {
            icon: "📧"
            title: "Nouvel email important"
            message: "Réunion équipe à 14h30 - Salle de conf"
        }
        
        ListElement {
            icon: "🏠"
            title: "Caméra entrée activée"
            message: "Mouvement détecté il y a 2 minutes"
        }
        
        ListElement {
            icon: "🎵"
            title: "Playlist du matin"
            message: "Henri suggère: Jazz pour bien commencer"
        }
        
        ListElement {
            icon: "🌡️"
            title: "Température optimisée"
            message: "Thermostat ajusté à 21°C (économie 15%)"
        }
    }
}