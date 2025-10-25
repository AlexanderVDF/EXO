import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: maisonSection
    
    property var assistant: null
    
    GridLayout {
        anchors.fill: parent
        anchors.margins: 20
        columns: 2
        rowSpacing: 20
        columnSpacing: 20
        
        // Météo
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            Layout.columnSpan: 2
            color: Qt.rgba(0, 188, 212, 0.2)
            radius: 15
            border.color: "#00BCD4"
            border.width: 2
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                
                Column {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "🌤️ Météo Paris"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    
                    Text {
                        text: "22°C - Partiellement nuageux"
                        color: "#B0BEC5"
                        font.pixelSize: 16
                    }
                    
                    Text {
                        text: "Humidité: 65% | Vent: 15 km/h"
                        color: "#90A4AE"
                        font.pixelSize: 14
                    }
                }
                
                Text {
                    text: "☁️"
                    font.pixelSize: 48
                }
            }
        }
        
        // Éclairage
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: Qt.rgba(255, 193, 7, 0.2)
            radius: 15
            border.color: "#FFC107"
            border.width: 2
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "💡 Éclairage"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Switch {
                    checked: true
                    Material.accent: "#FFC107"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "75% | 6 lampes"
                    color: "#B0BEC5"
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        // Sécurité
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: Qt.rgba(244, 67, 54, 0.2)
            radius: 15
            border.color: "#F44336"
            border.width: 2
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "🔒 Sécurité"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "ARMÉ"
                    color: "#4CAF50"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "4 capteurs actifs"
                    color: "#B0BEC5"
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        // Température
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: Qt.rgba(33, 150, 243, 0.2)
            radius: 15
            border.color: "#2196F3"
            border.width: 2
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "🌡️ Chauffage"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "20°C → 22°C"
                    color: "#FFC107"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "Mode Éco"
                    color: "#4CAF50"
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        // Caméras
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: Qt.rgba(156, 39, 176, 0.2)
            radius: 15
            border.color: "#9C27B0"
            border.width: 2
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "📹 Caméras"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "3 EN LIGNE"
                    color: "#4CAF50"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "Dernière activité: 14:32"
                    color: "#B0BEC5"
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}