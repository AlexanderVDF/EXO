import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SimulationCausalityGraph — Graphe de causalité
//  généré par le moteur de simulation.
//
//  Affiche les nœuds (événements, capteurs, devices,
//  agents) et les liens causaux (trigger → détection →
//  activation → réponse).
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    // ── SimulationController (C++) ──
    property var simController: typeof simulationController !== 'undefined' ? simulationController : null

    // ── Données ──
    property var causalGraph: simController ? simController.causalGraph : ({nodes: [], links: []})
    property var nodes: causalGraph.nodes || []
    property var links: causalGraph.links || []

    // ── Navigation ──
    property real panX: 0
    property real panY: 0
    property real zoomLevel: 1.0
    property int  selectedNodeId: -1
    property int  hoveredNodeId: -1

    // ── Couleurs par type de nœud ──
    function _nodeColor(type) {
        switch (String(type)) {
            case "0": case "Event":     return "#F44747"   // Error red
            case "1": case "Sensor":    return "#DCDCAA"   // Warning yellow
            case "2": case "Device":    return "#569CD6"   // Info blue
            case "3": case "Agent":     return "#4EC9B0"   // Success green
            case "4": case "Room":      return "#C586C0"   // Purple
            case "5": case "External":  return "#CE9178"   // Orange
            default:                    return "#888888"
        }
    }

    function _nodeIcon(type) {
        switch (String(type)) {
            case "0": case "Event":     return "⚡"
            case "1": case "Sensor":    return "📡"
            case "2": case "Device":    return "🔧"
            case "3": case "Agent":     return "🧠"
            case "4": case "Room":      return "🏠"
            case "5": case "External":  return "🌐"
            default:                    return "?"
        }
    }

    function _linkColor(relation) {
        switch (String(relation)) {
            case "triggers":    return "#F44747"
            case "causes":      return "#CE9178"
            case "activates":   return "#569CD6"
            case "detects":     return "#DCDCAA"
            case "alerts":      return "#C586C0"
            default:            return "#555555"
        }
    }

    // ── Layout automatique (force-directed simplifié) ──
    property var nodePositions: ({})

    function layoutNodes() {
        var pos = {}
        var n = root.nodes.length
        if (n === 0) return pos

        // Disposition circulaire par colonnes de type
        var cols = {}
        for (var i = 0; i < n; i++) {
            var type = String(root.nodes[i].type || "0")
            if (!cols[type]) cols[type] = []
            cols[type].push(root.nodes[i].id)
        }

        var colKeys = Object.keys(cols).sort()
        var colSpacing = (root.width - 80) / Math.max(colKeys.length, 1)

        for (var c = 0; c < colKeys.length; c++) {
            var ids = cols[colKeys[c]]
            var rowSpacing = (root.height - 80) / Math.max(ids.length, 1)
            for (var r = 0; r < ids.length; r++) {
                pos[ids[r]] = {
                    x: 40 + c * colSpacing + colSpacing / 2,
                    y: 40 + r * rowSpacing + rowSpacing / 2
                }
            }
        }

        root.nodePositions = pos
    }

    onNodesChanged: {
        layoutNodes()
        causalCanvas.requestPaint()
    }
    onLinksChanged: causalCanvas.requestPaint()
    onPanXChanged:  causalCanvas.requestPaint()
    onPanYChanged:  causalCanvas.requestPaint()

    Component.onCompleted: layoutNodes()

    // ══════════════════════════
    //  Header
    // ══════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing4

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "CAUSALITÉ SIMULATION"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Bold
                color: Theme.textSecondary
                font.letterSpacing: 1.2
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.nodes.length + " nœuds · " + root.links.length + " liens"
                font.family: Theme.fontMono
                font.pixelSize: 9
                color: Theme.textMuted
            }
        }

        // ══════════════════════════
        //  Canvas du graphe
        // ══════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMedium
            color: Theme.bgElevated
            clip: true

            Canvas {
                id: causalCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.save()
                    ctx.translate(root.panX, root.panY)
                    ctx.scale(root.zoomLevel, root.zoomLevel)

                    var pos = root.nodePositions

                    // ── Liens ──
                    ctx.lineWidth = 1.5
                    for (var i = 0; i < root.links.length; i++) {
                        var link = root.links[i]
                        var from = pos[link.fromId]
                        var to = pos[link.toId]
                        if (!from || !to) continue

                        ctx.strokeStyle = _linkColor(link.relation)
                        ctx.globalAlpha = 0.6
                        ctx.beginPath()
                        ctx.moveTo(from.x, from.y)

                        // Courbe de Bézier
                        var midX = (from.x + to.x) / 2
                        var midY = (from.y + to.y) / 2 - 20
                        ctx.quadraticCurveTo(midX, midY, to.x, to.y)
                        ctx.stroke()

                        // Flèche
                        var angle = Math.atan2(to.y - midY, to.x - midX)
                        ctx.beginPath()
                        ctx.moveTo(to.x, to.y)
                        ctx.lineTo(to.x - 8 * Math.cos(angle - 0.3), to.y - 8 * Math.sin(angle - 0.3))
                        ctx.lineTo(to.x - 8 * Math.cos(angle + 0.3), to.y - 8 * Math.sin(angle + 0.3))
                        ctx.closePath()
                        ctx.fillStyle = _linkColor(link.relation)
                        ctx.fill()

                        // Label
                        if (link.relation) {
                            ctx.globalAlpha = 0.5
                            ctx.font = "7px monospace"
                            ctx.textAlign = "center"
                            ctx.fillStyle = Theme.textMuted
                            ctx.fillText(link.relation, midX, midY - 4)
                        }

                        ctx.globalAlpha = 1.0
                    }

                    // ── Nœuds ──
                    for (var j = 0; j < root.nodes.length; j++) {
                        var node = root.nodes[j]
                        var p = pos[node.id]
                        if (!p) continue

                        var nColor = _nodeColor(node.type)
                        var isSelected = (node.id === root.selectedNodeId)
                        var isHovered = (node.id === root.hoveredNodeId)
                        var nodeR = isSelected ? 18 : (isHovered ? 16 : 14)

                        // Halo
                        if (isSelected || isHovered) {
                            ctx.beginPath()
                            ctx.arc(p.x, p.y, nodeR + 4, 0, 2 * Math.PI)
                            ctx.fillStyle = Qt.rgba(Qt.color(nColor).r, Qt.color(nColor).g, Qt.color(nColor).b, 0.15)
                            ctx.fill()
                        }

                        // Fond
                        ctx.beginPath()
                        ctx.arc(p.x, p.y, nodeR, 0, 2 * Math.PI)
                        ctx.fillStyle = Qt.rgba(Qt.color(nColor).r, Qt.color(nColor).g, Qt.color(nColor).b, 0.3)
                        ctx.fill()
                        ctx.strokeStyle = nColor
                        ctx.lineWidth = isSelected ? 2.5 : 1.5
                        ctx.stroke()

                        // Icône
                        ctx.font = nodeR + "px sans-serif"
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        ctx.fillStyle = "white"
                        ctx.fillText(_nodeIcon(node.type), p.x, p.y)

                        // Label
                        if (node.label) {
                            ctx.font = "8px monospace"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            ctx.fillStyle = Theme.textSecondary
                            ctx.fillText(node.label, p.x, p.y + nodeR + 4)
                        }

                        // Tick
                        if (node.tick !== undefined) {
                            ctx.font = "7px monospace"
                            ctx.fillStyle = Theme.textMuted
                            ctx.fillText("T" + node.tick, p.x, p.y - nodeR - 4)
                        }
                    }

                    ctx.restore()
                }
            }

            // Drag & zoom
            MouseArea {
                anchors.fill: parent
                property real lastX: 0
                property real lastY: 0
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true

                onPressed: function(mouse) { lastX = mouse.x; lastY = mouse.y }
                onPositionChanged: function(mouse) {
                    if (mouse.buttons & Qt.LeftButton) {
                        root.panX += (mouse.x - lastX)
                        root.panY += (mouse.y - lastY)
                        lastX = mouse.x
                        lastY = mouse.y
                    }
                }

                onWheel: function(wheel) {
                    var delta = wheel.angleDelta.y > 0 ? 1.1 : 0.9
                    root.zoomLevel = Math.max(0.3, Math.min(3.0, root.zoomLevel * delta))
                    causalCanvas.requestPaint()
                }
            }
        }

        // ══════════════════════════
        //  Légende
        // ══════════════════════════
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { type: "Event",   label: "Événement", icon: "⚡" },
                    { type: "Sensor",  label: "Capteur",   icon: "📡" },
                    { type: "Device",  label: "Appareil",  icon: "🔧" },
                    { type: "Agent",   label: "Agent",     icon: "🧠" }
                ]

                delegate: Row {
                    spacing: 3
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: _nodeColor(modelData.type)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.icon + " " + modelData.label
                        font.family: Theme.fontMono
                        font.pixelSize: 8
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
