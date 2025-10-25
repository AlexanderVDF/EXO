import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: mediasSection
    
    property var assistant: null
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        // Lecteur principal
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            color: Qt.rgba(156, 39, 176, 0.2)
            radius: 15
            border.color: "#9C27B0"
            border.width: 2
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                
                Text {
                    text: "🎵 Lecteur Musical"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Qt.rgba(0, 0, 0, 0.3)
                    radius: 10
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        
                        Rectangle {
                            width: 50
                            height: 50
                            radius: 5
                            color: "#9C27B0"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "♪"
                                color: "white"
                                font.pixelSize: 24
                            }
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            
                            Text {
                                text: "Aucun média en cours"
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                            }
                            
                            Text {
                                text: "Sélectionnez une source"
                                color: "#B0BEC5"
                                font.pixelSize: 14
                            }
                        }
                    }
                }
                
                // Contrôles
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 20
                    
                    Button {
                        text: "⏮"
                        Material.background: "#9C27B0"
                        font.pixelSize: 18
                    }
                    
                    Button {
                        text: "▶️"
                        Material.background: "#4CAF50"
                        font.pixelSize: 18
                    }
                    
                    Button {
                        text: "⏭"
                        Material.background: "#9C27B0"
                        font.pixelSize: 18
                    }
                }
            }
        }
        
        // Sources média
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 15
            columnSpacing: 15
            
            // Spotify
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                color: Qt.rgba(30, 215, 96, 0.2)
                radius: 15
                border.color: "#1ED760"
                border.width: 2
                
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    Text {
                        text: "🎶 Spotify"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "Non connecté"
                        color: "#B0BEC5"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: console.log("Connexion Spotify")
                }
            }
            
            // Radio locale
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                color: Qt.rgba(255, 152, 0, 0.2)
                radius: 15
                border.color: "#FF9800"
                border.width: 2
                
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    Text {
                        text: "📻 Radio"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "France Inter"
                        color: "#B0BEC5"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: console.log("Radio locale")
                }
            }
            
            // Podcasts
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                color: Qt.rgba(103, 58, 183, 0.2)
                radius: 15
                border.color: "#673AB7"
                border.width: 2
                
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    Text {
                        text: "🎙️ Podcasts"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "12 épisodes"
                        color: "#B0BEC5"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: console.log("Podcasts")
                }
            }
            
            // Fichiers locaux
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                color: Qt.rgba(0, 150, 136, 0.2)
                radius: 15
                border.color: "#009688"
                border.width: 2
                
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    Text {
                        text: "💾 Local"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "248 fichiers"
                        color: "#B0BEC5"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: console.log("Fichiers locaux")
                }
            }
        }
    }
}