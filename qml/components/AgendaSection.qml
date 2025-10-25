import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: agendaSection
    
    property var assistant: null
    property date currentDate: new Date()
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        // Calendrier
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: Qt.rgba(33, 150, 243, 0.2)
            radius: 15
            border.color: "#2196F3"
            border.width: 2
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                Text {
                    text: "📅 " + Qt.formatDate(currentDate, "MMMM yyyy")
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                // Mini calendrier (simplifié)
                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7
                    spacing: 5
                    
                    Repeater {
                        model: ["L", "M", "M", "J", "V", "S", "D"]
                        Text {
                            text: modelData
                            color: "#B0BEC5"
                            font.pixelSize: 12
                            font.bold: true
                            width: 35
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    
                    Repeater {
                        model: 35
                        Rectangle {
                            width: 35
                            height: 30
                            color: index === 15 ? "#2196F3" : "transparent"
                            radius: 5
                            
                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                color: index === 15 ? "white" : "#B0BEC5"
                                font.pixelSize: 12
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: console.log("Date sélectionnée:", index + 1)
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#2196F3"
                }
                
                Text {
                    text: "Aujourd'hui: " + Qt.formatDate(currentDate, "dd/MM/yyyy")
                    color: "#4CAF50"
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        // Événements du jour
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.2)
            radius: 15
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                Text {
                    text: "📋 Événements du jour"
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                }
                
                ScrollView {
                    width: parent.width
                    height: parent.height - 100
                    
                    Column {
                        width: parent.width
                        spacing: 10
                        
                        // Événement 1
                        Rectangle {
                            width: parent.width
                            height: 80
                            color: Qt.rgba(76, 175, 80, 0.3)
                            radius: 10
                            border.color: "#4CAF50"
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                
                                Rectangle {
                                    width: 4
                                    Layout.fillHeight: true
                                    color: "#4CAF50"
                                }
                                
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 5
                                    
                                    Text {
                                        text: "09:00 - Réunion équipe"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    
                                    Text {
                                        text: "Salle de conférence A"
                                        color: "#B0BEC5"
                                        font.pixelSize: 14
                                    }
                                }
                                
                                Text {
                                    text: "⏰"
                                    font.pixelSize: 24
                                }
                            }
                        }
                        
                        // Événement 2
                        Rectangle {
                            width: parent.width
                            height: 80
                            color: Qt.rgba(255, 193, 7, 0.3)
                            radius: 10
                            border.color: "#FFC107"
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                
                                Rectangle {
                                    width: 4
                                    Layout.fillHeight: true
                                    color: "#FFC107"
                                }
                                
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 5
                                    
                                    Text {
                                        text: "14:30 - Rendez-vous médecin"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    
                                    Text {
                                        text: "Dr. Martin - Contrôle"
                                        color: "#B0BEC5"
                                        font.pixelSize: 14
                                    }
                                }
                                
                                Text {
                                    text: "🏥"
                                    font.pixelSize: 24
                                }
                            }
                        }
                        
                        // Événement 3
                        Rectangle {
                            width: parent.width
                            height: 80
                            color: Qt.rgba(156, 39, 176, 0.3)
                            radius: 10
                            border.color: "#9C27B0"
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                
                                Rectangle {
                                    width: 4
                                    Layout.fillHeight: true
                                    color: "#9C27B0"
                                }
                                
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 5
                                    
                                    Text {
                                        text: "19:00 - Dîner famille"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    
                                    Text {
                                        text: "Restaurant Le Petit Paris"
                                        color: "#B0BEC5"
                                        font.pixelSize: 14
                                    }
                                }
                                
                                Text {
                                    text: "🍽️"
                                    font.pixelSize: 24
                                }
                            }
                        }
                    }
                }
                
                // Bouton ajouter événement
                Button {
                    width: parent.width
                    text: "➕ Ajouter un événement"
                    Material.background: "#2196F3"
                    onClicked: {
                        // TODO: Ouvrir dialogue ajout événement
                        console.log("Ajouter événement")
                    }
                }
            }
        }
    }
}