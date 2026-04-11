import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SimulationMinimap — Vue miniature du plan d'étage
//  avec superposition des propagations (fumée, chaleur,
//  eau), entités actives, trajectoires et zones impactées.
//
//  Extension de CognitiveMinimap pour la simulation.
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: Theme.bgElevated
    radius: Theme.radiusMedium

    // ── SimulationController (C++) ──
    property var simController: typeof simulationController !== 'undefined' ? simulationController : null

    // ── Monde ──
    property real worldWidth:  800
    property real worldHeight: 600

    // ── Données plan ──
    property var rooms: []       // { x, y, w, h, label }
    property var cameras: []     // { x, y }
    property var sensors: []     // { x, y, type }

    // ── Données simulation ──
    property var heatmapSmoke: simController ? simController.heatmapSmoke : []
    property var heatmapHeat:  simController ? simController.heatmapHeat  : []
    property var heatmapWater: simController ? simController.heatmapWater : []
    property var entities:     simController ? simController.entities     : []
    property var trajectories: simController ? simController.trajectories : []

    // ── Échelle ──
    property real scaleX: width / worldWidth
    property real scaleY: height / worldHeight

    // ── Visibilité couches ──
    property bool showPropagation: true
    property bool showEntities:    true

    // ── Tick ──
    property int currentTick: simController ? simController.currentTick : 0

    onCurrentTickChanged:  minimapCanvas.requestPaint()
    onEntitiesChanged:     minimapCanvas.requestPaint()
    onHeatmapSmokeChanged: minimapCanvas.requestPaint()
    onHeatmapHeatChanged:  minimapCanvas.requestPaint()
    onHeatmapWaterChanged: minimapCanvas.requestPaint()

    // ══════════════════════════
    //  Canvas minimap
    // ══════════════════════════
    Canvas {
        id: minimapCanvas
        anchors.fill: parent
        anchors.margins: 2
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var sx = root.scaleX
            var sy = root.scaleY

            // ── Pièces ──
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.1)
            ctx.lineWidth = 0.5
            for (var r = 0; r < root.rooms.length; r++) {
                var rm = root.rooms[r]
                ctx.strokeRect(rm.x * sx, rm.y * sy, rm.w * sx, rm.h * sy)
                if (rm.label) {
                    ctx.font = "6px monospace"
                    ctx.textAlign = "center"
                    ctx.fillStyle = Qt.rgba(1,1,1,0.15)
                    ctx.fillText(rm.label, (rm.x + rm.w / 2) * sx, (rm.y + rm.h / 2) * sy + 2)
                }
            }

            // ── Propagation fumée ──
            if (root.showPropagation) {
                var smoke = root.heatmapSmoke
                for (var s = 0; s < smoke.length; s++) {
                    var sc = smoke[s]
                    var slvl = sc.level || 0
                    if (slvl < 0.05) continue
                    ctx.fillStyle = Qt.rgba(0.6, 0.6, 0.6, slvl * 0.4)
                    ctx.fillRect(sc.x * sx - 2, sc.y * sy - 2, 4, 4)
                }

                // Chaleur
                var heat = root.heatmapHeat
                for (var h = 0; h < heat.length; h++) {
                    var hc = heat[h]
                    var hlvl = hc.level || 0
                    if (hlvl < 0.05) continue
                    ctx.fillStyle = Qt.rgba(1, 0.3, 0, hlvl * 0.4)
                    ctx.fillRect(hc.x * sx - 2, hc.y * sy - 2, 4, 4)
                }

                // Eau
                var water = root.heatmapWater
                for (var w = 0; w < water.length; w++) {
                    var wc = water[w]
                    var wlvl = wc.level || 0
                    if (wlvl < 0.05) continue
                    ctx.fillStyle = Qt.rgba(0.2, 0.5, 0.8, wlvl * 0.4)
                    ctx.fillRect(wc.x * sx - 2, wc.y * sy - 2, 4, 4)
                }
            }

            // ── Trajectoires ──
            if (root.showEntities) {
                var trajs = root.trajectories
                for (var ti = 0; ti < trajs.length; ti++) {
                    var traj = trajs[ti]
                    var pts = traj.points
                    if (!pts || pts.length < 2) continue
                    ctx.strokeStyle = _miniEntityColor(traj.type || "")
                    ctx.lineWidth = 0.8
                    ctx.globalAlpha = 0.4
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x * sx, pts[0].y * sy)
                    for (var pi = 1; pi < pts.length; pi++) {
                        ctx.lineTo(pts[pi].x * sx, pts[pi].y * sy)
                    }
                    ctx.stroke()
                    ctx.globalAlpha = 1.0
                }
            }

            // ── Capteurs ──
            for (var si = 0; si < root.sensors.length; si++) {
                var sensor = root.sensors[si]
                ctx.fillStyle = Qt.rgba(1, 0.85, 0.4, 0.5)
                ctx.beginPath()
                ctx.arc(sensor.x * sx, sensor.y * sy, 2, 0, 2 * Math.PI)
                ctx.fill()
            }

            // ── Caméras ──
            for (var ci = 0; ci < root.cameras.length; ci++) {
                var cam = root.cameras[ci]
                ctx.fillStyle = Qt.rgba(0.34, 0.61, 0.84, 0.6)
                ctx.fillRect(cam.x * sx - 1.5, cam.y * sy - 1.5, 3, 3)
            }

            // ── Entités actives ──
            if (root.showEntities) {
                var ents = root.entities
                for (var ei = 0; ei < ents.length; ei++) {
                    var ent = ents[ei]
                    var ec = _miniEntityColor(ent.type || "")
                    var er = 2 + Math.min((ent.radius || 1) * 0.3, 4)

                    ctx.beginPath()
                    ctx.arc(ent.x * sx, ent.y * sy, er, 0, 2 * Math.PI)
                    ctx.fillStyle = ec
                    ctx.globalAlpha = 0.85
                    ctx.fill()
                    ctx.globalAlpha = 1.0
                }
            }
        }
    }

    // ── Indicateur tick ──
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 2
        height: 12
        color: Qt.rgba(0, 0, 0, 0.5)
        radius: 2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            spacing: 2

            Text {
                text: "T" + root.currentTick
                font.family: Theme.fontMono
                font.pixelSize: 7
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            // Mini progress
            Rectangle {
                Layout.preferredWidth: 30
                height: 2; radius: 1
                color: Theme.bgPrimary

                Rectangle {
                    width: parent.width * (root.maxTicks > 0 ? root.currentTick / root.maxTicks : 0)
                    height: parent.height; radius: 1
                    color: Theme.accent
                }
            }

            Text {
                text: root.entities.length + "e"
                font.family: Theme.fontMono
                font.pixelSize: 6
                color: Theme.textMuted
            }
        }

        property int maxTicks: simController ? simController.maxTicks : 1
    }

    // ── Toggles ──
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 2
        spacing: 1

        Rectangle {
            width: 14; height: 14; radius: 3
            color: root.showPropagation ? Qt.rgba(1,1,1,0.08) : "transparent"
            Text { anchors.centerIn: parent; text: "🌫"; font.pixelSize: 8; opacity: root.showPropagation ? 1 : 0.3 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.showPropagation = !root.showPropagation; minimapCanvas.requestPaint() } }
        }

        Rectangle {
            width: 14; height: 14; radius: 3
            color: root.showEntities ? Qt.rgba(1,1,1,0.08) : "transparent"
            Text { anchors.centerIn: parent; text: "👤"; font.pixelSize: 8; opacity: root.showEntities ? 1 : 0.3 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.showEntities = !root.showEntities; minimapCanvas.requestPaint() } }
        }
    }

    function _miniEntityColor(type) {
        switch (String(type)) {
            case "0": case "Intruder":      return "#CE9178"
            case "1": case "Robot":          return "#4EC9B0"
            case "2": case "Smoke":          return "#999"
            case "3": case "Heat":           return "#F44747"
            case "4": case "Noise":          return "#DCDCAA"
            case "5": case "Light":          return "#569CD6"
            case "6": case "Water":          return "#2E90D1"
            case "7": case "CognitiveAgent": return "#B5CEA8"
            default:                         return "#666"
        }
    }
}
