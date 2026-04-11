import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

// ═══════════════════════════════════════════════════════
//  Sidebar — Navigation latérale EXO Design System
// ═══════════════════════════════════════════════════════

Rectangle {
    id: sidebar
    width: Theme.sidebarWidth
    color: Theme.bgElevated

    property string currentStatus: "Idle"
    property real micLevel: 0.0
    property string activePanel: "chat"

    signal panelSelected(string panelName)

    // Bordure droite
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.border
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
                spacing: Theme.spacing10

                Text {
                    text: "◆"
                    font.pixelSize: 22
                    color: Theme.accent
                }
                Text {
                    text: "EXO"
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.textPrimary
                    font.letterSpacing: 4
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }
        }

        // ── Status Indicator ──
        ExoStatusIndicator {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            currentStatus: sidebar.currentStatus
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // ── Microphone Level ──
        ExoMicrophoneLevel {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            level: sidebar.micLevel
        }

        // ── v8: Orb Visualizer ──
        ExoOrbVisualizer {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            orbSize: 80
            state: sidebar.currentStatus
            audioLevel: sidebar.micLevel
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // ── Navigation ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: Theme.spacing12
                spacing: Theme.spacing2

                Repeater {
                    model: [
                        { name: "chat",     icon: "icons/chat.svg",     label: "Chat" },
                        { name: "settings", icon: "icons/settings.svg", label: "Paramètres" },
                        { name: "history",  icon: "icons/history.svg",  label: "Historique" },
                        { name: "logs",     icon: "icons/logs.svg",     label: "Logs" },
                        { name: "pipeline", icon: "icons/pipeline.svg", label: "Pipeline" },
                        { name: "maison",   icon: "icons/maison.svg",   label: "Maison" },
                        { name: "reseau",   icon: "icons/reseau.svg",   label: "Réseau" },
                        { name: "cognitive",     icon: "icons/pipeline.svg", label: "Cognitif" },
                        { name: "heatmap",       icon: "icons/pipeline.svg", label: "Heatmap" },
                        { name: "voicepipeline", icon: "icons/pipeline.svg", label: "Voice Flow" },
                        { name: "memory",        icon: "icons/history.svg",  label: "Mémoire" },
                        { name: "governance",    icon: "icons/settings.svg", label: "Gouvernance" },
                        { name: "observability", icon: "icons/logs.svg",     label: "Observabilité" },
                        { name: "floorplan",     icon: "icons/maison.svg",   label: "Plan" },
                        { name: "simulation",    icon: "icons/pipeline.svg", label: "Simulation" },
                        { name: "stability",     icon: "icons/pipeline.svg", label: "Stabilité" }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.navItemHeight
                        Layout.leftMargin: Theme.spacing8
                        Layout.rightMargin: Theme.spacing8
                        radius: Theme.radiusSmall
                        color: sidebar.activePanel === modelData.name
                               ? Theme.accentActive : navMouseArea.containsMouse
                                 ? Theme.bgHover : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        // Barre accent gauche
                        Rectangle {
                            visible: sidebar.activePanel === modelData.name
                            anchors.left: parent.left
                            width: 3
                            height: parent.height
                            radius: 1
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            spacing: Theme.spacing10

                            Image {
                                source: "../" + modelData.icon
                                sourceSize.width: Theme.iconSize
                                sourceSize.height: Theme.iconSize
                                width: Theme.iconSize
                                height: Theme.iconSize
                                opacity: sidebar.activePanel === modelData.name ? 1.0 : 0.6
                            }
                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                color: sidebar.activePanel === modelData.name
                                       ? "#FFFFFF" : Theme.textSecondary
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
                color: Theme.border
            }

            Text {
                anchors.centerIn: parent
                text: "EXO v8.0"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontMicro
                color: Theme.textMuted
            }
        }
    }
}
