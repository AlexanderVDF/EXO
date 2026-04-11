import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ScenarioPanel — Simulation de scénarios
//  Incendie, intrusion, panne réseau, coupure courant
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var scenarios: [
        {
            id: "fire",
            label: "Incendie",
            icon: "🔥",
            desc: "Détection fumée/chaleur, évacuation",
            color: "#F44747",
            severity: "critical",
            active: false,
            status: "ready",
            steps: ["Détection capteur", "Alerte sonore", "Ouverture issues", "Appel secours"]
        },
        {
            id: "intrusion",
            label: "Intrusion",
            icon: "🚨",
            desc: "Détection présence non autorisée",
            color: "#CE9178",
            severity: "high",
            active: false,
            status: "ready",
            steps: ["Détection mouvement", "Identification", "Verrouillage", "Notification"]
        },
        {
            id: "network_failure",
            label: "Panne réseau",
            icon: "📡",
            desc: "Perte de connectivité internet/LAN",
            color: "#DCDCAA",
            severity: "medium",
            active: false,
            status: "ready",
            steps: ["Détection perte", "Mode hors ligne", "File d'attente", "Reconnexion"]
        },
        {
            id: "blackout",
            label: "Coupure courant",
            icon: "⚡",
            desc: "Perte d'alimentation électrique",
            color: "#569CD6",
            severity: "high",
            active: false,
            status: "ready",
            steps: ["Détection UPS", "Sauvegarde état", "Mode économie", "Arrêt gracieux"]
        }
    ]

    property string activeScenarioId: ""
    property int activeStep: -1

    // ── Simulation timer ──
    Timer {
        id: simTimer
        interval: 2000
        repeat: true
        running: root.activeScenarioId !== ""
        onTriggered: {
            var scn = _findScenario(root.activeScenarioId)
            if (!scn) return
            if (root.activeStep < scn.steps.length - 1) {
                root.activeStep++
            } else {
                // Fin de simulation
                _setScenarioStatus(root.activeScenarioId, "completed")
                root.activeScenarioId = ""
                root.activeStep = -1
            }
        }
    }

    function startSimulation(scenarioId) {
        if (root.activeScenarioId !== "") return  // déjà en cours
        _setScenarioStatus(scenarioId, "running")
        root.activeScenarioId = scenarioId
        root.activeStep = 0
    }

    function stopSimulation() {
        if (root.activeScenarioId === "") return
        _setScenarioStatus(root.activeScenarioId, "aborted")
        root.activeScenarioId = ""
        root.activeStep = -1
    }

    function resetScenario(scenarioId) {
        _setScenarioStatus(scenarioId, "ready")
        if (root.activeScenarioId === scenarioId) {
            root.activeScenarioId = ""
            root.activeStep = -1
        }
    }

    function _findScenario(id) {
        for (var i = 0; i < root.scenarios.length; i++) {
            if (root.scenarios[i].id === id) return root.scenarios[i]
        }
        return null
    }

    function _setScenarioStatus(id, status) {
        var copy = root.scenarios.slice()
        for (var i = 0; i < copy.length; i++) {
            if (copy[i].id === id) {
                copy[i] = Object.assign({}, copy[i], {
                    status: status,
                    active: status === "running"
                })
            }
        }
        root.scenarios = copy
    }

    function _statusColor(status) {
        switch (status) {
            case "running":   return Theme.warning
            case "completed": return Theme.success
            case "aborted":   return Theme.error
            default:          return Theme.textMuted
        }
    }

    function _statusLabel(status) {
        switch (status) {
            case "ready":     return "Prêt"
            case "running":   return "En cours"
            case "completed": return "Terminé"
            case "aborted":   return "Annulé"
            default:          return status
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "SCÉNARIOS"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Bold
                color: Theme.textSecondary
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            // Stop all btn
            Rectangle {
                width: stopRow.implicitWidth + 12
                height: 22
                radius: Theme.radiusSmall
                color: stopMouse.containsMouse ? Qt.darker(Theme.error, 1.3) : Theme.bgElevated
                border.width: root.activeScenarioId !== "" ? 1 : 0
                border.color: Theme.error
                visible: root.activeScenarioId !== ""

                RowLayout {
                    id: stopRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text { text: "⏹"; font.pixelSize: 10 }
                    Text {
                        text: "Arrêter"
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: Theme.error
                    }
                }

                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.stopSimulation()
                }
            }
        }

        // ── Cartes de scénarios ──
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.scenarios
            spacing: Theme.spacing4
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                width: parent ? parent.width : 0
                height: scenarioCol.implicitHeight + Theme.spacing12
                radius: Theme.radiusMedium
                color: Theme.bgElevated
                border.width: modelData.id === root.activeScenarioId ? 1.5 : 0
                border.color: modelData.color

                ColumnLayout {
                    id: scenarioCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing8
                    spacing: Theme.spacing4

                    // Header
                    RowLayout {
                        spacing: Theme.spacing8

                        Text {
                            text: modelData.icon
                            font.pixelSize: 20
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Text {
                                text: modelData.desc
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                                color: Theme.textMuted
                            }
                        }

                        // Status badge
                        Rectangle {
                            width: statusText.implicitWidth + 10
                            height: 18
                            radius: 9
                            color: Qt.rgba(
                                Qt.color(root._statusColor(modelData.status)).r,
                                Qt.color(root._statusColor(modelData.status)).g,
                                Qt.color(root._statusColor(modelData.status)).b, 0.15
                            )

                            Text {
                                id: statusText
                                anchors.centerIn: parent
                                text: root._statusLabel(modelData.status)
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                                color: root._statusColor(modelData.status)
                            }
                        }
                    }

                    // Steps progress
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: modelData.steps
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 20
                                radius: Theme.radiusSmall
                                color: {
                                    if (modelData.id !== root.activeScenarioId)
                                        return Theme.bgPrimary
                                    if (index < root.activeStep) return Theme.success
                                    if (index === root.activeStep) return modelData.color
                                    return Theme.bgPrimary
                                }
                                opacity: {
                                    if (modelData.id !== root.activeScenarioId) return 0.5
                                    if (index <= root.activeStep) return 1.0
                                    return 0.3
                                }

                                // Fix: need to access outer modelData
                                property string scenarioId: root.scenarios[Math.floor(index / 4)].id || ""

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animNormal }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.fontMono
                                    font.pixelSize: 8
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    width: parent.width - 4
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    // Actions
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing4

                        Item { Layout.fillWidth: true }

                        // Launch button
                        Rectangle {
                            width: launchRow.implicitWidth + 12
                            height: 24
                            radius: Theme.radiusSmall
                            color: launchMouse.containsMouse
                                ? Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.3)
                                : Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.1)
                            visible: modelData.status === "ready"

                            RowLayout {
                                id: launchRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: "▶"; font.pixelSize: 9; color: modelData.color }
                                Text {
                                    text: "Simuler"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: modelData.color
                                }
                            }

                            MouseArea {
                                id: launchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startSimulation(modelData.id)
                            }
                        }

                        // Reset button
                        Rectangle {
                            width: resetRow.implicitWidth + 12
                            height: 24
                            radius: Theme.radiusSmall
                            color: resetMouse.containsMouse ? Theme.bgHover : "transparent"
                            visible: modelData.status === "completed" || modelData.status === "aborted"

                            RowLayout {
                                id: resetRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: "↺"; font.pixelSize: 10; color: Theme.textSecondary }
                                Text {
                                    text: "Reset"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resetScenario(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
