import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RaspberryAssistant
import "../theme"
import "../cognitive"

// ═══════════════════════════════════════════════════════
//  SimulationPage — Page principale de simulation spatiale
//
//  Compose les 6 panneaux de simulation :
//   • SimulationScenarioPanel  (contrôle)
//   • SimulationOverlay        (visualisation spatiale)
//   • SimulationCausalityGraph (graphe causal)
//   • SimulationRiskPanel      (risques)
//   • SimulationTimeline       (timeline événements)
//   • SimulationMinimap        (minimap propagation)
//
//  Connecté à SimulationController (QML_ELEMENT C++)
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: Theme.bgPrimary

    // ── SimulationController (QML_ELEMENT) ──
    SimulationController {
        id: simulationController
        Component.onCompleted: {
            // Synchroniser la taille du monde avec le floor plan si dispo
            if (typeof floorPlanModel !== 'undefined') {
                setFloorPlan(floorPlanModel)
                setWorldSize(800, 600)
            }
        }
    }

    // ── État ──
    property bool simRunning: simulationController.running
    property string activeView: "spatial"   // "spatial" | "causality" | "timeline"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ══════════════════════════════════════════════
        //  Header Bar
        // ══════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: Theme.bgSecondary
            z: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing12
                anchors.rightMargin: Theme.spacing12
                spacing: Theme.spacing8

                Text {
                    text: "🔬  SIMULATION SPATIALE"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontLabel
                    font.weight: Font.Bold
                    color: Theme.textPrimary
                    font.letterSpacing: 1.5
                }

                // Séparateur
                Rectangle { width: 1; height: 20; color: Theme.border }

                // Toggle vues
                Repeater {
                    model: [
                        { id: "spatial",    label: "🗺 Spatial",    tip: "Vue carte + propagation" },
                        { id: "causality",  label: "🔗 Causalité", tip: "Graphe cause→effet" },
                        { id: "timeline",   label: "📊 Timeline",  tip: "Événements temporels" }
                    ]

                    delegate: Rectangle {
                        width: viewLbl.implicitWidth + 14; height: 26; radius: Theme.radiusSmall
                        color: root.activeView === modelData.id
                            ? Theme.accentActive
                            : viewMouse.containsMouse ? Theme.bgHover : "transparent"

                        Text {
                            id: viewLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontMicro
                            color: root.activeView === modelData.id ? Theme.accent : Theme.textSecondary
                        }

                        MouseArea {
                            id: viewMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeView = modelData.id
                        }

                        ToolTip.text: modelData.tip
                        ToolTip.visible: viewMouse.containsMouse
                        ToolTip.delay: 600
                    }
                }

                Item { Layout.fillWidth: true }

                // État simulation
                Rectangle {
                    width: simStateRow.implicitWidth + 12; height: 22; radius: 11
                    color: root.simRunning
                        ? Qt.rgba(Qt.color(Theme.success).r, Qt.color(Theme.success).g, Qt.color(Theme.success).b, 0.12)
                        : Qt.rgba(Qt.color(Theme.textMuted).r, Qt.color(Theme.textMuted).g, Qt.color(Theme.textMuted).b, 0.08)

                    Row {
                        id: simStateRow
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: root.simRunning ? Theme.success : Theme.textMuted
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.simRunning
                                NumberAnimation { from: 1; to: 0.3; duration: 600 }
                                NumberAnimation { from: 0.3; to: 1; duration: 600 }
                            }
                        }
                        Text {
                            text: root.simRunning
                                ? "Tick " + simulationController.currentTick
                                : "Inactif"
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: root.simRunning ? Theme.success : Theme.textMuted
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════
        //  Corps principal
        // ══════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            // ── Panneau gauche : Contrôle scénario ──
            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: Theme.bgSecondary

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 1

                    // Sélection + contrôles scénario
                    SimulationScenarioPanel {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        simController: simulationController
                    }

                    // Minimap
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        color: Theme.bgElevated

                        SimulationMinimap {
                            anchors.fill: parent
                            anchors.margins: 4
                            simController: simulationController
                            worldWidth: 800
                            worldHeight: 600
                        }
                    }
                }
            }

            // ── Zone centrale : Vue principale (swap) ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.bgPrimary
                clip: true

                StackLayout {
                    id: viewStack
                    anchors.fill: parent
                    currentIndex: {
                        switch (root.activeView) {
                            case "spatial":   return 0
                            case "causality": return 1
                            case "timeline":  return 2
                            default:          return 0
                        }
                    }

                    // Vue 0 : Spatial (Overlay)
                    Item {
                        SimulationOverlay {
                            anchors.fill: parent
                            simController: simulationController
                            worldWidth: 800
                            worldHeight: 600
                        }
                    }

                    // Vue 1 : Causalité
                    SimulationCausalityGraph {
                        simController: simulationController
                    }

                    // Vue 2 : Timeline
                    SimulationTimeline {
                        simController: simulationController
                    }
                }
            }

            // ── Panneau droit : Risques ──
            Rectangle {
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                color: Theme.bgSecondary

                SimulationRiskPanel {
                    anchors.fill: parent
                    simController: simulationController
                }
            }
        }
    }
}
