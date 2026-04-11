import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SpatialOverlay — Surcouche cognitive sur le plan
//
//  Affiche : zones actives, capteurs, heatmap, événements,
//  trajectoires agent sur le plan 2D existant
// ═══════════════════════════════════════════════════════

Item {
    id: root

    signal zoneClicked(string zoneId)
    signal sensorClicked(string sensorId)
    signal eventMarkerClicked(string eventId, real worldX, real worldY)

    // ── Données injectées ──
    property var activeZones: []    // [{ id, x, y, w, h, label, intensity }]
    property var sensors: []        // [{ id, x, y, type, state, label }]
    property var heatmapData: []    // [{ x, y, value }]
    property var events: []         // [{ id, x, y, type, label, severity, timestamp }]
    property var trajectories: []   // [{ agentId, points: [{x,y}], color }]

    // ── Options d'affichage ──
    property bool showZones: true
    property bool showSensors: true
    property bool showHeatmap: false
    property bool showEvents: true
    property bool showTrajectories: true

    // ── Connexion temps réel ──
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onEventEmitted(event) {
            if (!event.spatial) return
            var copy = root.events.slice()
            copy.push({
                id: event.event_id || ("evt_" + Date.now()),
                x: event.spatial.x || 0,
                y: event.spatial.y || 0,
                type: event.event_type || "unknown",
                label: event.event_type || "",
                severity: event.severity || "info",
                timestamp: event.timestamp || new Date().toISOString()
            })
            // Garder max 50 événements
            if (copy.length > 50) copy = copy.slice(-50)
            root.events = copy
        }
    }

    // ════════════════════════════
    //  Couche 1 : Zones actives
    // ════════════════════════════
    Repeater {
        model: root.showZones ? root.activeZones : []
        delegate: Rectangle {
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: Qt.rgba(
                Qt.color(Theme.accent).r,
                Qt.color(Theme.accent).g,
                Qt.color(Theme.accent).b,
                0.06 + (modelData.intensity || 0) * 0.15
            )
            border.width: 1
            border.color: Qt.rgba(
                Qt.color(Theme.accent).r,
                Qt.color(Theme.accent).g,
                Qt.color(Theme.accent).b,
                0.3 + (modelData.intensity || 0) * 0.4
            )
            radius: Theme.radiusSmall

            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 3
                text: modelData.label || ""
                font.family: Theme.fontMono
                font.pixelSize: 9
                color: Theme.accent
                opacity: 0.8
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.zoneClicked(modelData.id)
            }
        }
    }

    // ════════════════════════════
    //  Couche 2 : Heatmap (Canvas)
    // ════════════════════════════
    Canvas {
        id: heatmapCanvas
        anchors.fill: parent
        visible: root.showHeatmap && root.heatmapData.length > 0
        opacity: 0.4

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            for (var i = 0; i < root.heatmapData.length; i++) {
                var pt = root.heatmapData[i]
                var val = Math.min(Math.max(pt.value || 0, 0), 1)
                var rad = 30 + val * 40
                var gradient = ctx.createRadialGradient(pt.x, pt.y, 0, pt.x, pt.y, rad)
                // Gradient : accent → transparent
                var r = Math.floor(val * 244 + (1-val) * 78)
                var g = Math.floor(val * 71 + (1-val) * 120)
                var b = Math.floor(val * 71 + (1-val) * 212)
                gradient.addColorStop(0, "rgba(" + r + "," + g + "," + b + ",0.6)")
                gradient.addColorStop(1, "rgba(" + r + "," + g + "," + b + ",0)")
                ctx.fillStyle = gradient
                ctx.beginPath()
                ctx.arc(pt.x, pt.y, rad, 0, Math.PI * 2)
                ctx.fill()
            }
        }

        Connections {
            target: root
            function onHeatmapDataChanged() { heatmapCanvas.requestPaint() }
        }
    }

    // ════════════════════════════
    //  Couche 3 : Trajectoires (Canvas)
    // ════════════════════════════
    Canvas {
        id: trajCanvas
        anchors.fill: parent
        visible: root.showTrajectories && root.trajectories.length > 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            for (var t = 0; t < root.trajectories.length; t++) {
                var traj = root.trajectories[t]
                var pts = traj.points || []
                if (pts.length < 2) continue
                ctx.strokeStyle = traj.color || Theme.accent
                ctx.lineWidth = 2
                ctx.setLineDash([4, 3])
                ctx.globalAlpha = 0.7
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var p = 1; p < pts.length; p++) {
                    ctx.lineTo(pts[p].x, pts[p].y)
                }
                ctx.stroke()
                ctx.setLineDash([])
                ctx.globalAlpha = 1.0
                // Arrowhead on last segment
                if (pts.length >= 2) {
                    var last = pts[pts.length - 1]
                    var prev = pts[pts.length - 2]
                    var angle = Math.atan2(last.y - prev.y, last.x - prev.x)
                    ctx.fillStyle = traj.color || Theme.accent
                    ctx.beginPath()
                    ctx.moveTo(last.x, last.y)
                    ctx.lineTo(last.x - 8 * Math.cos(angle - 0.4), last.y - 8 * Math.sin(angle - 0.4))
                    ctx.lineTo(last.x - 8 * Math.cos(angle + 0.4), last.y - 8 * Math.sin(angle + 0.4))
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }

        Connections {
            target: root
            function onTrajectoriesChanged() { trajCanvas.requestPaint() }
        }
    }

    // ════════════════════════════
    //  Couche 4 : Capteurs
    // ════════════════════════════
    Repeater {
        model: root.showSensors ? root.sensors : []
        delegate: Item {
            x: modelData.x - 12
            y: modelData.y - 12
            width: 24
            height: 24

            Rectangle {
                anchors.centerIn: parent
                width: 20; height: 20; radius: 10
                color: {
                    switch (modelData.state) {
                        case "active": return Theme.success
                        case "alert":  return Theme.error
                        case "warn":   return Theme.warning
                        default:       return Theme.textMuted
                    }
                }
                opacity: 0.9

                Text {
                    anchors.centerIn: parent
                    text: _sensorIcon(modelData.type)
                    font.pixelSize: 11
                }

                // Pulse on active
                Rectangle {
                    anchors.centerIn: parent
                    width: 28; height: 28; radius: 14
                    color: "transparent"
                    border.width: 2
                    border.color: parent.color
                    visible: modelData.state === "active" || modelData.state === "alert"

                    SequentialAnimation on scale {
                        running: visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.8; to: 1.4; duration: 1000 }
                        NumberAnimation { from: 1.4; to: 0.8; duration: 1000 }
                    }

                    SequentialAnimation on opacity {
                        running: visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.8; to: 0; duration: 1000 }
                        NumberAnimation { from: 0; to: 0.8; duration: 1000 }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sensorClicked(modelData.id)
            }

            ToolTip.visible: sensorHover.hovered
            ToolTip.text: (modelData.label || modelData.type) + " — " + (modelData.state || "idle")
            HoverHandler { id: sensorHover }
        }
    }

    // ════════════════════════════
    //  Couche 5 : Événements
    // ════════════════════════════
    Repeater {
        model: root.showEvents ? root.events : []
        delegate: Item {
            x: modelData.x - 8
            y: modelData.y - 8
            width: 16
            height: 16

            Rectangle {
                anchors.centerIn: parent
                width: 12; height: 12; radius: 6
                color: {
                    switch (modelData.severity) {
                        case "error": case "critical": return Theme.error
                        case "warning": return Theme.warning
                        case "info": return Theme.info
                        default: return Theme.textMuted
                    }
                }
                border.width: 1
                border.color: Qt.lighter(color, 1.3)

                // Fade-in
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation { duration: Theme.animSlow }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.eventMarkerClicked(modelData.id, modelData.x, modelData.y)
            }
        }
    }

    function _sensorIcon(type) {
        switch (type) {
            case "camera":     return "📷"
            case "microphone": return "🎤"
            case "motion":     return "🏃"
            case "door":       return "🚪"
            case "temperature":return "🌡"
            case "light":      return "💡"
            default:           return "📡"
        }
    }
}
