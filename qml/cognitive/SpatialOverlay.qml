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

    // ── Données réseau/domotique (via SpatialNetworkIntegration) ──
    property var networkDevices: []     // [{ id, name, x, y, type, protocol, vendor, rssi, latency, online }]
    property var networkLinks: []       // [{ sourceId, targetId, bandwidth, latency, protocol }]
    property var cameras: []            // [{ id, name, x, y, angle, fov, range, online }]
    property var domoticEntities: []    // [{ id, name, x, y, type, state, value, unit }]
    property var wifiZones: []          // [{ x, y, radius, ssid, signal }]
    property var deadZones: []          // [{ x, y, w, h }]

    // ── Options d'affichage ──
    property bool showZones: true
    property bool showSensors: true
    property bool showHeatmap: false
    property bool showEvents: true
    property bool showTrajectories: true
    property bool showNetworkDevices: true
    property bool showNetworkLinks: false
    property bool showCameras: true
    property bool showDomoticEntities: true
    property bool showWifiHeatmap: false
    property bool showDeadZones: false

    // ── Signaux réseau ──
    signal networkDeviceClicked(string deviceId)
    signal cameraClicked(string cameraId)
    signal domoticEntityClicked(string entityId)

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

    // ════════════════════════════
    //  Couche 6 : Appareils réseau
    // ════════════════════════════
    Repeater {
        model: root.showNetworkDevices ? root.networkDevices : []
        delegate: Item {
            x: modelData.x - 14
            y: modelData.y - 14
            width: 28
            height: 28

            Rectangle {
                anchors.centerIn: parent
                width: 24; height: 24; radius: 4
                color: modelData.online ? Theme.bgElevated : Theme.bgInput
                border.width: 1
                border.color: modelData.online ? _protocolColor(modelData.protocol) : Theme.textMuted
                opacity: modelData.online ? 1.0 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: _networkIcon(modelData.type || modelData.protocol)
                    font.pixelSize: 13
                }
            }

            // Vendor badge
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: 14; height: 10; radius: 2
                visible: (modelData.vendor || "").length > 0
                color: Theme.bgElevated
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: (modelData.vendor || "").substring(0, 2)
                    font.pixelSize: 6
                    font.family: Theme.fontMono
                    color: Theme.textSecondary
                }
            }

            // RSSI indicator
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: 6; height: 6; radius: 3
                visible: modelData.rssi !== undefined
                color: {
                    var rssi = modelData.rssi || -100
                    if (rssi > -50) return Theme.success
                    if (rssi > -70) return Theme.warning
                    return Theme.error
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.networkDeviceClicked(modelData.id)
            }

            ToolTip.visible: netDevHover.hovered
            ToolTip.text: (modelData.name || modelData.ip || "device") + "\n"
                        + (modelData.protocol || "") + " • "
                        + (modelData.online ? "en ligne" : "hors ligne")
                        + (modelData.latency ? (" • " + modelData.latency + "ms") : "")
            HoverHandler { id: netDevHover }
        }
    }

    // ════════════════════════════
    //  Couche 7 : Liens réseau (Canvas)
    // ════════════════════════════
    Canvas {
        id: networkLinkCanvas
        anchors.fill: parent
        visible: root.showNetworkLinks && root.networkLinks.length > 0
        opacity: 0.5

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Build device position map
            var posMap = {}
            for (var d = 0; d < root.networkDevices.length; d++) {
                var dev = root.networkDevices[d]
                posMap[dev.id] = { x: dev.x || 0, y: dev.y || 0 }
            }

            for (var i = 0; i < root.networkLinks.length; i++) {
                var link = root.networkLinks[i]
                var src = posMap[link.sourceId]
                var dst = posMap[link.targetId]
                if (!src || !dst) continue

                ctx.strokeStyle = _protocolColor(link.protocol || "ethernet")
                ctx.lineWidth = Math.max(1, Math.min(4, (link.bandwidth || 10) / 25))
                ctx.setLineDash(link.protocol === "wifi" ? [3, 3] : [])
                ctx.globalAlpha = 0.6
                ctx.beginPath()
                ctx.moveTo(src.x, src.y)
                ctx.lineTo(dst.x, dst.y)
                ctx.stroke()
                ctx.setLineDash([])
                ctx.globalAlpha = 1.0

                // Latency label at midpoint
                if (link.latency) {
                    var mx = (src.x + dst.x) / 2
                    var my = (src.y + dst.y) / 2
                    ctx.fillStyle = Theme.textMuted
                    ctx.font = "8px monospace"
                    ctx.fillText(link.latency + "ms", mx + 3, my - 2)
                }
            }
        }

        Connections {
            target: root
            function onNetworkLinksChanged() { networkLinkCanvas.requestPaint() }
            function onNetworkDevicesChanged() { networkLinkCanvas.requestPaint() }
        }
    }

    // ════════════════════════════
    //  Couche 8 : Caméras (avec CameraCone)
    // ════════════════════════════
    Repeater {
        model: root.showCameras ? root.cameras : []
        delegate: Item {
            x: modelData.x - 10
            y: modelData.y - 10
            width: 20
            height: 20

            // Cone de vision
            Canvas {
                anchors.centerIn: parent
                width: (modelData.range || 60) * 2
                height: (modelData.range || 60) * 2
                visible: modelData.online !== false
                opacity: 0.15

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width / 2
                    var cy = height / 2
                    var range = modelData.range || 60
                    var fov = (modelData.fov || 90) * Math.PI / 180
                    var angle = (modelData.angle || 0) * Math.PI / 180

                    ctx.fillStyle = Theme.accent
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.arc(cx, cy, range, angle - fov/2, angle + fov/2)
                    ctx.closePath()
                    ctx.fill()
                }
            }

            // Camera icon
            Rectangle {
                anchors.centerIn: parent
                width: 18; height: 18; radius: 9
                color: modelData.online !== false ? Theme.accent : Theme.textMuted
                opacity: 0.9

                Text {
                    anchors.centerIn: parent
                    text: "📷"
                    font.pixelSize: 10
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cameraClicked(modelData.id)
            }

            ToolTip.visible: camHover.hovered
            ToolTip.text: (modelData.name || "Caméra") + (modelData.online !== false ? " • active" : " • hors ligne")
            HoverHandler { id: camHover }
        }
    }

    // ════════════════════════════
    //  Couche 9 : Entités domotiques
    // ════════════════════════════
    Repeater {
        model: root.showDomoticEntities ? root.domoticEntities : []
        delegate: Item {
            x: modelData.x - 12
            y: modelData.y - 12
            width: 24
            height: 28

            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 22; height: 22; radius: 4
                color: _entityColor(modelData.state)
                opacity: 0.85

                Text {
                    anchors.centerIn: parent
                    text: _entityIcon(modelData.type)
                    font.pixelSize: 12
                }
            }

            // Value badge
            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                visible: modelData.value !== undefined
                text: String(modelData.value || "") + (modelData.unit || "")
                font.pixelSize: 7
                font.family: Theme.fontMono
                color: Theme.textSecondary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.domoticEntityClicked(modelData.id)
            }

            ToolTip.visible: entHover.hovered
            ToolTip.text: (modelData.name || modelData.type) + " — " + (modelData.state || "off")
                        + (modelData.value !== undefined ? (" : " + modelData.value + (modelData.unit || "")) : "")
            HoverHandler { id: entHover }
        }
    }

    // ════════════════════════════
    //  Couche 10 : WiFi heatmap / dead zones
    // ════════════════════════════
    Canvas {
        id: wifiCanvas
        anchors.fill: parent
        visible: root.showWifiHeatmap && (root.wifiZones.length > 0 || root.deadZones.length > 0)
        opacity: 0.3

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // WiFi zones (green radial gradients)
            for (var i = 0; i < root.wifiZones.length; i++) {
                var zone = root.wifiZones[i]
                var sig = Math.min(Math.max((zone.signal || 50) / 100, 0), 1)
                var rad = zone.radius || 80
                var gradient = ctx.createRadialGradient(zone.x, zone.y, 0, zone.x, zone.y, rad)
                gradient.addColorStop(0, "rgba(46, 204, 113, " + (0.4 * sig) + ")")
                gradient.addColorStop(1, "rgba(46, 204, 113, 0)")
                ctx.fillStyle = gradient
                ctx.beginPath()
                ctx.arc(zone.x, zone.y, rad, 0, Math.PI * 2)
                ctx.fill()
            }

            // Dead zones (red rectangles)
            for (var j = 0; j < root.deadZones.length; j++) {
                var dz = root.deadZones[j]
                ctx.fillStyle = "rgba(231, 76, 60, 0.2)"
                ctx.strokeStyle = "rgba(231, 76, 60, 0.5)"
                ctx.lineWidth = 1
                ctx.setLineDash([4, 4])
                ctx.fillRect(dz.x, dz.y, dz.w, dz.h)
                ctx.strokeRect(dz.x, dz.y, dz.w, dz.h)
                ctx.setLineDash([])
            }
        }

        Connections {
            target: root
            function onWifiZonesChanged() { wifiCanvas.requestPaint() }
            function onDeadZonesChanged() { wifiCanvas.requestPaint() }
        }
    }

    // ════════════════════════════
    //  Helpers réseau
    // ════════════════════════════

    function _networkIcon(typeOrProtocol) {
        switch (typeOrProtocol) {
            case "wifi":      return "📶"
            case "zigbee":    return "🔀"
            case "bluetooth": return "🔵"
            case "ethernet":  return "🔌"
            case "router":    return "📡"
            case "gateway":   return "🌐"
            case "phone":     return "📱"
            case "computer":  return "💻"
            case "tv":        return "📺"
            case "speaker":   return "🔊"
            case "printer":   return "🖨"
            default:          return "📟"
        }
    }

    function _protocolColor(protocol) {
        switch (protocol) {
            case "wifi":      return "#3498db"
            case "zigbee":    return "#2ecc71"
            case "bluetooth": return "#9b59b6"
            case "ethernet":  return "#e67e22"
            case "zwave":     return "#1abc9c"
            default:          return Theme.textMuted
        }
    }

    function _entityColor(state) {
        switch (state) {
            case "on":      return Theme.success
            case "off":     return Theme.bgInput
            case "heating": return "#e67e22"
            case "cooling": return "#3498db"
            case "alert":   return Theme.error
            case "locked":  return Theme.warning
            default:        return Theme.bgElevated
        }
    }

    function _entityIcon(type) {
        switch (type) {
            case "light":       return "💡"
            case "switch":      return "🔘"
            case "thermostat":  return "🌡"
            case "lock":        return "🔒"
            case "blinds":      return "🪟"
            case "plug":        return "🔌"
            case "speaker":     return "🔊"
            case "vacuum":      return "🤖"
            case "tv":          return "📺"
            case "fan":         return "🌀"
            default:            return "🏠"
        }
    }

    // ════════════════════════════════════════════════════
    //  SÉCURITÉ SPATIALE — Couches 11-15
    // ════════════════════════════════════════════════════

    // ── Données sécurité ──
    property var securityAlerts: []     // [{ id, riskType, severity, roomId, x, y, description, confidence }]
    property var forbiddenZones: []     // [{ id, x, y, w, h, label }]
    property var firePropagation: []    // [{ x, y, intensity }]  heatmap incendie
    property var suspectTrajectories: []// [{ entityId, points: [{x,y}], color }]
    property var offlineSecurityDevices: [] // [{ id, x, y, type, name }]

    property bool showSecurityAlerts: true
    property bool showForbiddenZones: true
    property bool showFirePropagation: false
    property bool showSuspectTrajectories: true
    property bool showOfflineSecurityDevices: true

    signal securityAlertClicked(string alertId)

    // ════════════════════════════
    //  Couche 11 : Zones interdites
    // ════════════════════════════
    Repeater {
        model: root.showForbiddenZones ? root.forbiddenZones : []
        delegate: Rectangle {
            x: modelData.x; y: modelData.y
            width: modelData.w; height: modelData.h
            color: Qt.rgba(1, 0, 0, 0.06)
            border.width: 2; border.color: Qt.rgba(1, 0, 0, 0.5)
            radius: 4

            // Hachures diagonales
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = "rgba(255, 0, 0, 0.15)"
                    ctx.lineWidth = 1
                    for (var i = -height; i < width; i += 12) {
                        ctx.beginPath()
                        ctx.moveTo(i, 0)
                        ctx.lineTo(i + height, height)
                        ctx.stroke()
                    }
                }
            }

            Text {
                anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 3
                text: "⛔ " + (modelData.label || "Zone interdite")
                font.pixelSize: 9; color: "#FF4444"
            }
        }
    }

    // ════════════════════════════
    //  Couche 12 : Alertes sécurité sur le plan
    // ════════════════════════════
    Repeater {
        model: root.showSecurityAlerts ? root.securityAlerts : []
        delegate: Item {
            x: modelData.x - 14; y: modelData.y - 14
            width: 28; height: 28

            Rectangle {
                anchors.centerIn: parent
                width: 22; height: 22; radius: 11
                color: {
                    var sev = modelData.severity || 0
                    if (sev >= 5) return "#FF0040"   // Emergency
                    if (sev >= 4) return "#FF4500"   // Critical
                    if (sev >= 3) return Theme.error  // High
                    if (sev >= 2) return Theme.warning// Medium
                    return Theme.info
                }
                opacity: 0.9

                Text {
                    anchors.centerIn: parent
                    text: {
                        var rt = modelData.riskType || 0
                        if (rt === 0) return "🚨"  // Intrusion
                        if (rt === 1 || rt === 2) return "🔥"  // Fire/Smoke
                        if (rt === 3) return "⚡"  // Electrical
                        if (rt === 4) return "🌐"  // Network
                        if (rt === 5) return "🏠"  // Domotic
                        return "⚠️"
                    }
                    font.pixelSize: 11
                }

                // Pulse urgence
                Rectangle {
                    anchors.centerIn: parent
                    width: 32; height: 32; radius: 16
                    color: "transparent"
                    border.width: 2; border.color: parent.color
                    visible: (modelData.severity || 0) >= 4

                    SequentialAnimation on scale {
                        running: visible; loops: Animation.Infinite
                        NumberAnimation { from: 0.8; to: 1.6; duration: 800 }
                        NumberAnimation { from: 1.6; to: 0.8; duration: 800 }
                    }
                    SequentialAnimation on opacity {
                        running: visible; loops: Animation.Infinite
                        NumberAnimation { from: 0.8; to: 0; duration: 800 }
                        NumberAnimation { from: 0; to: 0.8; duration: 800 }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.securityAlertClicked(modelData.id)
            }

            ToolTip.visible: secAlertHover.hovered
            ToolTip.text: (modelData.description || "Alerte") + "\n📍 " + (modelData.roomId || "—")
                        + " • " + Math.round((modelData.confidence || 0) * 100) + "%"
            HoverHandler { id: secAlertHover }
        }
    }

    // ════════════════════════════
    //  Couche 13 : Propagation incendie (Canvas)
    // ════════════════════════════
    Canvas {
        id: firePropCanvas
        anchors.fill: parent
        visible: root.showFirePropagation && root.firePropagation.length > 0
        opacity: 0.5

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            for (var i = 0; i < root.firePropagation.length; i++) {
                var pt = root.firePropagation[i]
                var intensity = Math.min(Math.max(pt.intensity || 0, 0), 1)
                var rad = 20 + intensity * 50
                var gradient = ctx.createRadialGradient(pt.x, pt.y, 0, pt.x, pt.y, rad)
                gradient.addColorStop(0, "rgba(255, 69, 0, " + (0.6 * intensity) + ")")
                gradient.addColorStop(0.5, "rgba(255, 165, 0, " + (0.3 * intensity) + ")")
                gradient.addColorStop(1, "rgba(255, 69, 0, 0)")
                ctx.fillStyle = gradient
                ctx.beginPath()
                ctx.arc(pt.x, pt.y, rad, 0, Math.PI * 2)
                ctx.fill()
            }
        }

        Connections {
            target: root
            function onFirePropagationChanged() { firePropCanvas.requestPaint() }
        }
    }

    // ════════════════════════════
    //  Couche 14 : Trajectoires suspectes (Canvas)
    // ════════════════════════════
    Canvas {
        id: suspectTrajCanvas
        anchors.fill: parent
        visible: root.showSuspectTrajectories && root.suspectTrajectories.length > 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            for (var t = 0; t < root.suspectTrajectories.length; t++) {
                var traj = root.suspectTrajectories[t]
                var pts = traj.points || []
                if (pts.length < 2) continue
                ctx.strokeStyle = traj.color || "#FF4444"
                ctx.lineWidth = 3
                ctx.setLineDash([6, 4])
                ctx.globalAlpha = 0.8
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var p = 1; p < pts.length; p++)
                    ctx.lineTo(pts[p].x, pts[p].y)
                ctx.stroke()
                ctx.setLineDash([])
                ctx.globalAlpha = 1.0

                // Tête de flèche rouge
                if (pts.length >= 2) {
                    var last = pts[pts.length - 1]
                    var prev = pts[pts.length - 2]
                    var angle = Math.atan2(last.y - prev.y, last.x - prev.x)
                    ctx.fillStyle = "#FF4444"
                    ctx.beginPath()
                    ctx.moveTo(last.x, last.y)
                    ctx.lineTo(last.x - 10 * Math.cos(angle - 0.4), last.y - 10 * Math.sin(angle - 0.4))
                    ctx.lineTo(last.x - 10 * Math.cos(angle + 0.4), last.y - 10 * Math.sin(angle + 0.4))
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }

        Connections {
            target: root
            function onSuspectTrajectoriesChanged() { suspectTrajCanvas.requestPaint() }
        }
    }

    // ════════════════════════════
    //  Couche 15 : Appareils sécurité hors-ligne
    // ════════════════════════════
    Repeater {
        model: root.showOfflineSecurityDevices ? root.offlineSecurityDevices : []
        delegate: Item {
            x: modelData.x - 12; y: modelData.y - 12
            width: 24; height: 24

            Rectangle {
                anchors.centerIn: parent
                width: 20; height: 20; radius: 10
                color: Theme.error; opacity: 0.3
                border.width: 2; border.color: Theme.error

                Text {
                    anchors.centerIn: parent
                    text: "✖"
                    font.pixelSize: 12; color: Theme.error
                }
            }

            ToolTip.visible: offDevHover.hovered
            ToolTip.text: (modelData.name || modelData.type || "Appareil") + " — HORS LIGNE"
            HoverHandler { id: offDevHover }
        }
    }
}
