import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

// ═══════════════════════════════════════════════════════
//  CognitiveSpatialView — Vue principale cognitive spatiale
//
//  Layout :
//   ┌──────────┬──────────────────────┬──────────┐
//   │ Cognitive │   FloorPlan +        │  Right   │
//   │ Timeline  │   SpatialOverlay     │  Tabs    │
//   │ (gauche)  │                      │          │
//   ├──────────┴──────────────────────┤          │
//   │     PipelineTimeline (bas)      │          │
//   └─────────────────────────────────┴──────────┘
//   + CognitiveMinimap (coin bas-gauche)
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: Theme.bgPrimary

    // ── FloorPlan model (injecté depuis C++) ──
    property var floorModel: null

    // ── Sélection cognitive ──
    property string selectedObjectId: ""
    property string selectedRoom: ""
    property string selectedAgent: ""
    property string selectedTrace: ""

    // ── Signaux d'interaction ──
    signal objectClicked(string objectId)
    signal roomClicked(string roomId)
    signal cameraClicked(string cameraId)
    signal agentClicked(string agentId)
    signal eventClicked(string eventId, real worldX, real worldY)

    // ── Panneaux latéraux ──
    property bool leftPanelVisible: true
    property bool rightPanelVisible: true
    property bool bottomPanelVisible: true
    property int rightTabIndex: 0

    readonly property var rightTabs: [
        { label: "Traces",     icon: "📋" },
        { label: "Métriques",  icon: "📊" },
        { label: "Agents",     icon: "🤖" },
        { label: "Scénarios",  icon: "🎬" },
        { label: "Anomalies",  icon: "⚠" },
        { label: "Risques",    icon: "🛡" },
        { label: "Causalités", icon: "🔗" }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ════════════════════════════
        //  Panneau gauche : CognitiveTimeline
        // ════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: root.leftPanelVisible ? 220 : 0
            visible: root.leftPanelVisible
            color: Theme.bgSecondary
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: Theme.bgElevated

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing8
                        anchors.rightMargin: Theme.spacing8

                        Text {
                            text: "COGNITION"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontLabel
                            font.weight: Font.Bold
                            color: Theme.textSecondary
                            font.letterSpacing: 1.2
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: cogTimeline.hasActivity ? Theme.success : Theme.textMuted

                            SequentialAnimation on opacity {
                                running: cogTimeline.hasActivity
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }
                    }
                }

                // Timeline
                CognitiveTimeline {
                    id: cogTimeline
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onLayerClicked: function(layerId) {
                        root.rightTabIndex = 0  // Switch to traces
                        tracePanel.filterModule = layerId
                    }
                }
            }
        }

        // ════════════════════════════
        //  Zone centrale + bas
        // ════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Zone centrale : FloorPlan + Overlay ──
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // FloorPlan existant (chargé depuis FloorPlanPage)
                Loader {
                    id: floorPlanLoader
                    anchors.fill: parent
                    source: "../pages/FloorPlanPage.qml"
                    active: root.floorModel !== null

                    onLoaded: {
                        if (item) item.floorModel = root.floorModel
                    }
                }

                // Placeholder si pas de modèle
                Rectangle {
                    anchors.fill: parent
                    visible: root.floorModel === null
                    color: Theme.bgPrimary

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacing12

                        Text {
                            text: "🏠"
                            font.pixelSize: 48
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Plan de logement non chargé"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            color: Theme.textSecondary
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Créez ou chargez un plan dans l'éditeur"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            color: Theme.textMuted
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Superposition cognitive
                SpatialOverlay {
                    id: spatialOverlay
                    anchors.fill: parent
                    visible: root.floorModel !== null

                    onZoneClicked: function(zoneId) {
                        root.roomClicked(zoneId)
                        root.selectedRoom = zoneId
                    }
                    onSensorClicked: function(sensorId) {
                        root.objectClicked(sensorId)
                        root.selectedObjectId = sensorId
                    }
                }

                // Minimap coin bas-gauche
                CognitiveMinimap {
                    id: minimap
                    width: 180
                    height: 140
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing12
                    visible: root.floorModel !== null
                }
            }

            // ── Splitter horizontal ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
                visible: root.bottomPanelVisible
            }

            // ── Panneau bas : PipelineTimeline ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.bottomPanelVisible ? 120 : 0
                visible: root.bottomPanelVisible
                color: Theme.bgSecondary
                clip: true

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
                }

                PipelineTimeline {
                    id: pipelineTimeline
                    anchors.fill: parent
                    anchors.margins: Theme.spacing8
                    onStageClicked: function(stageId) {
                        root.rightTabIndex = 0
                        tracePanel.filterModule = stageId
                    }
                }
            }
        }

        // ════════════════════════════
        //  Splitter vertical
        // ════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Theme.border
            visible: root.rightPanelVisible
        }

        // ════════════════════════════
        //  Panneau droit : Onglets
        // ════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: root.rightPanelVisible ? 360 : 0
            visible: root.rightPanelVisible
            color: Theme.bgSecondary
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Tab bar ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    color: Theme.bgElevated

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: root.rightTabs
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: root.rightTabIndex === index ? Theme.bgSecondary : "transparent"

                                Rectangle {
                                    width: parent.width; height: 2
                                    anchors.bottom: parent.bottom
                                    color: root.rightTabIndex === index ? Theme.accent : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: Theme.fontSmall
                                    opacity: root.rightTabIndex === index ? 1.0 : 0.5
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.rightTabIndex = index
                                }

                                ToolTip.visible: hovered
                                ToolTip.text: modelData.label
                                property bool hovered: false
                                HoverHandler { onHoveredChanged: parent.hovered = hovered }
                            }
                        }
                    }
                }

                // ── Tab content ──
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.rightTabIndex

                    TracePanel {
                        id: tracePanel
                        onTraceSelected: function(traceId, worldX, worldY) {
                            root.eventClicked(traceId, worldX, worldY)
                        }
                    }

                    MetricsPanel { id: metricsPanel }

                    AgentsPanel {
                        id: agentsPanel
                        onAgentSelected: function(agentId) {
                            root.agentClicked(agentId)
                            root.selectedAgent = agentId
                        }
                    }

                    ScenarioPanel { id: scenarioPanel }

                    AnomalyPanel {
                        id: anomalyPanel
                        onAnomalyClicked: function(anomalyId, worldX, worldY) {
                            root.eventClicked(anomalyId, worldX, worldY)
                        }
                    }

                    RiskPanel { id: riskPanel }

                    CausalityGraph { id: causalityGraph }
                }
            }
        }
    }

    // ════════════════════════════
    //  Toggle toolbar (haut)
    // ════════════════════════════
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spacing8
        z: 10
        spacing: Theme.spacing4

        Repeater {
            model: [
                { label: "◀", prop: "leftPanelVisible" },
                { label: "▼", prop: "bottomPanelVisible" },
                { label: "▶", prop: "rightPanelVisible" }
            ]
            delegate: Rectangle {
                width: 28; height: 24
                radius: Theme.radiusSmall
                color: toggleArea.containsMouse ? Theme.bgHover : Theme.bgElevated
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: Theme.fontMicro
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: toggleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root[modelData.prop] = !root[modelData.prop]
                }
            }
        }
    }
}
