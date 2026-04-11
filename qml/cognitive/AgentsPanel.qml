import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  AgentsPanel — Agents macro (5) + micro (8)
//  État, dernière action, durée
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    signal agentSelected(string agentId)

    property var agents: []

    // ── Définition des agents ──
    readonly property var macroAgents: [
        { id: "orchestrator",  label: "Orchestrateur",  icon: "🎯", desc: "Pipeline global" },
        { id: "dialogue",      label: "Dialogue",       icon: "💬", desc: "Gestion conversationnelle" },
        { id: "spatial",       label: "Spatial",         icon: "🏠", desc: "Conscience spatiale" },
        { id: "risk_analysis", label: "Analyse Risque",  icon: "🛡", desc: "Évaluation menaces" },
        { id: "scenario",      label: "Scénario",        icon: "🎬", desc: "Simulation & prédiction" }
    ]

    readonly property var microAgents: [
        { id: "audio_agent",     label: "Audio",        icon: "🎤", desc: "Capture & preprocessing" },
        { id: "vad_agent",       label: "VAD",          icon: "📡", desc: "Détection voix" },
        { id: "wakeword_agent",  label: "WakeWord",     icon: "👋", desc: "Mot d'activation" },
        { id: "stt_agent",       label: "STT",          icon: "✍", desc: "Transcription" },
        { id: "nlu_agent",       label: "NLU",          icon: "🧠", desc: "Compréhension" },
        { id: "llm_agent",       label: "LLM",          icon: "⚡", desc: "Raisonnement" },
        { id: "tts_agent",       label: "TTS",          icon: "🔊", desc: "Synthèse vocale" },
        { id: "memory_agent",    label: "Mémoire",      icon: "💾", desc: "Mémoire sémantique" }
    ]

    // ── Connexion temps réel ──
    Timer {
        interval: 800
        repeat: true
        running: root.visible
        onTriggered: {
            if (typeof serviceSupervisor === 'undefined') return
            var statuses = serviceSupervisor.serviceStatuses
            if (!statuses) return
            var result = []
            var allDefs = root.macroAgents.concat(root.microAgents)
            for (var i = 0; i < allDefs.length; i++) {
                var def = allDefs[i]
                var svc = statuses[def.id] || {}
                result.push({
                    id: def.id,
                    state: svc.state || "idle",
                    lastAction: svc.last_action || "",
                    durationMs: svc.duration_ms || 0,
                    uptime: svc.uptime || 0
                })
            }
            root.agents = result
        }
    }

    function _agentData(agentId) {
        for (var i = 0; i < root.agents.length; i++) {
            if (root.agents[i].id === agentId) return root.agents[i]
        }
        return {}
    }

    function _stateColor(state) {
        switch (state) {
            case "active": case "processing": return Theme.success
            case "waiting": return Theme.warning
            case "error":   return Theme.error
            case "idle":    return Theme.textMuted
            default:        return Theme.textMuted
        }
    }

    function _stateLabel(state) {
        switch (state) {
            case "active": return "Actif"
            case "processing": return "En cours"
            case "waiting": return "Attente"
            case "error":   return "Erreur"
            case "idle":    return "Inactif"
            default:        return state
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        // ── Header ──
        Text {
            text: "AGENTS"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontLabel
            font.weight: Font.Bold
            color: Theme.textSecondary
            font.letterSpacing: 1.2
        }

        // ── Résumé rapide ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            Repeater {
                model: [
                    { label: "Actifs", state: "active", color: Theme.success },
                    { label: "Erreurs", state: "error", color: Theme.error }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    radius: Theme.radiusSmall
                    color: Theme.bgElevated

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: modelData.color
                        }
                        Text {
                            text: {
                                var count = 0
                                for (var i = 0; i < root.agents.length; i++) {
                                    if (modelData.state === "active" &&
                                        (root.agents[i].state === "active" || root.agents[i].state === "processing"))
                                        count++
                                    else if (root.agents[i].state === modelData.state)
                                        count++
                                }
                                return count + " " + modelData.label
                            }
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // ── Macro agents ──
        Text {
            text: "Macro-agents"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontMicro
            font.weight: Font.Bold
            color: Theme.textMuted
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: macroCol.implicitHeight
            Layout.maximumHeight: 200
            contentHeight: macroCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: macroCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.macroAgents
                    delegate: agentCard
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // ── Micro agents ──
        Text {
            text: "Micro-agents"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontMicro
            font.weight: Font.Bold
            color: Theme.textMuted
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: microCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: microCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.microAgents
                    delegate: agentCard
                }
            }
        }
    }

    // ── Agent card delegate ──
    Component {
        id: agentCard

        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: Theme.radiusSmall
            color: cardMouse.containsMouse ? Theme.bgHover : Theme.bgElevated

            property var data: root._agentData(modelData.id)
            property string agentState: data.state || "idle"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing8
                anchors.rightMargin: Theme.spacing8
                spacing: Theme.spacing8

                // Status indicator
                Rectangle {
                    width: 3; height: 26; radius: 1.5
                    color: root._stateColor(agentState)

                    SequentialAnimation on opacity {
                        running: agentState === "active" || agentState === "processing"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 700 }
                        NumberAnimation { to: 1.0; duration: 700 }
                    }
                }

                // Icon
                Text {
                    text: modelData.icon
                    font.pixelSize: 14
                    Layout.preferredWidth: 20
                }

                // Info
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
                        text: data.lastAction || modelData.desc
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Duration
                Text {
                    text: data.durationMs ? data.durationMs.toFixed(0) + "ms" : ""
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    color: Theme.textMuted
                    visible: text !== ""
                }

                // State badge
                Rectangle {
                    width: stateText.implicitWidth + 8
                    height: 16
                    radius: 8
                    color: Qt.rgba(
                        Qt.color(root._stateColor(agentState)).r,
                        Qt.color(root._stateColor(agentState)).g,
                        Qt.color(root._stateColor(agentState)).b, 0.15
                    )

                    Text {
                        id: stateText
                        anchors.centerIn: parent
                        text: root._stateLabel(agentState)
                        font.family: Theme.fontMono
                        font.pixelSize: 8
                        color: root._stateColor(agentState)
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.agentSelected(modelData.id)
            }
        }
    }
}
