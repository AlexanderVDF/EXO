import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  MetricsPanel — Métriques temps réel
//  CPU/GPU, latences, histogrammes, counters, heatmap
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var metrics: ({
        cpu: 0, gpu: 0, ram: 0, vram: 0,
        latencies: {},
        counters: {}
    })

    // ── Connexion serviceSupervisor ──
    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            if (typeof serviceSupervisor === 'undefined') return
            var status = serviceSupervisor.systemMetrics
            if (!status) return
            root.metrics = {
                cpu: status.cpu_percent || 0,
                gpu: status.gpu_percent || 0,
                ram: status.ram_percent || 0,
                vram: status.vram_percent || 0,
                latencies: status.latencies || {},
                counters: status.counters || {}
            }
            _pushHistory("cpu", root.metrics.cpu)
            _pushHistory("gpu", root.metrics.gpu)
        }
    }

    // ── Historique pour sparklines ──
    property var history: ({ cpu: [], gpu: [], ram: [] })
    property int maxHistory: 60

    function _pushHistory(key, value) {
        var copy = Object.assign({}, root.history)
        if (!copy[key]) copy[key] = []
        var arr = copy[key].slice()
        arr.push(value)
        if (arr.length > root.maxHistory) arr = arr.slice(-root.maxHistory)
        copy[key] = arr
        root.history = copy
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        // ── Header ──
        Text {
            text: "MÉTRIQUES"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontLabel
            font.weight: Font.Bold
            color: Theme.textSecondary
            font.letterSpacing: 1.2
        }

        // ── Gauges principales ──
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Theme.spacing4
            columnSpacing: Theme.spacing4

            Repeater {
                model: [
                    { label: "CPU",  key: "cpu",  icon: "🖥", color: Theme.accent },
                    { label: "GPU",  key: "gpu",  icon: "🎮", color: "#4EC9B0" },
                    { label: "RAM",  key: "ram",  icon: "💾", color: "#C586C0" },
                    { label: "VRAM", key: "vram", icon: "📊", color: "#DCDCAA" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    radius: Theme.radiusMedium
                    color: Theme.bgElevated

                    property real value: root.metrics[modelData.key] || 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing4
                        spacing: 2

                        RowLayout {
                            spacing: Theme.spacing4

                            Text {
                                text: modelData.icon
                                font.pixelSize: 12
                            }
                            Text {
                                text: modelData.label
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontMicro
                                color: Theme.textSecondary
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: value.toFixed(0) + "%"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.Bold
                                color: value > 90 ? Theme.error :
                                       value > 70 ? Theme.warning : modelData.color
                            }
                        }

                        // Progress bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: Theme.bgPrimary

                            Rectangle {
                                width: parent.width * Math.min(value / 100, 1)
                                height: parent.height
                                radius: 2
                                color: value > 90 ? Theme.error :
                                       value > 70 ? Theme.warning : modelData.color

                                Behavior on width {
                                    NumberAnimation { duration: Theme.animNormal }
                                }
                            }
                        }

                        // Sparkline
                        Canvas {
                            Layout.fillWidth: true
                            height: 16
                            visible: (root.history[modelData.key] || []).length > 1

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var data = root.history[modelData.key] || []
                                if (data.length < 2) return

                                ctx.strokeStyle = modelData.color
                                ctx.lineWidth = 1
                                ctx.globalAlpha = 0.6
                                ctx.beginPath()
                                for (var i = 0; i < data.length; i++) {
                                    var x = (i / (root.maxHistory - 1)) * width
                                    var y = height - (data[i] / 100) * height
                                    if (i === 0) ctx.moveTo(x, y)
                                    else ctx.lineTo(x, y)
                                }
                                ctx.stroke()
                            }

                            Timer {
                                interval: 1000
                                repeat: true
                                running: parent.visible
                                onTriggered: parent.requestPaint()
                            }
                        }
                    }
                }
            }
        }

        // ── Séparateur ──
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // ── Latences par service ──
        Text {
            text: "Latences"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontMicro
            font.weight: Font.Bold
            color: Theme.textSecondary
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumHeight: 200
            model: Object.keys(root.metrics.latencies || {})
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                width: parent ? parent.width : 0
                height: 24
                radius: Theme.radiusSmall
                color: Theme.bgElevated

                property string key: modelData
                property real latency: root.metrics.latencies[key] || 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing8
                    anchors.rightMargin: Theme.spacing8

                    Text {
                        text: key
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }

                    // Latency bar
                    Rectangle {
                        Layout.preferredWidth: 60
                        height: 4
                        radius: 2
                        color: Theme.bgPrimary

                        Rectangle {
                            width: parent.width * Math.min(latency / 5000, 1)
                            height: parent.height
                            radius: 2
                            color: latency > 3000 ? Theme.error :
                                   latency > 1000 ? Theme.warning : Theme.success
                        }
                    }

                    Text {
                        text: latency.toFixed(0) + "ms"
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: latency > 3000 ? Theme.error :
                               latency > 1000 ? Theme.warning : Theme.success
                        Layout.preferredWidth: 45
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: "Pas de données de latence"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                color: Theme.textMuted
            }
        }

        // ── Compteurs ──
        Text {
            text: "Compteurs"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontMicro
            font.weight: Font.Bold
            color: Theme.textSecondary
            visible: Object.keys(root.metrics.counters || {}).length > 0
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing4
            visible: Object.keys(root.metrics.counters || {}).length > 0

            Repeater {
                model: Object.keys(root.metrics.counters || {})
                delegate: Rectangle {
                    width: counterRow.implicitWidth + 12
                    height: 22
                    radius: Theme.radiusSmall
                    color: Theme.bgElevated

                    RowLayout {
                        id: counterRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: modelData
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: Theme.textMuted
                        }
                        Text {
                            text: (root.metrics.counters[modelData] || 0).toString()
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.accent
                        }
                    }
                }
            }
        }
    }
}
