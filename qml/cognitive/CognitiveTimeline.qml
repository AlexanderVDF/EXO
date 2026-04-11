import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  CognitiveTimeline — Timeline verticale cognitive
//  8 couches cognitives haut-niveau :
//    Perception → Extraction → Symbolique → Inférence
//    → Planification → Simulation → Décision → Supervision
//
//  Distinct de components/CognitiveTimeline (pipeline audio)
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    // ── Signaux ──
    signal layerClicked(string layerId)

    // ── Activité globale ──
    property bool hasActivity: {
        for (var k in layerData) {
            if (layerData[k].state === "active" || layerData[k].state === "processing")
                return true
        }
        return false
    }

    // ── Données temps réel par couche ──
    property var layerData: ({})

    // ── Couches cognitives (haut-niveau, pas audio) ──
    readonly property var layers: [
        { id: "perception",     label: "Perception",     icon: "👁", color: "#4EC9B0", desc: "Fusion sensorielle multi-modale" },
        { id: "extraction",     label: "Extraction",     icon: "🔍", color: "#569CD6", desc: "Entités, intentions, contexte" },
        { id: "symbolic",       label: "Symbolique",     icon: "🧩", color: "#C586C0", desc: "Représentation sémantique" },
        { id: "inference",      label: "Inférence",      icon: "⚡", color: "#DCDCAA", desc: "Raisonnement logique & probabiliste" },
        { id: "planning",       label: "Planification",  icon: "📐", color: "#CE9178", desc: "Stratégie & ordonnancement" },
        { id: "simulation",     label: "Simulation",     icon: "🔮", color: "#D4D4D4", desc: "Prédiction & what-if" },
        { id: "decision",       label: "Décision",       icon: "🎯", color: "#4FC1FF", desc: "Sélection d'action optimale" },
        { id: "supervision",    label: "Supervision",    icon: "🛡", color: "#B5CEA8", desc: "Méta-cognition & contrôle" }
    ]

    // ── Connexion pipelineEventBus ──
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onModuleStateChanged(moduleName, state) {
            var mapping = _moduleToLayer(moduleName)
            if (!mapping) return
            var copy = Object.assign({}, root.layerData)
            if (!copy[mapping]) copy[mapping] = {}
            copy[mapping].state = state
            copy[mapping].lastUpdate = Date.now()
            root.layerData = copy
        }

        function onEventEmitted(event) {
            var mapping = _moduleToLayer(event.module || "")
            if (!mapping) return
            var copy = Object.assign({}, root.layerData)
            if (!copy[mapping]) copy[mapping] = {}
            copy[mapping].elapsed_ms = event.elapsed_ms || 0
            copy[mapping].lastEvent = event.event_type || ""
            copy[mapping].confidence = event.confidence || 0
            copy[mapping].lastUpdate = Date.now()
            root.layerData = copy
        }
    }

    // Mapping modules pipeline → couche cognitive
    function _moduleToLayer(mod) {
        var map = {
            "audio_capture": "perception", "vad": "perception", "wakeword": "perception",
            "stt": "extraction", "nlu": "extraction",
            "memory": "symbolic", "knowledge": "symbolic",
            "claude": "inference",
            "orchestrator": "planning",
            "scenario": "simulation",
            "decision": "decision", "tools": "decision",
            "tts": "supervision", "health": "supervision"
        }
        return map[mod] || null
    }

    // ── Rafraîchissement ──
    Timer {
        interval: 600
        repeat: true
        running: root.visible
        onTriggered: {
            if (typeof pipelineEventBus === 'undefined') return
            var snap = pipelineEventBus.getPipelineSnapshot()
            if (!snap || !snap.modules) return
            var copy = Object.assign({}, root.layerData)
            var moduleMap = {
                "audio_capture": "perception", "vad": "perception",
                "stt": "extraction", "nlu": "extraction",
                "memory": "symbolic", "claude": "inference",
                "orchestrator": "planning", "tts": "supervision"
            }
            for (var mod in moduleMap) {
                var lid = moduleMap[mod]
                if (snap.modules[mod]) {
                    if (!copy[lid]) copy[lid] = {}
                    var s = snap.modules[mod].state || "idle"
                    if (s === "active" || s === "processing") {
                        copy[lid].state = s
                    } else if (!copy[lid].state || copy[lid].state !== "active") {
                        copy[lid].state = s
                    }
                }
            }
            root.layerData = copy
        }
    }

    // ── UI ──
    ListView {
        id: layerList
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        model: root.layers
        spacing: Theme.spacing4
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: layerDelegate
            width: layerList.width
            height: 52
            radius: Theme.radiusMedium
            color: layerMouse.containsMouse ? Theme.bgHover : Theme.bgElevated
            border.width: isActive ? 1.5 : 0
            border.color: modelData.color

            property var data: root.layerData[modelData.id] || {}
            property string state: data.state || "idle"
            property bool isActive: state === "active" || state === "processing"

            Behavior on border.width {
                NumberAnimation { duration: Theme.animFast }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing8
                anchors.rightMargin: Theme.spacing8
                spacing: Theme.spacing8

                // Indicateur vertical
                Rectangle {
                    width: 3
                    Layout.fillHeight: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    radius: 1.5
                    color: layerDelegate.isActive ? modelData.color : Theme.textMuted
                    opacity: layerDelegate.isActive ? 1.0 : 0.3

                    SequentialAnimation on opacity {
                        running: layerDelegate.isActive
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                // Icône
                Text {
                    text: modelData.icon
                    font.pixelSize: 16
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }

                // Info
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        spacing: Theme.spacing4

                        Text {
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                            color: layerDelegate.isActive ? modelData.color : Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        // Latence
                        Text {
                            text: layerDelegate.data.elapsed_ms
                                  ? layerDelegate.data.elapsed_ms.toFixed(0) + "ms"
                                  : ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontMicro
                            color: {
                                var ms = layerDelegate.data.elapsed_ms || 0
                                if (ms > 3000) return Theme.error
                                if (ms > 1000) return Theme.warning
                                return Theme.textMuted
                            }
                            visible: text !== ""
                        }
                    }

                    Text {
                        text: modelData.desc
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMicro
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // État
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: {
                        switch (layerDelegate.state) {
                            case "active": case "processing": return modelData.color
                            case "error": return Theme.error
                            case "idle": return Theme.textMuted
                            default: return Theme.textMuted
                        }
                    }
                }
            }

            MouseArea {
                id: layerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.layerClicked(modelData.id)
            }

            ToolTip.visible: layerMouse.containsMouse
            ToolTip.delay: 400
            ToolTip.text: {
                var lines = [modelData.label + " — " + modelData.desc]
                if (layerDelegate.data.lastEvent)
                    lines.push("Dernier: " + layerDelegate.data.lastEvent)
                if (layerDelegate.data.confidence)
                    lines.push("Confiance: " + (layerDelegate.data.confidence * 100).toFixed(0) + "%")
                return lines.join("\n")
            }
        }
    }
}
