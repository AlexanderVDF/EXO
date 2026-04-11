import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  PipelineTimeline — Pipeline horizontal temps réel
//    AudioInput→ VAD → WakeWord → STT → LLM → TTS
//  + LatencyMetrics bar
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    signal stageClicked(string stageId)

    property var stageData: ({})

    readonly property var stages: [
        { id: "audio",    label: "Audio",    icon: "🎤", color: "#4EC9B0" },
        { id: "vad",      label: "VAD",      icon: "📡", color: "#569CD6" },
        { id: "wakeword", label: "WakeWord", icon: "👋", color: "#C586C0" },
        { id: "stt",      label: "STT",      icon: "💬", color: "#DCDCAA" },
        { id: "llm",      label: "LLM",      icon: "🧠", color: "#CE9178" },
        { id: "tts",      label: "TTS",      icon: "🔊", color: "#4FC1FF" }
    ]

    // ── Connexion pipelineEventBus ──
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onModuleStateChanged(moduleName, state) {
            var stageId = _mapModule(moduleName)
            if (!stageId) return
            var copy = Object.assign({}, root.stageData)
            if (!copy[stageId]) copy[stageId] = {}
            copy[stageId].state = state
            root.stageData = copy
        }

        function onEventEmitted(event) {
            var stageId = _mapModule(event.module || "")
            if (!stageId) return
            var copy = Object.assign({}, root.stageData)
            if (!copy[stageId]) copy[stageId] = {}
            copy[stageId].latencyMs = event.elapsed_ms || 0
            copy[stageId].engine = event.engine || ""
            copy[stageId].lastEvent = event.event_type || ""
            root.stageData = copy
        }
    }

    function _mapModule(mod) {
        var map = {
            "audio_capture": "audio", "preprocessor": "audio",
            "vad": "vad",
            "wakeword": "wakeword",
            "stt": "stt", "whisper": "stt",
            "claude": "llm", "nlu": "llm",
            "tts": "tts", "cosyvoice": "tts"
        }
        return map[mod] || null
    }

    // ── Latence totale ──
    property real totalLatency: {
        var total = 0
        for (var i = 0; i < stages.length; i++) {
            var d = stageData[stages[i].id]
            if (d && d.latencyMs) total += d.latencyMs
        }
        return total
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing4

        // ── Stages row ──
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Repeater {
                model: root.stages
                delegate: Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    property var data: root.stageData[modelData.id] || {}
                    property string state: data.state || "idle"
                    property bool isActive: state === "active" || state === "processing"
                    property real latency: data.latencyMs || 0

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Stage box
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 2
                            radius: Theme.radiusMedium
                            color: {
                                if (isActive) return Qt.rgba(
                                    Qt.color(modelData.color).r,
                                    Qt.color(modelData.color).g,
                                    Qt.color(modelData.color).b, 0.15)
                                return Theme.bgElevated
                            }
                            border.width: isActive ? 1 : 0
                            border.color: modelData.color

                            Behavior on color {
                                ColorAnimation { duration: Theme.animNormal }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 18
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontMicro
                                    font.weight: Font.DemiBold
                                    color: isActive ? modelData.color : Theme.textSecondary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: latency > 0 ? latency.toFixed(0) + "ms" : "—"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: {
                                        if (latency > 3000) return Theme.error
                                        if (latency > 1000) return Theme.warning
                                        if (latency > 0) return Theme.success
                                        return Theme.textMuted
                                    }
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            // Glow effect on active
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 2
                                border.color: modelData.color
                                opacity: 0
                                visible: isActive

                                SequentialAnimation on opacity {
                                    running: isActive
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.6; duration: 500 }
                                    NumberAnimation { to: 0; duration: 500 }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.stageClicked(modelData.id)
                            }
                        }

                        // Arrow connector
                        Text {
                            text: "→"
                            font.pixelSize: 12
                            color: Theme.textMuted
                            visible: index < root.stages.length - 1
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }

        // ── Latency bar ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            radius: Theme.radiusSmall
            color: Theme.bgElevated

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing8
                anchors.rightMargin: Theme.spacing8
                spacing: Theme.spacing4

                Text {
                    text: "Latence totale"
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.textMuted
                }

                // Bar segments
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Theme.bgPrimary

                    Row {
                        height: parent.height
                        Repeater {
                            model: root.stages
                            Rectangle {
                                height: parent.height
                                width: {
                                    if (root.totalLatency <= 0) return 0
                                    var d = root.stageData[modelData.id]
                                    var ms = d ? (d.latencyMs || 0) : 0
                                    return (ms / root.totalLatency) * parent.parent.parent.width
                                }
                                color: modelData.color
                                radius: 2
                            }
                        }
                    }
                }

                Text {
                    text: root.totalLatency > 0 ? root.totalLatency.toFixed(0) + "ms" : "—"
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: {
                        if (root.totalLatency > 5000) return Theme.error
                        if (root.totalLatency > 2000) return Theme.warning
                        if (root.totalLatency > 0) return Theme.success
                        return Theme.textMuted
                    }
                }
            }
        }
    }
}
