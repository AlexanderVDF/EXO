import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SimulationScenarioPanel — Panneau de contrôle complet
//  de simulation spatiale (extension de ScenarioPanel)
//
//  Connecté à SimulationController (C++).
//  Scénarios prédéfinis + paramètres + timeline + heatmap
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    // ── SimulationController (C++ QML_ELEMENT) ──
    property var simController: typeof simulationController !== 'undefined' ? simulationController : null

    // ── État ──
    property string selectedPresetId: ""
    property bool simRunning: simController ? simController.running : false
    property int  simTick: simController ? simController.currentTick : 0
    property int  simMaxTicks: simController ? simController.maxTicks : 1
    property double simProgress: simController ? simController.progress : 0.0

    // ── Paramètres configurables ──
    property double paramSpeed: 1.0
    property double paramIntensity: 1.0
    property int    paramDuration: 3000
    property double paramStartX: 400
    property double paramStartY: 300

    // ── Signals ──
    signal simulationStarted(string scenarioId)
    signal simulationStopped()
    signal simulationCompleted(var summary)

    // ── Presets from controller ──
    property var presets: simController ? simController.availablePresets() : [
        {id: "fire",      label: "Incendie",        icon: "🔥", color: "#F44747", severity: "critical"},
        {id: "intrusion", label: "Intrusion",       icon: "🚨", color: "#CE9178", severity: "high"},
        {id: "blackout",  label: "Coupure courant", icon: "⚡", color: "#569CD6", severity: "high"},
        {id: "network",   label: "Panne réseau",    icon: "📡", color: "#DCDCAA", severity: "medium"},
        {id: "flood",     label: "Fuite d'eau",     icon: "💧", color: "#4EC9B0", severity: "high"}
    ]

    // ── Connections ──
    Connections {
        target: simController
        function onSimulationCompleted(summary) {
            root.simulationCompleted(summary)
        }
    }

    // ── Actions ──
    function launchSimulation() {
        if (!simController || !root.selectedPresetId) return
        simController.loadPresetScenario(root.selectedPresetId)
        simController.setTickIntervalMs(Math.round(100 / root.paramSpeed))
        simController.start()
        root.simulationStarted(root.selectedPresetId)
    }

    function launchCustomSimulation() {
        if (!simController) return
        simController.loadScenario(root.selectedPresetId || "custom", {
            name: "Custom",
            startX: root.paramStartX,
            startY: root.paramStartY,
            propagationSpeed: root.paramSpeed,
            intensity: root.paramIntensity,
            maxDurationTicks: root.paramDuration
        })
        simController.start()
    }

    function pauseSimulation() {
        if (simController) simController.pause()
    }

    function stopSimulation() {
        if (simController) simController.stop()
        root.simulationStopped()
    }

    function stepSimulation() {
        if (simController) simController.step()
    }

    function resetSimulation() {
        if (simController) simController.reset()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        // ══════════════
        //  Header
        // ══════════════
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "SIMULATION SPATIALE"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Bold
                color: Theme.textSecondary
                font.letterSpacing: 1.2
            }
            Item { Layout.fillWidth: true }

            // État
            Rectangle {
                width: stateLabel.implicitWidth + 12
                height: 18
                radius: 9
                color: root.simRunning
                    ? Qt.rgba(Qt.color(Theme.success).r, Qt.color(Theme.success).g, Qt.color(Theme.success).b, 0.15)
                    : Qt.rgba(Qt.color(Theme.textMuted).r, Qt.color(Theme.textMuted).g, Qt.color(Theme.textMuted).b, 0.15)

                Text {
                    id: stateLabel
                    anchors.centerIn: parent
                    text: root.simRunning ? "En cours" : "Inactif"
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    color: root.simRunning ? Theme.success : Theme.textMuted
                }
            }
        }

        // ══════════════
        //  Sélection scénario
        // ══════════════
        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing4

            Repeater {
                model: root.presets
                delegate: Rectangle {
                    width: presetRow.implicitWidth + 14
                    height: 30
                    radius: Theme.radiusMedium
                    color: root.selectedPresetId === modelData.id
                        ? Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.2)
                        : presetHover.containsMouse ? Theme.bgHover : Theme.bgElevated
                    border.width: root.selectedPresetId === modelData.id ? 1.5 : 0
                    border.color: modelData.color

                    RowLayout {
                        id: presetRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: modelData.icon
                            font.pixelSize: 14
                        }
                        Text {
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontMicro
                            font.weight: root.selectedPresetId === modelData.id ? Font.Bold : Font.Normal
                            color: root.selectedPresetId === modelData.id ? modelData.color : Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: presetHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedPresetId = modelData.id
                    }
                }
            }
        }

        // ══════════════
        //  Paramètres
        // ══════════════
        Rectangle {
            Layout.fillWidth: true
            height: paramCol.implicitHeight + Theme.spacing12
            radius: Theme.radiusMedium
            color: Theme.bgElevated
            visible: root.selectedPresetId !== ""

            ColumnLayout {
                id: paramCol
                anchors.fill: parent
                anchors.margins: Theme.spacing8
                spacing: Theme.spacing4

                Text {
                    text: "Paramètres"
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.textMuted
                    font.letterSpacing: 1
                }

                // Vitesse
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Vitesse"; font.family: Theme.fontMono; font.pixelSize: 9; color: Theme.textSecondary; Layout.preferredWidth: 70 }
                    Slider {
                        Layout.fillWidth: true
                        from: 0.1; to: 5.0; value: root.paramSpeed; stepSize: 0.1
                        onValueChanged: root.paramSpeed = value
                    }
                    Text { text: root.paramSpeed.toFixed(1) + "×"; font.family: Theme.fontMono; font.pixelSize: 9; color: Theme.textPrimary; Layout.preferredWidth: 30 }
                }

                // Intensité
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Intensité"; font.family: Theme.fontMono; font.pixelSize: 9; color: Theme.textSecondary; Layout.preferredWidth: 70 }
                    Slider {
                        Layout.fillWidth: true
                        from: 0.1; to: 2.0; value: root.paramIntensity; stepSize: 0.1
                        onValueChanged: root.paramIntensity = value
                    }
                    Text { text: root.paramIntensity.toFixed(1); font.family: Theme.fontMono; font.pixelSize: 9; color: Theme.textPrimary; Layout.preferredWidth: 30 }
                }

                // Durée
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Durée"; font.family: Theme.fontMono; font.pixelSize: 9; color: Theme.textSecondary; Layout.preferredWidth: 70 }
                    Slider {
                        Layout.fillWidth: true
                        from: 600; to: 6000; value: root.paramDuration; stepSize: 300
                        onValueChanged: root.paramDuration = Math.round(value)
                    }
                    Text { text: (root.paramDuration * 0.1 / 60).toFixed(1) + " min"; font.family: Theme.fontMono; font.pixelSize: 9; color: Theme.textPrimary; Layout.preferredWidth: 40 }
                }
            }
        }

        // ══════════════
        //  Contrôles
        // ══════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing4

            // Play
            Rectangle {
                width: 32; height: 28; radius: Theme.radiusSmall
                color: playMouse.containsMouse ? Theme.accentHover : Theme.accent
                opacity: root.selectedPresetId !== "" && !root.simRunning ? 1.0 : 0.4
                Text { anchors.centerIn: parent; text: "▶"; font.pixelSize: 12; color: "white" }
                MouseArea {
                    id: playMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchSimulation()
                    enabled: root.selectedPresetId !== "" && !root.simRunning
                }
            }

            // Pause
            Rectangle {
                width: 32; height: 28; radius: Theme.radiusSmall
                color: pauseMouse.containsMouse ? Theme.bgActive : Theme.bgElevated
                opacity: root.simRunning ? 1.0 : 0.4
                Text { anchors.centerIn: parent; text: "⏸"; font.pixelSize: 12; color: Theme.textPrimary }
                MouseArea {
                    id: pauseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.pauseSimulation()
                    enabled: root.simRunning
                }
            }

            // Step
            Rectangle {
                width: 32; height: 28; radius: Theme.radiusSmall
                color: stepMouse.containsMouse ? Theme.bgActive : Theme.bgElevated
                Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 12; color: Theme.textPrimary }
                MouseArea {
                    id: stepMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.stepSimulation()
                }
            }

            // Stop
            Rectangle {
                width: 32; height: 28; radius: Theme.radiusSmall
                color: sim_stopMouse.containsMouse ? Qt.darker(Theme.error, 1.2) : Theme.bgElevated
                border.width: root.simRunning ? 1 : 0; border.color: Theme.error
                Text { anchors.centerIn: parent; text: "⏹"; font.pixelSize: 12; color: Theme.error }
                MouseArea {
                    id: sim_stopMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.stopSimulation()
                }
            }

            Item { Layout.fillWidth: true }

            // Reset
            Rectangle {
                width: resetSimRow.implicitWidth + 12; height: 28; radius: Theme.radiusSmall
                color: resetSimMouse.containsMouse ? Theme.bgActive : Theme.bgElevated
                RowLayout {
                    id: resetSimRow; anchors.centerIn: parent; spacing: 4
                    Text { text: "↺"; font.pixelSize: 10; color: Theme.textSecondary }
                    Text { text: "Reset"; font.family: Theme.fontMono; font.pixelSize: 9; color: Theme.textSecondary }
                }
                MouseArea {
                    id: resetSimMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetSimulation()
                }
            }
        }

        // ══════════════
        //  Timeline simulation
        // ══════════════
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: Theme.radiusMedium
            color: Theme.bgElevated
            visible: root.simRunning || root.simTick > 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Tick " + root.simTick + " / " + root.simMaxTicks
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: Theme.textSecondary
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (root.simProgress * 100).toFixed(0) + "%"
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Theme.accent
                    }
                }

                // Progress bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Theme.bgPrimary

                    Rectangle {
                        width: parent.width * root.simProgress
                        height: parent.height
                        radius: 2
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation { duration: 100 }
                        }
                    }
                }
            }
        }

        // ══════════════
        //  Événements récents
        // ══════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMedium
            color: Theme.bgElevated
            visible: root.simTick > 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                Text {
                    text: "ÉVÉNEMENTS"
                    font.family: Theme.fontMono
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    color: Theme.textMuted
                    font.letterSpacing: 1
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: simController ? simController.events : []
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    verticalLayoutDirection: ListView.BottomToTop

                    delegate: RowLayout {
                        width: parent ? parent.width : 0
                        spacing: 4

                        Rectangle {
                            width: 4; height: 4; radius: 2
                            color: {
                                var sev = modelData.severity || 0
                                if (sev >= 3) return Theme.error
                                if (sev >= 2) return Theme.warning
                                if (sev >= 1) return Theme.info
                                return Theme.textMuted
                            }
                        }

                        Text {
                            text: "T" + (modelData.tick || 0)
                            font.family: Theme.fontMono
                            font.pixelSize: 8
                            color: Theme.textMuted
                            Layout.preferredWidth: 30
                        }

                        Text {
                            text: modelData.description || modelData.type || ""
                            font.family: Theme.fontMono
                            font.pixelSize: 8
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
