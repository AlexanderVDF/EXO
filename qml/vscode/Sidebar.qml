import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: sidebar
    width: 260
    color: "#2D2D2D"

    // ── Propriétés exposées ──
    property string currentStatus: "Idle"
    property real micLevel: 0.0
    property string activePanel: "chat"  // "chat", "settings", "logs", "history"

    signal panelSelected(string panelName)

    // Bordure droite
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: "#3C3C3C"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Logo EXO ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "transparent"

            RowLayout {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: "◆"
                    font.pixelSize: 22
                    color: "#007ACC"
                }
                Text {
                    text: "EXO"
                    font.family: "Cascadia Code, Fira Code, JetBrains Mono, Consolas"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#E0E0E0"
                    font.letterSpacing: 4
                }
            }

            // Séparateur
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#3C3C3C"
            }
        }

        // ── Status Indicator ──
        StatusIndicator {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            currentStatus: sidebar.currentStatus
        }

        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#3C3C3C"
        }

        // ── Microphone Level ──
        MicrophoneLevel {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            level: sidebar.micLevel
        }

        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#3C3C3C"
        }

        // ── Navigation ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 12
                spacing: 2

                Repeater {
                    model: [
                        { name: "chat",     icon: "💬", label: "Chat" },
                        { name: "settings", icon: "⚙",  label: "Paramètres" },
                        { name: "history",  icon: "📋", label: "Historique" },
                        { name: "logs",     icon: "▸",  label: "Logs" },
                        { name: "pipeline", icon: "⬡",  label: "Pipeline" }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        radius: 4
                        color: sidebar.activePanel === modelData.name
                               ? "#094771" : navMouseArea.containsMouse
                                 ? "#2A2D2E" : "transparent"

                        // Barre accent gauche
                        Rectangle {
                            visible: sidebar.activePanel === modelData.name
                            anchors.left: parent.left
                            width: 3
                            height: parent.height
                            radius: 1
                            color: "#007ACC"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            spacing: 10

                            Text {
                                text: modelData.icon
                                font.pixelSize: 14
                            }
                            Text {
                                text: modelData.label
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 13
                                color: sidebar.activePanel === modelData.name
                                       ? "#FFFFFF" : "#A0A0A0"
                            }
                        }

                        MouseArea {
                            id: navMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sidebar.activePanel = modelData.name
                                sidebar.panelSelected(modelData.name)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ── Footer : version ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: "transparent"

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#3C3C3C"
            }

            Text {
                anchors.centerIn: parent
                text: "EXO v4.1"
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 11
                color: "#5A5A5A"
            }
        }
    }
}
