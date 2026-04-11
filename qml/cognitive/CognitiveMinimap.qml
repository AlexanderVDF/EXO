import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  CognitiveMinimap — Vue miniature du plan
//  Zones actives, caméras, capteurs, agents, anomalies
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    radius: Theme.radiusMedium
    color: Qt.rgba(Qt.color(Theme.bgElevated).r,
                   Qt.color(Theme.bgElevated).g,
                   Qt.color(Theme.bgElevated).b, 0.9)
    border.width: 1
    border.color: Theme.border

    // ── Données ──
    property var rooms: []      // [{ id, x, y, w, h, label, color }]
    property var cameras: []    // [{ id, x, y, angle, fov, active }]
    property var sensors: []    // [{ id, x, y, type, state }]
    property var agentPositions: []  // [{ id, x, y, label }]
    property var anomalyMarkers: [] // [{ id, x, y, severity }]

    // Pour mapper les coords monde → minimap
    property real worldWidth: 800
    property real worldHeight: 600
    property real viewportX: 0
    property real viewportY: 0
    property real viewportW: 400
    property real viewportH: 300

    signal viewportMoved(real worldX, real worldY)

    // ── Scale factors ──
    property real scaleX: (root.width - 8) / worldWidth
    property real scaleY: (root.height - 24) / worldHeight
    property real scale: Math.min(scaleX, scaleY)
    property real offsetX: (root.width - worldWidth * scale) / 2
    property real offsetY: 20 + (root.height - 24 - worldHeight * scale) / 2

    // ── Header ──
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 18
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: "MINIMAP"
            font.family: Theme.fontMono
            font.pixelSize: 8
            font.weight: Font.Bold
            color: Theme.textMuted
            font.letterSpacing: 1
        }
    }

    // ── Canvas ──
    Canvas {
        id: minimapCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var ox = root.offsetX
            var oy = root.offsetY
            var s = root.scale

            // ── Fond du plan ──
            ctx.fillStyle = Qt.rgba(Qt.color(Theme.bgPrimary).r, Qt.color(Theme.bgPrimary).g, Qt.color(Theme.bgPrimary).b, 0.8)
            ctx.fillRect(ox, oy, root.worldWidth * s, root.worldHeight * s)

            // ── Pièces ──
            for (var r = 0; r < root.rooms.length; r++) {
                var room = root.rooms[r]
                ctx.fillStyle = room.color || Qt.rgba(Qt.color(Theme.accent).r, Qt.color(Theme.accent).g, Qt.color(Theme.accent).b, 0.1)
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15)
                ctx.lineWidth = 0.5
                ctx.fillRect(ox + room.x * s, oy + room.y * s, room.w * s, room.h * s)
                ctx.strokeRect(ox + room.x * s, oy + room.y * s, room.w * s, room.h * s)
            }

            // ── Capteurs ──
            for (var i = 0; i < root.sensors.length; i++) {
                var sensor = root.sensors[i]
                var sx = ox + sensor.x * s
                var sy = oy + sensor.y * s
                ctx.fillStyle = sensor.state === "active" ? Theme.success :
                               sensor.state === "alert"  ? Theme.error : Theme.textMuted
                ctx.beginPath()
                ctx.arc(sx, sy, 2, 0, Math.PI * 2)
                ctx.fill()
            }

            // ── Caméras (cone de vue) ──
            for (var c = 0; c < root.cameras.length; c++) {
                var cam = root.cameras[c]
                var cx = ox + cam.x * s
                var cy = oy + cam.y * s
                var cAngle = (cam.angle || 0) * Math.PI / 180
                var cFov = (cam.fov || 60) * Math.PI / 180 / 2
                var cRad = 15

                if (cam.active) {
                    ctx.fillStyle = Qt.rgba(Qt.color(Theme.info).r, Qt.color(Theme.info).g, Qt.color(Theme.info).b, 0.15)
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.arc(cx, cy, cRad, cAngle - cFov, cAngle + cFov)
                    ctx.closePath()
                    ctx.fill()
                }

                ctx.fillStyle = cam.active ? Theme.info : Theme.textMuted
                ctx.beginPath()
                ctx.arc(cx, cy, 2.5, 0, Math.PI * 2)
                ctx.fill()
            }

            // ── Agents ──
            for (var a = 0; a < root.agentPositions.length; a++) {
                var agent = root.agentPositions[a]
                var ax = ox + agent.x * s
                var ay = oy + agent.y * s
                ctx.fillStyle = "#C586C0"
                ctx.beginPath()
                ctx.arc(ax, ay, 3, 0, Math.PI * 2)
                ctx.fill()
                ctx.strokeStyle = "#C586C0"
                ctx.lineWidth = 0.5
                ctx.stroke()
            }

            // ── Anomalies ──
            for (var an = 0; an < root.anomalyMarkers.length; an++) {
                var anom = root.anomalyMarkers[an]
                var anx = ox + anom.x * s
                var any_ = oy + anom.y * s
                ctx.fillStyle = anom.severity === "critical" ? Theme.error :
                               anom.severity === "high" ? "#CE9178" : Theme.warning
                // Diamond shape
                ctx.beginPath()
                ctx.moveTo(anx, any_ - 3)
                ctx.lineTo(anx + 3, any_)
                ctx.lineTo(anx, any_ + 3)
                ctx.lineTo(anx - 3, any_)
                ctx.closePath()
                ctx.fill()
            }

            // ── Viewport rectangle ──
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 1.5
            ctx.setLineDash([3, 2])
            ctx.strokeRect(
                ox + root.viewportX * s,
                oy + root.viewportY * s,
                root.viewportW * s,
                root.viewportH * s
            )
            ctx.setLineDash([])
        }

        // Repaint connections
        Connections {
            target: root
            function onRoomsChanged() { minimapCanvas.requestPaint() }
            function onCamerasChanged() { minimapCanvas.requestPaint() }
            function onSensorsChanged() { minimapCanvas.requestPaint() }
            function onAgentPositionsChanged() { minimapCanvas.requestPaint() }
            function onAnomalyMarkersChanged() { minimapCanvas.requestPaint() }
            function onViewportXChanged() { minimapCanvas.requestPaint() }
            function onViewportYChanged() { minimapCanvas.requestPaint() }
        }

        Component.onCompleted: requestPaint()
    }

    // ── Interaction : clic pour déplacer le viewport ──
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        onClicked: function(mouse) {
            var worldX = (mouse.x - root.offsetX) / root.scale - root.viewportW / 2
            var worldY = (mouse.y - root.offsetY) / root.scale - root.viewportH / 2
            worldX = Math.max(0, Math.min(root.worldWidth - root.viewportW, worldX))
            worldY = Math.max(0, Math.min(root.worldHeight - root.viewportH, worldY))
            root.viewportMoved(worldX, worldY)
        }
    }
}
