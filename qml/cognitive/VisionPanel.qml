import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionPanel — Tableau de bord principal vision IA
//  Vue d'ensemble : caméras, détections, activité, cycle
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null     // CameraVisionEngine (C++ QML_ELEMENT)

    property int    phase:          engine ? engine.phase : 0
    property bool   running:        engine ? engine.running : false
    property int    cycleCount:     engine ? engine.cycleCount : 0
    property int    activeCameras:  engine ? engine.activeCameras : 0
    property int    totalDetections: engine ? engine.totalDetections : 0
    property int    totalPersons:   engine ? engine.totalPersons : 0
    property double globalActivity: engine ? engine.globalActivity : 0.0
    property var    state:          engine ? engine.visionState : ({})

    readonly property var phaseNames: [
        "Repos", "Capture", "Prétraitement", "Inférence",
        "Post-traitement", "Routage", "Sync Cognition"
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ── En-tête ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "📹 Vision IA"
                font.pixelSize: 14
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 10; height: 10; radius: 5
                color: root.running ? Theme.success : Theme.textSecondary

                SequentialAnimation on opacity {
                    running: root.running
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600 }
                    NumberAnimation { to: 1.0; duration: 600 }
                }
            }

            Label {
                text: root.phaseNames[root.phase] || "?"
                font.pixelSize: 11
                color: Theme.textSecondary
            }

            Label {
                text: "Cycle " + root.cycleCount
                font.pixelSize: 10
                color: Theme.textSecondary
            }
        }

        // ── Niveau d'activité global ──
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 6
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                Label {
                    text: "Activité globale"
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }

                ProgressBar {
                    Layout.fillWidth: true
                    from: 0; to: 1
                    value: root.globalActivity
                }

                Label {
                    text: Math.round(root.globalActivity * 100) + "%"
                    font.pixelSize: 12
                    font.bold: true
                    color: root.globalActivity > 0.7 ? Theme.error
                         : root.globalActivity > 0.4 ? Theme.warning
                         : Theme.success
                }
            }
        }

        // ── Métriques clés ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { label: "Caméras", value: root.activeCameras, icon: "📹" },
                    { label: "Détections", value: root.totalDetections, icon: "🎯" },
                    { label: "Personnes", value: root.totalPersons, icon: "👤" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: 6
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Label {
                            text: modelData.icon + " " + modelData.value
                            font.pixelSize: 16
                            font.bold: true
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: modelData.label
                            font.pixelSize: 10
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // ── Contrôles ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: root.running ? "⏸ Arrêter" : "▶ Démarrer"
                onClicked: {
                    if (root.running)
                        engine.stopAutoCycle()
                    else
                        engine.startAutoCycle(2000)
                }
            }

            Button {
                text: "🔄 Cycle unique"
                enabled: !root.running
                onClicked: engine.runVisionCycle()
            }

            Item { Layout.fillWidth: true }
        }

        Item { Layout.fillHeight: true }
    }
}
