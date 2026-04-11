import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SimulationTimeline — Timeline complète des événements
//  de simulation avec couches (propagation, capteurs,
//  devices, agents, risques).
//
//  Extension de CognitiveTimeline pour la couche
//  "simulation".
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    // ── SimulationController (C++) ──
    property var simController: typeof simulationController !== 'undefined' ? simulationController : null

    // ── Données ──
    property var events: simController ? simController.events : []
    property int currentTick: simController ? simController.currentTick : 0
    property int maxTicks: simController ? simController.maxTicks : 1

    // ── Navigation ──
    property real scrollOffsetX: 0
    property real pixelsPerTick: 2.0
    property int  hoveredTick: -1

    // ── Couches ──
    property var layers: [
        { id: "propagation", label: "Propagation", color: "#CE9178", visible: true },
        { id: "sensor",      label: "Capteurs",    color: "#DCDCAA", visible: true },
        { id: "device",      label: "Appareils",   color: "#569CD6", visible: true },
        { id: "agent",       label: "Agents",       color: "#4EC9B0", visible: true },
        { id: "risk",        label: "Risques",      color: "#F44747", visible: true }
    ]

    // Catégorisation événements → couche
    function _eventLayer(eventType) {
        switch (String(eventType)) {
            case "propagation_start": case "propagation_spread": return "propagation"
            case "sensor_triggered": return "sensor"
            case "device_activated": case "device_deactivated": return "device"
            case "agent_response": case "agent_alert": return "agent"
            case "risk_detected": case "risk_escalated": return "risk"
            default: return "propagation"
        }
    }

    function _eventIcon(eventType) {
        switch (String(eventType)) {
            case "propagation_start":  return "🔥"
            case "propagation_spread": return "💨"
            case "sensor_triggered":   return "📡"
            case "device_activated":   return "✅"
            case "device_deactivated": return "⛔"
            case "agent_response":     return "🧠"
            case "agent_alert":        return "🚨"
            case "risk_detected":      return "⚠️"
            case "risk_escalated":     return "🔴"
            default:                   return "•"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing4

        // ══════════════
        //  Header
        // ══════════════
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "TIMELINE SIMULATION"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Bold
                color: Theme.textSecondary
                font.letterSpacing: 1.2
            }
            Item { Layout.fillWidth: true }

            Text {
                text: root.events.length + " événements"
                font.family: Theme.fontMono
                font.pixelSize: 9
                color: Theme.textMuted
            }
        }

        // ══════════════
        //  Toggles couches
        // ══════════════
        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.layers
                delegate: Rectangle {
                    width: layerRow.implicitWidth + 10; height: 18; radius: 9
                    color: modelData.visible
                        ? Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.15)
                        : "transparent"
                    border.width: modelData.visible ? 1 : 0
                    border.color: modelData.color
                    opacity: modelData.visible ? 1.0 : 0.4

                    Row {
                        id: layerRow
                        anchors.centerIn: parent
                        spacing: 3
                        Rectangle { width: 6; height: 6; radius: 3; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.label; font.family: Theme.fontMono; font.pixelSize: 7; color: modelData.color }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var updated = root.layers.slice()
                            updated[index] = Object.assign({}, updated[index], {visible: !updated[index].visible})
                            root.layers = updated
                            timelineCanvas.requestPaint()
                        }
                    }
                }
            }
        }

        // ══════════════
        //  Canvas timeline
        // ══════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMedium
            color: Theme.bgElevated
            clip: true

            Canvas {
                id: timelineCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var layerHeight = (height - 30) / root.layers.length
                    var ppt = root.pixelsPerTick

                    // ── Axe temporel (haut) ──
                    ctx.fillStyle = Theme.bgPrimary
                    ctx.fillRect(0, 0, width, 20)

                    ctx.font = "8px monospace"
                    ctx.fillStyle = Theme.textMuted
                    ctx.textAlign = "center"

                    var tickStep = Math.max(1, Math.round(50 / ppt))
                    for (var t = 0; t <= root.maxTicks; t += tickStep) {
                        var tx = t * ppt - root.scrollOffsetX
                        if (tx < 0 || tx > width) continue
                        ctx.fillText("" + t, tx, 14)
                        ctx.strokeStyle = Qt.rgba(1,1,1,0.05)
                        ctx.beginPath()
                        ctx.moveTo(tx, 20)
                        ctx.lineTo(tx, height)
                        ctx.stroke()
                    }

                    // ── Playhead (tick courant) ──
                    var playX = root.currentTick * ppt - root.scrollOffsetX
                    if (playX >= 0 && playX <= width) {
                        ctx.strokeStyle = Theme.accent
                        ctx.lineWidth = 1.5
                        ctx.setLineDash([3, 2])
                        ctx.beginPath()
                        ctx.moveTo(playX, 0)
                        ctx.lineTo(playX, height)
                        ctx.stroke()
                        ctx.setLineDash([])
                        ctx.lineWidth = 1
                    }

                    // ── Labels couches (gauche) ──
                    for (var l = 0; l < root.layers.length; l++) {
                        var ly = 22 + l * layerHeight
                        var layer = root.layers[l]

                        // Séparateur
                        ctx.strokeStyle = Qt.rgba(1,1,1,0.04)
                        ctx.beginPath()
                        ctx.moveTo(0, ly)
                        ctx.lineTo(width, ly)
                        ctx.stroke()
                    }

                    // ── Événements ──
                    for (var e = 0; e < root.events.length; e++) {
                        var ev = root.events[e]
                        var evLayer = _eventLayer(ev.type)

                        // Trouver l'index de la couche
                        var layerIdx = -1
                        for (var li = 0; li < root.layers.length; li++) {
                            if (root.layers[li].id === evLayer) {
                                layerIdx = li
                                break
                            }
                        }
                        if (layerIdx < 0 || !root.layers[layerIdx].visible) continue

                        var ex = (ev.tick || 0) * ppt - root.scrollOffsetX
                        if (ex < -10 || ex > width + 10) continue

                        var ey = 22 + layerIdx * layerHeight + layerHeight / 2
                        var layerColor = root.layers[layerIdx].color

                        // Point
                        var severity = ev.severity || 1
                        var ptSize = 3 + severity
                        ctx.beginPath()
                        ctx.arc(ex, ey, ptSize, 0, 2 * Math.PI)
                        ctx.fillStyle = layerColor
                        ctx.globalAlpha = 0.8
                        ctx.fill()
                        ctx.globalAlpha = 1.0

                        // Halo sévérité élevée
                        if (severity >= 3) {
                            ctx.beginPath()
                            ctx.arc(ex, ey, ptSize + 3, 0, 2 * Math.PI)
                            ctx.strokeStyle = layerColor
                            ctx.globalAlpha = 0.3
                            ctx.stroke()
                            ctx.globalAlpha = 1.0
                        }
                    }

                    // ── Hovered tick ──
                    if (root.hoveredTick >= 0) {
                        var hx = root.hoveredTick * ppt - root.scrollOffsetX
                        ctx.strokeStyle = Qt.rgba(1,1,1,0.2)
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(hx, 0)
                        ctx.lineTo(hx, height)
                        ctx.stroke()

                        ctx.fillStyle = Theme.textPrimary
                        ctx.font = "9px monospace"
                        ctx.textAlign = "left"
                        ctx.fillText("Tick " + root.hoveredTick, hx + 4, 14)
                    }
                }
            }

            // Navigation
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                property real dragStartX: 0

                onPositionChanged: function(mouse) {
                    root.hoveredTick = Math.round((mouse.x + root.scrollOffsetX) / root.pixelsPerTick)
                    if (mouse.buttons & Qt.LeftButton) {
                        root.scrollOffsetX -= (mouse.x - dragStartX)
                        root.scrollOffsetX = Math.max(0, root.scrollOffsetX)
                        dragStartX = mouse.x
                    }
                    timelineCanvas.requestPaint()
                }

                onPressed: function(mouse) { dragStartX = mouse.x }

                onExited: {
                    root.hoveredTick = -1
                    timelineCanvas.requestPaint()
                }

                onWheel: function(wheel) {
                    var delta = wheel.angleDelta.y > 0 ? 1.2 : 0.8
                    root.pixelsPerTick = Math.max(0.5, Math.min(10, root.pixelsPerTick * delta))
                    timelineCanvas.requestPaint()
                }
            }
        }

        // ══════════════
        //  Détail tick hover
        // ══════════════
        Rectangle {
            Layout.fillWidth: true
            height: tickDetailCol.implicitHeight + 8
            radius: Theme.radiusSmall
            color: Theme.bgElevated
            visible: root.hoveredTick >= 0

            ColumnLayout {
                id: tickDetailCol
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                Repeater {
                    model: {
                        if (root.hoveredTick < 0) return []
                        var filtered = []
                        for (var i = 0; i < root.events.length && filtered.length < 5; i++) {
                            if (root.events[i].tick === root.hoveredTick) {
                                filtered.push(root.events[i])
                            }
                        }
                        return filtered
                    }

                    delegate: RowLayout {
                        spacing: 4
                        Text { text: _eventIcon(modelData.type); font.pixelSize: 10 }
                        Text { text: modelData.description || modelData.type || ""; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.textSecondary }
                    }
                }
            }
        }
    }
}
