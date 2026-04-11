import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  CausalityGraph — Graphe causal Canvas
//  Nœuds : événements, capteurs, actions, décisions
//  Liens directionnels entre nœuds
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    // ── Données ──
    property var nodes: []   // [{ id, type, label, x, y, state }]
    property var links: []   // [{ from, to, weight, label }]

    // ── Interaction ──
    property string selectedNodeId: ""
    property real panX: 0
    property real panY: 0
    property real zoomLevel: 1.0

    signal nodeClicked(string nodeId)

    // ── Connexion temps réel ──
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onEventEmitted(event) {
            if (!event.causality) return
            var caus = event.causality

            // Ajouter nœuds si nécessaires
            if (caus.source_id) _ensureNode(caus.source_id, caus.source_type || "event", caus.source_label || caus.source_id)
            if (caus.target_id) _ensureNode(caus.target_id, caus.target_type || "event", caus.target_label || caus.target_id)

            // Ajouter lien
            if (caus.source_id && caus.target_id) {
                var linksCopy = root.links.slice()
                linksCopy.push({
                    from: caus.source_id,
                    to: caus.target_id,
                    weight: caus.weight || 1.0,
                    label: caus.relation || ""
                })
                if (linksCopy.length > 200) linksCopy = linksCopy.slice(-200)
                root.links = linksCopy
            }
        }
    }

    function _ensureNode(id, type, label) {
        for (var i = 0; i < root.nodes.length; i++) {
            if (root.nodes[i].id === id) return
        }
        var copy = root.nodes.slice()
        // Auto-layout en cercle
        var angle = copy.length * (2 * Math.PI / Math.max(copy.length + 1, 8))
        var cx = root.width / 2
        var cy = root.height / 2
        var rad = Math.min(root.width, root.height) * 0.35
        copy.push({
            id: id,
            type: type,
            label: label,
            x: cx + rad * Math.cos(angle),
            y: cy + rad * Math.sin(angle),
            state: "active"
        })
        if (copy.length > 50) copy = copy.slice(-50)
        root.nodes = copy
    }

    function _nodeById(id) {
        for (var i = 0; i < root.nodes.length; i++) {
            if (root.nodes[i].id === id) return root.nodes[i]
        }
        return null
    }

    function _nodeColor(type) {
        switch (type) {
            case "event":    return Theme.accent
            case "sensor":   return "#4EC9B0"
            case "action":   return "#CE9178"
            case "decision": return "#C586C0"
            case "anomaly":  return Theme.error
            // Sécurité spatiale
            case "intrusion":   return "#FF0040"
            case "fire":        return "#FF6600"
            case "electrical":  return "#FFD700"
            case "network_risk":return "#00BFFF"
            case "domotic":     return "#FF69B4"
            case "security_action": return "#FF4060"
            default:         return Theme.textMuted
        }
    }

    function _nodeIcon(type) {
        switch (type) {
            case "event":    return "⚡"
            case "sensor":   return "📡"
            case "action":   return "🎯"
            case "decision": return "🧠"
            case "anomaly":  return "⚠"
            // Sécurité spatiale
            case "intrusion":   return "🚨"
            case "fire":        return "🔥"
            case "electrical":  return "⚡"
            case "network_risk":return "🌐"
            case "domotic":     return "🏠"
            case "security_action": return "🛡"
            default:         return "●"
        }
    }

    // ── Injection d'alertes sécurité ──
    function addSecurityAlert(alert) {
        var typeMap = { 0: "intrusion", 1: "fire", 2: "fire", 3: "electrical", 4: "network_risk", 5: "domotic" }
        var nodeType = typeMap[alert.riskType] || "anomaly"
        var alertNodeId = "sec_" + alert.id
        _ensureNode(alertNodeId, nodeType, alert.description || "Alerte")

        // Lien causal : capteur → alerte si roomId
        if (alert.roomId) {
            var roomNodeId = "room_" + alert.roomId
            _ensureNode(roomNodeId, "sensor", alert.roomId)
            var linksCopy = root.links.slice()
            linksCopy.push({
                from: roomNodeId,
                to: alertNodeId,
                weight: alert.confidence || 0.5,
                label: "détecté"
            })
            if (linksCopy.length > 200) linksCopy = linksCopy.slice(-200)
            root.links = linksCopy
        }
    }

    function addSecurityAction(alertId, actionDesc) {
        var actionNodeId = "act_" + alertId + "_" + Date.now()
        _ensureNode(actionNodeId, "security_action", actionDesc)
        var srcId = "sec_" + alertId
        _ensureNode(srcId, "anomaly", alertId)
        var linksCopy = root.links.slice()
        linksCopy.push({
            from: srcId,
            to: actionNodeId,
            weight: 1.0,
            label: "action"
        })
        if (linksCopy.length > 200) linksCopy = linksCopy.slice(-200)
        root.links = linksCopy
    }

    // ════════════════════════════
    //  Canvas principal
    // ════════════════════════════
    Canvas {
        id: graphCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save()
            ctx.translate(root.panX, root.panY)
            ctx.scale(root.zoomLevel, root.zoomLevel)

            // ── Liens ──
            for (var l = 0; l < root.links.length; l++) {
                var link = root.links[l]
                var fromNode = root._nodeById(link.from)
                var toNode = root._nodeById(link.to)
                if (!fromNode || !toNode) continue

                var weight = link.weight || 1.0
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15 + weight * 0.25)
                ctx.lineWidth = 1 + weight * 1.5
                ctx.beginPath()
                ctx.moveTo(fromNode.x, fromNode.y)

                // Bézier curve
                var mx = (fromNode.x + toNode.x) / 2
                var my = (fromNode.y + toNode.y) / 2
                var dx = toNode.x - fromNode.x
                var dy = toNode.y - fromNode.y
                var cx1 = mx - dy * 0.15
                var cy1 = my + dx * 0.15
                ctx.quadraticCurveTo(cx1, cy1, toNode.x, toNode.y)
                ctx.stroke()

                // Arrowhead
                var angle = Math.atan2(toNode.y - cy1, toNode.x - cx1)
                var arrSize = 6
                ctx.fillStyle = ctx.strokeStyle
                ctx.beginPath()
                ctx.moveTo(toNode.x, toNode.y)
                ctx.lineTo(toNode.x - arrSize * Math.cos(angle - 0.4),
                           toNode.y - arrSize * Math.sin(angle - 0.4))
                ctx.lineTo(toNode.x - arrSize * Math.cos(angle + 0.4),
                           toNode.y - arrSize * Math.sin(angle + 0.4))
                ctx.closePath()
                ctx.fill()

                // Link label
                if (link.label) {
                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.4)
                    ctx.font = "9px 'Cascadia Code'"
                    ctx.textAlign = "center"
                    ctx.fillText(link.label, mx, my - 5)
                }
            }

            // ── Nœuds ──
            for (var n = 0; n < root.nodes.length; n++) {
                var node = root.nodes[n]
                var col = root._nodeColor(node.type)
                var isSelected = node.id === root.selectedNodeId
                var nodeRadius = isSelected ? 22 : 18

                // Glow
                if (node.state === "active") {
                    ctx.fillStyle = Qt.rgba(Qt.color(col).r, Qt.color(col).g, Qt.color(col).b, 0.1)
                    ctx.beginPath()
                    ctx.arc(node.x, node.y, nodeRadius + 8, 0, Math.PI * 2)
                    ctx.fill()
                }

                // Circle
                ctx.fillStyle = Qt.rgba(Qt.color(col).r, Qt.color(col).g, Qt.color(col).b, 0.2)
                ctx.strokeStyle = col
                ctx.lineWidth = isSelected ? 2 : 1
                ctx.beginPath()
                ctx.arc(node.x, node.y, nodeRadius, 0, Math.PI * 2)
                ctx.fill()
                ctx.stroke()

                // Label
                ctx.fillStyle = Theme.textPrimary
                ctx.font = "10px 'Inter'"
                ctx.textAlign = "center"
                ctx.fillText(node.label, node.x, node.y + nodeRadius + 14)
            }

            ctx.restore()
        }

        // Repaint on data change
        Connections {
            target: root
            function onNodesChanged() { graphCanvas.requestPaint() }
            function onLinksChanged() { graphCanvas.requestPaint() }
            function onSelectedNodeIdChanged() { graphCanvas.requestPaint() }
            function onPanXChanged() { graphCanvas.requestPaint() }
            function onPanYChanged() { graphCanvas.requestPaint() }
            function onZoomLevelChanged() { graphCanvas.requestPaint() }
        }

        Component.onCompleted: requestPaint()
    }

    // ════════════════════════════
    //  Interactions souris
    // ════════════════════════════
    MouseArea {
        id: graphMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        property real lastX: 0
        property real lastY: 0
        property string dragNodeId: ""

        onPressed: function(mouse) {
            lastX = mouse.x
            lastY = mouse.y

            if (mouse.button === Qt.LeftButton) {
                // Check node hit
                var worldX = (mouse.x - root.panX) / root.zoomLevel
                var worldY = (mouse.y - root.panY) / root.zoomLevel

                for (var i = root.nodes.length - 1; i >= 0; i--) {
                    var node = root.nodes[i]
                    var dx = worldX - node.x
                    var dy = worldY - node.y
                    if (dx * dx + dy * dy < 22 * 22) {
                        root.selectedNodeId = node.id
                        dragNodeId = node.id
                        root.nodeClicked(node.id)
                        return
                    }
                }
                root.selectedNodeId = ""
            }
        }

        onPositionChanged: function(mouse) {
            if (dragNodeId !== "") {
                // Drag node
                var copy = root.nodes.slice()
                for (var i = 0; i < copy.length; i++) {
                    if (copy[i].id === dragNodeId) {
                        copy[i] = Object.assign({}, copy[i], {
                            x: copy[i].x + (mouse.x - lastX) / root.zoomLevel,
                            y: copy[i].y + (mouse.y - lastY) / root.zoomLevel
                        })
                        break
                    }
                }
                root.nodes = copy
            } else if (mouse.buttons & Qt.MiddleButton) {
                // Pan
                root.panX += (mouse.x - lastX)
                root.panY += (mouse.y - lastY)
            }
            lastX = mouse.x
            lastY = mouse.y
        }

        onReleased: {
            dragNodeId = ""
        }

        onWheel: function(wheel) {
            var factor = wheel.angleDelta.y > 0 ? 1.1 : 0.9
            var newZoom = Math.max(0.3, Math.min(3.0, root.zoomLevel * factor))
            root.zoomLevel = newZoom
        }
    }

    // ════════════════════════════
    //  Légende
    // ════════════════════════════
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing8
        width: legendCol.implicitWidth + Theme.spacing12
        height: legendCol.implicitHeight + Theme.spacing8
        radius: Theme.radiusMedium
        color: Qt.rgba(Qt.color(Theme.bgElevated).r, Qt.color(Theme.bgElevated).g, Qt.color(Theme.bgElevated).b, 0.85)

        ColumnLayout {
            id: legendCol
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: "Légende"
                font.family: Theme.fontMono
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.textMuted
            }

            Repeater {
                model: [
                    { type: "event",    label: "Événement" },
                    { type: "sensor",   label: "Capteur" },
                    { type: "action",   label: "Action" },
                    { type: "decision", label: "Décision" },
                    { type: "anomaly",  label: "Anomalie" },
                    { type: "intrusion",       label: "Intrusion" },
                    { type: "fire",            label: "Incendie" },
                    { type: "electrical",      label: "Électrique" },
                    { type: "network_risk",    label: "Réseau" },
                    { type: "security_action", label: "Action sécu." }
                ]

                RowLayout {
                    spacing: 4

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: root._nodeColor(modelData.type)
                    }

                    Text {
                        text: modelData.label
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }

    // ── Empty state ──
    Text {
        anchors.centerIn: parent
        visible: root.nodes.length === 0
        text: "Graphe causal vide\nLes relations apparaîtront ici"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
    }
}
