import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SpatialCognitionPanel — Vue d'ensemble du moteur cognitif
//  Affiche la phase, le cycle, le risque global et les métriques
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    // ── Propriétés liées au SpatialCognitiveEngine ──
    property var engine: null     // SpatialCognitiveEngine (C++ QML_ELEMENT)

    property int    phase:       engine ? engine.phase : 0
    property bool   running:     engine ? engine.running : false
    property int    cycleCount:  engine ? engine.cycleCount : 0
    property double globalRisk:  engine ? engine.globalRisk : 0.0
    property var    state:       engine ? engine.cognitiveState : ({})

    readonly property var phaseNames: [
        "Repos", "Perception", "Symbolique", "Inférence",
        "Planification", "Simulation", "Décision", "Supervision", "Exécution"
    ]

    readonly property var phaseColors: [
        Theme.textSecondary, Theme.info, "#9CDCFE", Theme.warning,
        "#CE9178", "#C586C0", Theme.success, Theme.error, Theme.accent
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
                text: "🧠 Cognition Spatiale"
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
                text: root.running ? "Actif" : "Repos"
                font.pixelSize: 11
                color: root.running ? Theme.success : Theme.textSecondary
            }
        }

        // ── Phase actuelle ──
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 4
            color: Theme.cardBackground

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Label {
                    text: "Phase :"
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }

                Rectangle {
                    width: phaseLabel.implicitWidth + 12
                    height: 22
                    radius: 4
                    color: Qt.rgba(
                        root.phaseColors[root.phase] ? Qt.color(root.phaseColors[root.phase]).r : 0.5,
                        root.phaseColors[root.phase] ? Qt.color(root.phaseColors[root.phase]).g : 0.5,
                        root.phaseColors[root.phase] ? Qt.color(root.phaseColors[root.phase]).b : 0.5,
                        0.15
                    )

                    Label {
                        id: phaseLabel
                        anchors.centerIn: parent
                        text: root.phaseNames[root.phase] || "?"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.phaseColors[root.phase] || Theme.textPrimary
                    }
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Cycle #" + root.cycleCount
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }
            }
        }

        // ── Jauge de risque global ──
        Rectangle {
            Layout.fillWidth: true
            height: 50
            radius: 4
            color: Theme.cardBackground

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "Risque global"
                        font.pixelSize: 11
                        color: Theme.textSecondary
                    }

                    Item { Layout.fillWidth: true }

                    Label {
                        text: Math.round(root.globalRisk * 100) + "%"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.globalRisk >= 0.7 ? Theme.error :
                               root.globalRisk >= 0.4 ? Theme.warning : Theme.success
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.05)

                    Rectangle {
                        width: parent.width * root.globalRisk
                        height: parent.height
                        radius: 3
                        color: root.globalRisk >= 0.7 ? Theme.error :
                               root.globalRisk >= 0.4 ? Theme.warning : Theme.success

                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }
        }

        // ── Métriques du graphe ──
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: [
                    { label: "Nœuds",     value: root.state.nodeCount || 0,      icon: "🔵" },
                    { label: "Arêtes",     value: root.state.edgeCount || 0,      icon: "🔗" },
                    { label: "Inférences", value: root.state.inferenceCount || 0, icon: "💡" },
                    { label: "Plans",      value: root.state.planCount || 0,      icon: "📋" },
                    { label: "Risques",    value: root.state.riskCount || 0,      icon: "⚠" },
                    { label: "Mémoire",    value: root.state.memorySize || 0,     icon: "🧠" }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: Theme.cardBackground

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Label {
                            text: modelData.icon
                            font.pixelSize: 14
                        }

                        ColumnLayout {
                            spacing: 0

                            Label {
                                text: String(modelData.value)
                                font.pixelSize: 14
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Label {
                                text: modelData.label
                                font.pixelSize: 9
                                color: Theme.textSecondary
                            }
                        }
                    }
                }
            }
        }

        // ── Boutons d'action ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Button {
                Layout.fillWidth: true
                text: root.running ? "⏸ Arrêter" : "▶ Cycle"
                font.pixelSize: 11
                onClicked: {
                    if (root.engine) {
                        if (root.running)
                            root.engine.stopAutoCycle()
                        else
                            root.engine.runCognitiveCycle()
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: "🔄 Auto (5s)"
                font.pixelSize: 11
                onClicked: {
                    if (root.engine) root.engine.startAutoCycle(5000)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
