import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ═══════════════════════════════════════════════════════
//  SplashScreen — Écran de démarrage EXO
//
//  Affiche la progression du lancement des services
//  puis disparaît quand allReady == true.
// ═══════════════════════════════════════════════════════

Rectangle {
    id: splash
    color: "#1A1A2E"

    property bool allReady: false
    property int readyCount: 0
    property int totalServices: 0
    property string currentAction: "Initialisation…"
    property var serviceStatuses: []

    signal dismissed()

    // Auto-dismiss quand tout est prêt
    onAllReadyChanged: {
        if (allReady)
            dismissTimer.start()
    }

    Timer {
        id: dismissTimer
        interval: 600
        onTriggered: splash.dismissed()
    }

    // ── Contenu principal ──

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 32
        width: Math.min(parent.width * 0.7, 500)

        // Logo / Titre
        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⬡"
                font.pixelSize: 64
                color: "#E94560"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "EXO Assistant"
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 28
                font.weight: Font.Bold
                color: "#E8E8E8"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "v4.2"
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 14
                color: "#888888"
            }
        }

        // Barre de progression
        Column {
            Layout.fillWidth: true
            spacing: 8

            ProgressBar {
                id: progressBar
                width: parent.width
                from: 0
                to: splash.totalServices > 0 ? splash.totalServices : 1
                value: splash.readyCount

                background: Rectangle {
                    implicitHeight: 6
                    radius: 3
                    color: "#2A2A3E"
                }

                contentItem: Item {
                    Rectangle {
                        width: progressBar.visualPosition * parent.width
                        height: parent.height
                        radius: 3

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#E94560" }
                            GradientStop { position: 1.0; color: "#0F3460" }
                        }

                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: splash.allReady
                      ? "✓ Tous les services sont prêts"
                      : splash.currentAction
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 13
                color: splash.allReady ? "#4EC9B0" : "#CCCCCC"
            }
        }

        // Liste des services
        Column {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: splash.serviceStatuses

                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 4
                    color: "#16213E"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        // Indicateur d'état
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: {
                                var s = modelData.status
                                if (s === "ready")     return "#4EC9B0"
                                if (s === "failed")    return "#F44747"
                                if (s === "launching" || s === "running" || s === "checking")
                                    return "#DCDCAA"
                                return "#555555"
                            }

                            SequentialAnimation on opacity {
                                running: modelData.status === "launching"
                                         || modelData.status === "running"
                                         || modelData.status === "checking"
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }

                        Text {
                            text: modelData.name
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#D4D4D4"
                            Layout.fillWidth: true
                        }

                        Text {
                            text: ":" + modelData.port
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 11
                            color: "#888888"
                        }

                        Text {
                            text: {
                                var s = modelData.status
                                if (s === "ready")     return "✓"
                                if (s === "failed")    return "✗"
                                if (s === "launching") return "…"
                                if (s === "checking")  return "?"
                                if (s === "running")   return "↻"
                                return ""
                            }
                            font.pixelSize: 14
                            color: {
                                var s = modelData.status
                                if (s === "ready")  return "#4EC9B0"
                                if (s === "failed") return "#F44747"
                                return "#DCDCAA"
                            }
                        }
                    }
                }
            }
        }

        // Spinner animé
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 24; height: 24
            visible: !splash.allReady

            Rectangle {
                id: spinner
                anchors.centerIn: parent
                width: 24; height: 24
                radius: 12
                color: "transparent"
                border.width: 3
                border.color: "#E94560"

                // Arc partiel via clip
                Rectangle {
                    width: 12; height: 12
                    color: "#1A1A2E"
                    anchors.right: parent.right
                    anchors.top: parent.top
                }

                RotationAnimation on rotation {
                    from: 0; to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }
        }
    }

    // ── Fond animé subtil ──
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        color: "#E94560"
        opacity: splash.allReady ? 0 : 0.6

        Behavior on opacity { NumberAnimation { duration: 400 } }

        SequentialAnimation on x {
            running: !splash.allReady
            loops: Animation.Infinite
            NumberAnimation { from: -splash.width; to: splash.width; duration: 2000 }
        }
    }
}
