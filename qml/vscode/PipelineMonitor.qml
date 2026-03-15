import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1E1E1E"

    // ── Données internes ──
    property var moduleStates: ({})
    property var recentEvents: []
    property string selectedModule: ""

    // Couleurs par état
    function stateColor(state) {
        switch (state) {
        case "active":      return "#4EC9B0"
        case "processing":  return "#DCDCAA"
        case "error":       return "#F44747"
        case "unavailable": return "#5A5A5A"
        default:            return "#3C3C3C"  // idle
        }
    }

    function stateBorderColor(state) {
        switch (state) {
        case "active":      return "#4EC9B0"
        case "processing":  return "#CE9178"
        case "error":       return "#F44747"
        case "unavailable": return "#5A5A5A"
        default:            return "#007ACC"
        }
    }

    // ── Chargement initial + timer de rafraîchissement ──
    Timer {
        id: refreshTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: root.refreshSnapshot()
    }

    Component.onCompleted: {
        refreshSnapshot()
        loadRecentEvents()
    }

    function refreshSnapshot() {
        if (typeof pipelineEventBus === 'undefined') return
        var snap = pipelineEventBus.getPipelineSnapshot()
        if (snap && snap.modules) {
            var newStates = {}
            for (var key in snap.modules) {
                newStates[key] = snap.modules[key]
            }
            root.moduleStates = newStates
        }
    }

    function loadRecentEvents() {
        if (typeof pipelineEventBus === 'undefined') return
        var evts = pipelineEventBus.getRecentEvents(80)
        var arr = []
        for (var i = 0; i < evts.length; i++)
            arr.push(evts[i])
        root.recentEvents = arr
    }

    // Écouter les nouveaux événements en temps réel
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onEventEmitted(event) {
            // Ajouter en tête, limiter à 200
            var arr = root.recentEvents.slice()
            arr.unshift(event)
            if (arr.length > 200) arr.length = 200
            root.recentEvents = arr
        }

        function onModuleStateChanged(moduleName, state) {
            var copy = Object.assign({}, root.moduleStates)
            if (!copy[moduleName]) copy[moduleName] = {}
            copy[moduleName].state = state
            root.moduleStates = copy
        }
    }

    // ── Pipeline DAG definition ──
    // Chaque nœud : { id, label, x, y }
    // Position normalisée dans un grid 6 colonnes x 3 lignes
    readonly property var pipelineNodes: [
        { id: "audio_capture",  label: "Audio\nCapture",   col: 0, row: 1 },
        { id: "preprocessor",   label: "Preprocessor",     col: 1, row: 1 },
        { id: "vad",            label: "VAD",              col: 2, row: 1 },
        { id: "stt",            label: "STT",              col: 3, row: 1 },
        { id: "wake_word",      label: "Wake\nWord",       col: 2, row: 0 },
        { id: "nlu",            label: "NLU",              col: 4, row: 0 },
        { id: "orchestrator",   label: "Orchestrator",     col: 4, row: 1 },
        { id: "claude",         label: "Claude",           col: 5, row: 1 },
        { id: "memory",         label: "Memory",           col: 5, row: 0 },
        { id: "tts",            label: "TTS",              col: 6, row: 1 },
        { id: "audio_output",   label: "Audio\nOutput",    col: 7, row: 1 },
        { id: "gui",            label: "GUI",              col: 4, row: 2 }
    ]

    // Arêtes du DAG (flux de données)
    readonly property var pipelineEdges: [
        { from: "audio_capture", to: "preprocessor" },
        { from: "preprocessor",  to: "vad" },
        { from: "vad",           to: "stt" },
        { from: "vad",           to: "wake_word" },
        { from: "stt",           to: "orchestrator" },
        { from: "stt",           to: "nlu" },
        { from: "nlu",           to: "orchestrator" },
        { from: "orchestrator",  to: "claude" },
        { from: "orchestrator",  to: "gui" },
        { from: "claude",        to: "memory" },
        { from: "claude",        to: "tts" },
        { from: "tts",           to: "audio_output" }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#252526"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    text: "PIPELINE MONITOR"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#007ACC"
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                // Correlation ID
                Text {
                    text: {
                        if (typeof pipelineEventBus !== 'undefined') {
                            var cid = pipelineEventBus.getCorrelationId()
                            return cid ? ("CID: " + cid) : "No active interaction"
                        }
                        return ""
                    }
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 10
                    color: "#808080"
                }
            }
        }

        // ── SplitView vertical : DAG en haut, Timeline en bas ──
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical

            // ── DAG Pipeline View ──
            Rectangle {
                id: dagContainer
                SplitView.fillWidth: true
                SplitView.preferredHeight: 280
                SplitView.minimumHeight: 180
                color: "#1E1E1E"

                // Canvas pour dessiner les arêtes
                Canvas {
                    id: edgeCanvas
                    anchors.fill: parent

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = "#3C3C3C"
                        ctx.lineWidth = 1.5

                        for (var i = 0; i < root.pipelineEdges.length; i++) {
                            var edge = root.pipelineEdges[i]
                            var fromNode = dagContainer.findNode(edge.from)
                            var toNode = dagContainer.findNode(edge.to)
                            if (!fromNode || !toNode) continue

                            var fx = dagContainer.nodeX(fromNode) + dagContainer.nodeW / 2
                            var fy = dagContainer.nodeY(fromNode) + dagContainer.nodeH / 2
                            var tx = dagContainer.nodeX(toNode) + dagContainer.nodeW / 2
                            var ty = dagContainer.nodeY(toNode) + dagContainer.nodeH / 2

                            // Colorer l'arête si le module source est actif
                            var sourceState = dagContainer.getModuleState(edge.from)
                            if (sourceState === "active" || sourceState === "processing")
                                ctx.strokeStyle = "#4EC9B050"
                            else
                                ctx.strokeStyle = "#3C3C3C"

                            ctx.beginPath()
                            ctx.moveTo(fx, fy)
                            // Courbe de Bézier pour un rendu plus propre
                            var mx = (fx + tx) / 2
                            ctx.bezierCurveTo(mx, fy, mx, ty, tx, ty)
                            ctx.stroke()
                        }
                    }

                    // Re-dessiner quand les états changent
                    Connections {
                        target: root
                        function onModuleStatesChanged() { edgeCanvas.requestPaint() }
                    }

                    Timer {
                        interval: 600
                        repeat: true
                        running: true
                        onTriggered: edgeCanvas.requestPaint()
                    }
                }

                // Propriétés de layout du DAG
                readonly property int dagCols: 8
                readonly property int dagRows: 3
                readonly property real nodeW: 90
                readonly property real nodeH: 52
                readonly property real padX: 16
                readonly property real padY: 20

                function nodeX(node) {
                    var usable = edgeCanvas.width - 2 * padX - nodeW
                    return padX + (node.col / (dagCols - 1)) * usable
                }
                function nodeY(node) {
                    var usable = edgeCanvas.height - 2 * padY - nodeH
                    return padY + (node.row / (dagRows - 1)) * usable
                }

                function findNode(id) {
                    for (var i = 0; i < root.pipelineNodes.length; i++) {
                        if (root.pipelineNodes[i].id === id)
                            return root.pipelineNodes[i]
                    }
                    return null
                }

                function getModuleState(id) {
                    if (root.moduleStates[id] && root.moduleStates[id].state)
                        return root.moduleStates[id].state
                    return "idle"
                }

                // Nœuds du pipeline
                Repeater {
                    model: root.pipelineNodes

                    Rectangle {
                        id: nodeRect
                        x: edgeCanvas.parent.nodeX(modelData)
                        y: edgeCanvas.parent.nodeY(modelData)
                        width: edgeCanvas.parent.nodeW
                        height: edgeCanvas.parent.nodeH
                        radius: 6
                        color: {
                            var st = edgeCanvas.parent.getModuleState(modelData.id)
                            return root.stateColor(st)
                        }
                        border.width: root.selectedModule === modelData.id ? 2 : 1
                        border.color: {
                            if (root.selectedModule === modelData.id) return "#FFFFFF"
                            var st = edgeCanvas.parent.getModuleState(modelData.id)
                            return root.stateBorderColor(st)
                        }
                        opacity: 0.9

                        // Animation pulsation pour module actif
                        SequentialAnimation on opacity {
                            running: edgeCanvas.parent.getModuleState(modelData.id) === "processing"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.9; duration: 600; easing.type: Easing.InOutSine }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedModule = (root.selectedModule === modelData.id)
                                                      ? "" : modelData.id
                            }
                        }
                    }
                }

                // ── Légende des états ──
                Row {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 10
                    spacing: 12

                    Repeater {
                        model: [
                            { label: "Idle",       color: "#3C3C3C" },
                            { label: "Active",     color: "#4EC9B0" },
                            { label: "Processing", color: "#DCDCAA" },
                            { label: "Error",      color: "#F44747" }
                        ]

                        Row {
                            spacing: 4
                            Rectangle {
                                width: 10; height: 10; radius: 2
                                color: modelData.color
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.label
                                font.pixelSize: 9
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                color: "#808080"
                            }
                        }
                    }
                }
            }

            // ── Bottom half: Event Timeline + Inspector ──
            SplitView {
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                SplitView.minimumHeight: 200
                orientation: Qt.Horizontal

                // ── Event Timeline ──
                Rectangle {
                    SplitView.fillWidth: true
                    SplitView.minimumWidth: 300
                    color: "#1E1E1E"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            color: "#252526"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: "EVENT TIMELINE"
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#808080"
                                    font.letterSpacing: 1
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: root.recentEvents.length + " events"
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 10
                                    color: "#5A5A5A"
                                }
                            }
                        }

                        ListView {
                            id: eventList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.recentEvents

                            delegate: Rectangle {
                                width: eventList.width
                                height: 26
                                color: index % 2 === 0 ? "#1E1E1E" : "#252526"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    // Timestamp (compact)
                                    Text {
                                        text: {
                                            var ts = modelData.timestamp || ""
                                            return ts.length > 12 ? ts.substring(11, 23) : ts
                                        }
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 9
                                        color: "#5A5A5A"
                                        Layout.preferredWidth: 80
                                    }

                                    // Module badge
                                    Rectangle {
                                        Layout.preferredWidth: 72
                                        Layout.preferredHeight: 16
                                        radius: 3
                                        color: root.stateColor(modelData.module === root.selectedModule ? "active" : "idle")
                                        opacity: 0.8

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.module || ""
                                            font.family: "Cascadia Code, Fira Code, Consolas"
                                            font.pixelSize: 8
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                    }

                                    // Event type
                                    Text {
                                        text: modelData.event_type || ""
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 10
                                        color: "#D4D4D4"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // Elapsed ms
                                    Text {
                                        text: {
                                            var ms = modelData.elapsed_ms
                                            return (ms !== undefined && ms > 0) ? (ms + "ms") : ""
                                        }
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 9
                                        color: "#CE9178"
                                        Layout.preferredWidth: 50
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.module)
                                            root.selectedModule = modelData.module
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }
                        }
                    }
                }

                // ── Module Inspector ──
                Rectangle {
                    SplitView.preferredWidth: 280
                    SplitView.minimumWidth: 200
                    color: "#252526"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            color: "#1E1E1E"

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                text: root.selectedModule
                                      ? ("INSPECTOR: " + root.selectedModule.toUpperCase())
                                      : "INSPECTOR"
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#808080"
                                font.letterSpacing: 1
                            }
                        }

                        // Contenu de l'inspecteur
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentHeight: inspectorCol.height
                            clip: true

                            ColumnLayout {
                                id: inspectorCol
                                width: parent.width
                                spacing: 8

                                // Pas de module sélectionné
                                Text {
                                    visible: !root.selectedModule
                                    text: "Cliquer sur un module\npour l'inspecter"
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 11
                                    color: "#5A5A5A"
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 40
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // Module sélectionné — infos
                                ColumnLayout {
                                    visible: !!root.selectedModule
                                    Layout.fillWidth: true
                                    Layout.margins: 12
                                    spacing: 6

                                    // État
                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: "État:"
                                            font.family: "Cascadia Code, Fira Code, Consolas"
                                            font.pixelSize: 11
                                            color: "#808080"
                                        }
                                        Rectangle {
                                            width: stateText.width + 12
                                            height: 20
                                            radius: 4
                                            color: root.stateColor(inspectorState())

                                            Text {
                                                id: stateText
                                                anchors.centerIn: parent
                                                text: inspectorState()
                                                font.family: "Cascadia Code, Fira Code, Consolas"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: "#FFFFFF"
                                            }
                                        }
                                    }

                                    // Dernier événement
                                    Text {
                                        text: "Dernier event: " + inspectorLastEvent()
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 10
                                        color: "#D4D4D4"
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                    }

                                    // Erreur
                                    Text {
                                        visible: inspectorError() !== ""
                                        text: "Erreur: " + inspectorError()
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 10
                                        color: "#F44747"
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                    }

                                    // Séparateur
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#3C3C3C"
                                        Layout.topMargin: 4
                                        Layout.bottomMargin: 4
                                    }

                                    // Métriques
                                    Text {
                                        text: "Métriques"
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#808080"
                                    }

                                    Text {
                                        text: inspectorMetrics()
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 10
                                        color: "#CE9178"
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                    }

                                    // Séparateur
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#3C3C3C"
                                        Layout.topMargin: 4
                                        Layout.bottomMargin: 4
                                    }

                                    // Timeline filtrée pour ce module
                                    Text {
                                        text: "Événements récents"
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#808080"
                                    }

                                    Repeater {
                                        model: moduleFilteredEvents()

                                        Text {
                                            text: modelData.event_type + (modelData.elapsed_ms > 0 ? (" +" + modelData.elapsed_ms + "ms") : "")
                                            font.family: "Cascadia Code, Fira Code, Consolas"
                                            font.pixelSize: 9
                                            color: "#D4D4D4"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                handle: Rectangle {
                    implicitWidth: 1
                    color: "#3C3C3C"
                }
            }

            handle: Rectangle {
                implicitHeight: 1
                color: "#3C3C3C"
            }
        }
    }

    // ── Helper functions pour l'inspecteur ──
    function inspectorState() {
        if (!root.selectedModule) return "idle"
        var info = root.moduleStates[root.selectedModule]
        return info ? (info.state || "idle") : "idle"
    }

    function inspectorLastEvent() {
        if (!root.selectedModule) return "-"
        var info = root.moduleStates[root.selectedModule]
        return info ? (info.last_event || "-") : "-"
    }

    function inspectorError() {
        if (!root.selectedModule) return ""
        var info = root.moduleStates[root.selectedModule]
        return info ? (info.last_error || "") : ""
    }

    function inspectorMetrics() {
        if (!root.selectedModule) return "-"
        var info = root.moduleStates[root.selectedModule]
        if (!info || !info.metrics) return "(aucune)"
        var lines = []
        for (var key in info.metrics) {
            lines.push(key + ": " + JSON.stringify(info.metrics[key]))
        }
        return lines.length > 0 ? lines.join("\n") : "(aucune)"
    }

    function moduleFilteredEvents() {
        if (!root.selectedModule) return []
        var filtered = []
        for (var i = 0; i < root.recentEvents.length && filtered.length < 15; i++) {
            if (root.recentEvents[i].module === root.selectedModule)
                filtered.push(root.recentEvents[i])
        }
        return filtered
    }
}
