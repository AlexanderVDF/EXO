import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SimulationOverlay — Couche de visualisation spatiale
//  des propagations (fumée, chaleur, eau, bruit, lumière),
//  trajectoires d'entités et capteurs déclenchés.
//
//  Se superpose au FloorPlan via Canvas multi-couches.
// ═══════════════════════════════════════════════════════

Item {
    id: root

    // ── SimulationController (C++) ──
    property var simController: typeof simulationController !== 'undefined' ? simulationController : null

    // ── Données de propagation (heatmaps) ──
    property var heatmapSmoke: simController ? simController.heatmapSmoke : []
    property var heatmapHeat:  simController ? simController.heatmapHeat  : []
    property var heatmapWater: simController ? simController.heatmapWater : []

    // ── Entités ──
    property var entities:     simController ? simController.entities     : []
    property var trajectories: simController ? simController.trajectories : []
    property var risks:        simController ? simController.risks        : []

    // ── Visibilité des couches ──
    property bool showSmoke:       true
    property bool showHeat:        true
    property bool showWater:       true
    property bool showTrajectories: true
    property bool showEntities:    true

    // ── Échelle monde→pixel ──
    property real worldWidth:  800
    property real worldHeight: 600
    property real scaleX: width / worldWidth
    property real scaleY: height / worldHeight

    // ── Tick courant ──
    property int currentTick: simController ? simController.currentTick : 0

    // Rafraîchissement
    onCurrentTickChanged:       { smokeCanvas.requestPaint(); heatCanvas.requestPaint(); waterCanvas.requestPaint(); entityCanvas.requestPaint() }
    onHeatmapSmokeChanged:      smokeCanvas.requestPaint()
    onHeatmapHeatChanged:       heatCanvas.requestPaint()
    onHeatmapWaterChanged:      waterCanvas.requestPaint()
    onEntitiesChanged:          entityCanvas.requestPaint()
    onTrajectoriesChanged:      entityCanvas.requestPaint()

    // ══════════════════════════
    //  Canvas: Fumée (gris)
    // ══════════════════════════
    Canvas {
        id: smokeCanvas
        anchors.fill: parent
        visible: root.showSmoke
        opacity: 0.6
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var data = root.heatmapSmoke
            if (!data || data.length === 0) return
            for (var i = 0; i < data.length; i++) {
                var cell = data[i]
                var level = cell.level || 0
                if (level < 0.01) continue
                var alpha = Math.min(level * 0.7, 0.85)
                ctx.fillStyle = Qt.rgba(0.6, 0.6, 0.6, alpha)
                ctx.beginPath()
                ctx.arc(cell.x * root.scaleX, cell.y * root.scaleY,
                        (cell.radius || 10) * Math.max(root.scaleX, root.scaleY) * level,
                        0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }

    // ══════════════════════════
    //  Canvas: Chaleur (rouge→jaune)
    // ══════════════════════════
    Canvas {
        id: heatCanvas
        anchors.fill: parent
        visible: root.showHeat
        opacity: 0.5
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var data = root.heatmapHeat
            if (!data || data.length === 0) return
            for (var i = 0; i < data.length; i++) {
                var cell = data[i]
                var level = cell.level || 0
                if (level < 0.01) continue
                var r = 1.0
                var g = Math.max(0, 1.0 - level * 0.8)
                var b = 0
                var alpha = Math.min(level * 0.6, 0.75)
                ctx.fillStyle = Qt.rgba(r, g, b, alpha)
                ctx.beginPath()
                ctx.arc(cell.x * root.scaleX, cell.y * root.scaleY,
                        (cell.radius || 8) * Math.max(root.scaleX, root.scaleY) * level,
                        0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }

    // ══════════════════════════
    //  Canvas: Eau (bleu)
    // ══════════════════════════
    Canvas {
        id: waterCanvas
        anchors.fill: parent
        visible: root.showWater
        opacity: 0.55
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var data = root.heatmapWater
            if (!data || data.length === 0) return
            for (var i = 0; i < data.length; i++) {
                var cell = data[i]
                var level = cell.level || 0
                if (level < 0.01) continue
                var alpha = Math.min(level * 0.5, 0.7)
                ctx.fillStyle = Qt.rgba(0.18, 0.56, 0.82, alpha)
                ctx.beginPath()
                ctx.arc(cell.x * root.scaleX, cell.y * root.scaleY,
                        (cell.radius || 10) * Math.max(root.scaleX, root.scaleY) * level,
                        0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }

    // ══════════════════════════
    //  Canvas: Entités + Trajectoires
    // ══════════════════════════
    Canvas {
        id: entityCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // ── Trajectoires ──
            if (root.showTrajectories) {
                var trajs = root.trajectories
                if (trajs && trajs.length > 0) {
                    for (var t = 0; t < trajs.length; t++) {
                        var traj = trajs[t]
                        var pts = traj.points
                        if (!pts || pts.length < 2) continue

                        ctx.strokeStyle = _entityColor(traj.type || "default")
                        ctx.lineWidth = 1.5
                        ctx.setLineDash([4, 3])
                        ctx.globalAlpha = 0.6
                        ctx.beginPath()
                        ctx.moveTo(pts[0].x * root.scaleX, pts[0].y * root.scaleY)
                        for (var p = 1; p < pts.length; p++) {
                            ctx.lineTo(pts[p].x * root.scaleX, pts[p].y * root.scaleY)
                        }
                        ctx.stroke()
                        ctx.setLineDash([])
                        ctx.globalAlpha = 1.0
                    }
                }
            }

            // ── Entités ──
            if (root.showEntities) {
                var ents = root.entities
                if (ents && ents.length > 0) {
                    for (var e = 0; e < ents.length; e++) {
                        var ent = ents[e]
                        var ex = ent.x * root.scaleX
                        var ey = ent.y * root.scaleY
                        var eRadius = Math.max(4, (ent.radius || 6) * root.scaleX)
                        var eColor = _entityColor(ent.type || "default")

                        // Aura
                        ctx.beginPath()
                        ctx.arc(ex, ey, eRadius + 4, 0, 2 * Math.PI)
                        ctx.fillStyle = Qt.rgba(Qt.color(eColor).r, Qt.color(eColor).g, Qt.color(eColor).b, 0.15)
                        ctx.fill()

                        // Point
                        ctx.beginPath()
                        ctx.arc(ex, ey, eRadius, 0, 2 * Math.PI)
                        ctx.fillStyle = eColor
                        ctx.fill()

                        // Icône
                        var icon = _entityIcon(ent.type || "")
                        if (icon) {
                            ctx.font = Math.round(eRadius * 1.2) + "px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillStyle = "white"
                            ctx.fillText(icon, ex, ey)
                        }

                        // Label
                        if (ent.label) {
                            ctx.font = "8px monospace"
                            ctx.textAlign = "center"
                            ctx.fillStyle = Theme.textMuted
                            ctx.fillText(ent.label, ex, ey + eRadius + 10)
                        }
                    }
                }
            }
        }
    }

    // ── Capteurs déclenchés (pulsation) ──
    Repeater {
        model: {
            if (!root.simController) return []
            var events = root.simController.events
            if (!events) return []
            var triggered = []
            for (var i = events.length - 1; i >= 0 && triggered.length < 20; i--) {
                var ev = events[i]
                if (ev.type === "sensor_triggered" || ev.type === "device_activated") {
                    triggered.push(ev)
                }
            }
            return triggered
        }

        delegate: Rectangle {
            x: (modelData.x || 0) * root.scaleX - 8
            y: (modelData.y || 0) * root.scaleY - 8
            width: 16; height: 16; radius: 8
            color: "transparent"
            border.width: 2
            border.color: modelData.type === "sensor_triggered" ? Theme.warning : Theme.info

            SequentialAnimation on opacity {
                loops: 3
                NumberAnimation { from: 1.0; to: 0.2; duration: 300 }
                NumberAnimation { from: 0.2; to: 1.0; duration: 300 }
            }
        }
    }

    // ══════════════════════════
    //  Toolbar couches
    // ══════════════════════════
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        spacing: 2
        z: 10

        Repeater {
            model: [
                { key: "smoke", label: "💨", prop: "showSmoke"       },
                { key: "heat",  label: "🔥", prop: "showHeat"        },
                { key: "water", label: "💧", prop: "showWater"       },
                { key: "traj",  label: "➡",  prop: "showTrajectories"},
                { key: "ent",   label: "👤", prop: "showEntities"    }
            ]

            delegate: Rectangle {
                width: 22; height: 22; radius: 4
                color: root[modelData.prop] ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.3)
                border.width: root[modelData.prop] ? 1 : 0
                border.color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 12
                    opacity: root[modelData.prop] ? 1.0 : 0.3
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root[modelData.prop] = !root[modelData.prop]
                }
            }
        }
    }

    // ══════════════════════════
    //  Légende
    // ══════════════════════════
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 4
        width: legendCol.implicitWidth + 12
        height: legendCol.implicitHeight + 8
        radius: Theme.radiusSmall
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: root.entities.length > 0 || root.heatmapSmoke.length > 0

        Column {
            id: legendCol
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: [
                    { color: "#999",    label: "Fumée" },
                    { color: "#F44747", label: "Chaleur" },
                    { color: "#2E90D1", label: "Eau" },
                    { color: "#CE9178", label: "Intrus" },
                    { color: "#4EC9B0", label: "Robot" }
                ]

                delegate: Row {
                    spacing: 4
                    Rectangle { width: 6; height: 6; radius: 3; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: modelData.label; font.family: Theme.fontMono; font.pixelSize: 7; color: "#ccc" }
                }
            }
        }
    }

    // ── Helpers ──
    function _entityColor(type) {
        switch (String(type)) {
            case "0": case "Intruder":      return "#CE9178"
            case "1": case "Robot":          return "#4EC9B0"
            case "2": case "Smoke":          return "#999999"
            case "3": case "Heat":           return "#F44747"
            case "4": case "Noise":          return "#DCDCAA"
            case "5": case "Light":          return "#569CD6"
            case "6": case "Water":          return "#2E90D1"
            case "7": case "CognitiveAgent": return "#B5CEA8"
            default:                         return "#888888"
        }
    }

    function _entityIcon(type) {
        switch (String(type)) {
            case "0": case "Intruder":      return "👤"
            case "1": case "Robot":          return "🤖"
            case "2": case "Smoke":          return ""
            case "3": case "Heat":           return ""
            case "4": case "Noise":          return "🔊"
            case "5": case "Light":          return "💡"
            case "6": case "Water":          return ""
            case "7": case "CognitiveAgent": return "🧠"
            default:                         return ""
        }
    }
}
