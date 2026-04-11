import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SecurityPanel — Tableau de bord sécurité spatiale
//  Vue d'ensemble : niveau global, alertes, sous-systèmes
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null     // SpatialSecurityEngine (C++ QML_ELEMENT)

    property int    phase:         engine ? engine.phase : 0
    property bool   running:       engine ? engine.running : false
    property int    cycleCount:    engine ? engine.cycleCount : 0
    property double securityLevel: engine ? engine.globalSecurityLevel : 0.0
    property int    severity:      engine ? engine.overallSeverity : 0
    property var    alerts:        engine ? engine.activeAlerts : []
    property var    state:         engine ? engine.securityState : ({})

    readonly property var phaseNames: [
        "Repos", "Perception", "Analyse", "Détection",
        "Évaluation", "Planification", "Supervision"
    ]

    readonly property var severityNames: ["Info", "Basse", "Moyenne", "Haute", "Critique", "Urgence"]
    readonly property var severityColors: [
        Theme.textSecondary, Theme.info, Theme.warning,
        "#FF8C00", Theme.error, "#FF0040"
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
                text: "🛡️ Sécurité Spatiale"
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

        // ── Niveau de sécurité global ──
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 6
            color: Qt.rgba(root.severityColors[root.severity] ? Qt.darker(root.severityColors[root.severity], 3).r : 0.1,
                           root.severityColors[root.severity] ? Qt.darker(root.severityColors[root.severity], 3).g : 0.1,
                           root.severityColors[root.severity] ? Qt.darker(root.severityColors[root.severity], 3).b : 0.1, 0.4)
            border.color: root.severityColors[root.severity] || Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                Label {
                    text: root.severityNames[root.severity] || "—"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.severityColors[root.severity] || Theme.textPrimary
                }

                // Barre de niveau
                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: Theme.surface

                    Rectangle {
                        width: parent.width * root.securityLevel
                        height: parent.height
                        radius: 4
                        color: root.severityColors[root.severity] || Theme.accent

                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }

                Label {
                    text: Math.round(root.securityLevel * 100) + "%"
                    font.pixelSize: 12
                    font.bold: true
                    color: root.severityColors[root.severity] || Theme.textPrimary
                }
            }
        }

        // ── Alertes actives ──
        Label {
            text: "Alertes actives (" + root.alerts.length + ")"
            font.pixelSize: 12
            font.bold: true
            color: Theme.textPrimary
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.alerts

            delegate: Rectangle {
                width: ListView.view.width
                height: 40
                radius: 4
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                border.color: root.severityColors[modelData.severity] || Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: root.severityColors[modelData.severity] || Theme.textSecondary
                    }

                    Label {
                        Layout.fillWidth: true
                        text: modelData.description || ""
                        font.pixelSize: 10
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    Label {
                        text: modelData.roomId || ""
                        font.pixelSize: 9
                        color: Theme.textSecondary
                    }
                }
            }
        }

        // ── Contrôles ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: root.running ? "⏸ Stop" : "▶ Cycle"
                onClicked: {
                    if (root.engine) {
                        if (root.running)
                            root.engine.stopAutoCycle()
                        else
                            root.engine.runSecurityCycle()
                    }
                }
            }

            Button {
                text: "🔄 Auto"
                onClicked: {
                    if (root.engine) root.engine.startAutoCycle(3000)
                }
            }
        }
    }
}
