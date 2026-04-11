import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebSockets
import "../theme"

// ═══════════════════════════════════════════════════════
//  SpatialNetworkIntegration — Bridge NetworkMap + HomeGraph
//
//  Connects to:
//   • NetworkMap   ws://localhost:8790  (réseau local)
//   • HomeGraph    ws://localhost:8784  (domotique)
//
//  Fournit les données réseau/domotique pour :
//   SpatialOverlay, FloorPlanProperties, CognitiveSpatialView
// ═══════════════════════════════════════════════════════

Item {
    id: root

    // ── Configuration ──
    property string networkMapUrl: "ws://localhost:8790/ws"
    property string homeGraphUrl:  "ws://localhost:8784/ws"
    property int reconnectInterval: 5000

    // ── État de connexion ──
    property bool networkConnected: networkWs.status === WebSocket.Open
    property bool homeGraphConnected: homeGraphWs.status === WebSocket.Open
    property bool allConnected: networkConnected && homeGraphConnected

    // ── Données réseau ──
    property var networkDevices: []     // [{ id, name, ip, mac, type, protocol, vendor, rssi, latency, x, y, online }]
    property var networkLinks: []       // [{ sourceId, targetId, bandwidth, latency, protocol }]
    property var wifiZones: []          // [{ x, y, radius, ssid, signal }]
    property var deadZones: []          // [{ x, y, w, h }]

    // ── Données domotique ──
    property var domoticEntities: []    // [{ id, name, type, state, room, x, y, value, unit }]
    property var cameras: []            // [{ id, name, x, y, angle, fov, range, online }]
    property var rooms: ({})            // { roomId: { name, devices: [], sensors: [] } }

    // ── Signaux ──
    signal deviceUpdated(string deviceId, var data)
    signal sensorUpdated(string sensorId, var data)
    signal cameraUpdated(string cameraId, var data)
    signal networkUpdated()
    signal entityStateChanged(string entityId, string newState)

    // ── Compteurs ──
    readonly property int deviceCount: networkDevices.length
    readonly property int entityCount: domoticEntities.length
    readonly property int cameraCount: cameras.length
    readonly property int onlineDeviceCount: {
        var c = 0
        for (var i = 0; i < networkDevices.length; i++)
            if (networkDevices[i].online) c++
        return c
    }

    // ══════════════════════════════════════════════
    //  WebSocket — NetworkMap (port 8790)
    // ══════════════════════════════════════════════

    WebSocket {
        id: networkWs
        url: root.networkMapUrl
        active: true

        onTextMessageReceived: function(message) {
            try {
                var msg = JSON.parse(message)
                _handleNetworkMessage(msg)
            } catch (e) {
                console.warn("[SpatialNetworkIntegration] NetworkMap parse error:", e)
            }
        }

        onStatusChanged: {
            if (status === WebSocket.Error) {
                console.warn("[SpatialNetworkIntegration] NetworkMap WS error:", errorString)
                networkReconnectTimer.start()
            } else if (status === WebSocket.Open) {
                console.log("[SpatialNetworkIntegration] NetworkMap connected")
                networkReconnectTimer.stop()
                refreshNetwork()
            } else if (status === WebSocket.Closed) {
                networkReconnectTimer.start()
            }
        }
    }

    Timer {
        id: networkReconnectTimer
        interval: root.reconnectInterval
        repeat: false
        onTriggered: { networkWs.active = false; networkWs.active = true }
    }

    // ══════════════════════════════════════════════
    //  WebSocket — HomeGraph (port 8784)
    // ══════════════════════════════════════════════

    WebSocket {
        id: homeGraphWs
        url: root.homeGraphUrl
        active: true

        onTextMessageReceived: function(message) {
            try {
                var msg = JSON.parse(message)
                _handleHomeGraphMessage(msg)
            } catch (e) {
                console.warn("[SpatialNetworkIntegration] HomeGraph parse error:", e)
            }
        }

        onStatusChanged: {
            if (status === WebSocket.Error) {
                console.warn("[SpatialNetworkIntegration] HomeGraph WS error:", errorString)
                homeGraphReconnectTimer.start()
            } else if (status === WebSocket.Open) {
                console.log("[SpatialNetworkIntegration] HomeGraph connected")
                homeGraphReconnectTimer.stop()
                refreshHomeGraph()
            } else if (status === WebSocket.Closed) {
                homeGraphReconnectTimer.start()
            }
        }
    }

    Timer {
        id: homeGraphReconnectTimer
        interval: root.reconnectInterval
        repeat: false
        onTriggered: { homeGraphWs.active = false; homeGraphWs.active = true }
    }

    // ══════════════════════════════════════════════
    //  Refresh polling (30s)
    // ══════════════════════════════════════════════

    Timer {
        id: pollTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (root.networkConnected)   refreshNetwork()
            if (root.homeGraphConnected) refreshHomeGraph()
        }
    }

    // ══════════════════════════════════════════════
    //  Public API
    // ══════════════════════════════════════════════

    function refreshNetwork() {
        if (!networkWs || networkWs.status !== WebSocket.Open) return
        networkWs.sendTextMessage(JSON.stringify({
            type: "request", command: "scan"
        }))
    }

    function refreshHomeGraph() {
        if (!homeGraphWs || homeGraphWs.status !== WebSocket.Open) return
        homeGraphWs.sendTextMessage(JSON.stringify({
            type: "request", command: "full_state"
        }))
    }

    function linkDeviceToItem(itemId, deviceId) {
        // Lookup device info
        var device = _findDevice(deviceId)
        return device || null
    }

    function unlinkDevice(itemId) {
        // No-op on network side, just return
        return true
    }

    function getDevicesInRoom(roomId) {
        var r = root.rooms[roomId]
        return r ? (r.devices || []) : []
    }

    function getSensorsInRoom(roomId) {
        var r = root.rooms[roomId]
        return r ? (r.sensors || []) : []
    }

    function getNetworkLinksForDevice(deviceId) {
        var result = []
        for (var i = 0; i < root.networkLinks.length; i++) {
            var link = root.networkLinks[i]
            if (link.sourceId === deviceId || link.targetId === deviceId)
                result.push(link)
        }
        return result
    }

    function getDeviceById(deviceId) {
        return _findDevice(deviceId)
    }

    function getEntityById(entityId) {
        for (var i = 0; i < root.domoticEntities.length; i++) {
            if (root.domoticEntities[i].id === entityId)
                return root.domoticEntities[i]
        }
        return null
    }

    function getCameraById(cameraId) {
        for (var i = 0; i < root.cameras.length; i++) {
            if (root.cameras[i].id === cameraId)
                return root.cameras[i]
        }
        return null
    }

    // ══════════════════════════════════════════════
    //  Internal — NetworkMap message handler
    // ══════════════════════════════════════════════

    function _handleNetworkMessage(msg) {
        switch (msg.type) {
        case "scan_result":
        case "devices":
            if (Array.isArray(msg.devices)) {
                root.networkDevices = msg.devices
                root.networkUpdated()
            }
            break

        case "links":
            if (Array.isArray(msg.links)) {
                root.networkLinks = msg.links
                root.networkUpdated()
            }
            break

        case "wifi_zones":
            if (Array.isArray(msg.zones))
                root.wifiZones = msg.zones
            if (Array.isArray(msg.dead_zones))
                root.deadZones = msg.dead_zones
            break

        case "device_update":
            if (msg.device) {
                _updateDevice(msg.device)
                root.deviceUpdated(msg.device.id, msg.device)
            }
            break

        case "full_state":
            if (msg.devices)     root.networkDevices = msg.devices
            if (msg.links)       root.networkLinks = msg.links
            if (msg.wifi_zones)  root.wifiZones = msg.wifi_zones
            if (msg.dead_zones)  root.deadZones = msg.dead_zones
            root.networkUpdated()
            break
        }
    }

    // ══════════════════════════════════════════════
    //  Internal — HomeGraph message handler
    // ══════════════════════════════════════════════

    function _handleHomeGraphMessage(msg) {
        switch (msg.type) {
        case "full_state":
            if (msg.entities)  root.domoticEntities = msg.entities
            if (msg.cameras)   root.cameras = msg.cameras
            if (msg.rooms)     root.rooms = msg.rooms
            break

        case "entity_update":
            if (msg.entity) {
                _updateEntity(msg.entity)
                root.entityStateChanged(msg.entity.id, msg.entity.state || "")
            }
            break

        case "camera_update":
            if (msg.camera) {
                _updateCamera(msg.camera)
                root.cameraUpdated(msg.camera.id, msg.camera)
            }
            break

        case "sensor_update":
            if (msg.sensor) {
                root.sensorUpdated(msg.sensor.id, msg.sensor)
            }
            break
        }
    }

    // ══════════════════════════════════════════════
    //  Internal helpers
    // ══════════════════════════════════════════════

    function _findDevice(deviceId) {
        for (var i = 0; i < root.networkDevices.length; i++) {
            if (root.networkDevices[i].id === deviceId)
                return root.networkDevices[i]
        }
        return null
    }

    function _updateDevice(device) {
        var copy = root.networkDevices.slice()
        for (var i = 0; i < copy.length; i++) {
            if (copy[i].id === device.id) {
                copy[i] = device
                root.networkDevices = copy
                return
            }
        }
        // New device
        copy.push(device)
        root.networkDevices = copy
    }

    function _updateEntity(entity) {
        var copy = root.domoticEntities.slice()
        for (var i = 0; i < copy.length; i++) {
            if (copy[i].id === entity.id) {
                copy[i] = entity
                root.domoticEntities = copy
                return
            }
        }
        copy.push(entity)
        root.domoticEntities = copy
    }

    function _updateCamera(camera) {
        var copy = root.cameras.slice()
        for (var i = 0; i < copy.length; i++) {
            if (copy[i].id === camera.id) {
                copy[i] = camera
                root.cameras = copy
                return
            }
        }
        copy.push(camera)
        root.cameras = copy
    }
}
