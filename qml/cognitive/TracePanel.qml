import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  TracePanel — Traces hiérarchiques temps réel
//  trace_id, spans, parent/child, timestamps, module
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    signal traceSelected(string traceId, real worldX, real worldY)

    property string filterModule: ""
    property var traces: []  // [{ trace_id, module, spans: [{ span_id, parent_id, name, start_ms, end_ms, status }] }]

    // ── Connexion temps réel ──
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onEventEmitted(event) {
            if (!event.trace_id) return
            var copy = root.traces.slice()

            // Chercher trace existante
            var found = false
            for (var i = 0; i < copy.length; i++) {
                if (copy[i].trace_id === event.trace_id) {
                    var spans = copy[i].spans.slice()
                    spans.push({
                        span_id: event.span_id || ("span_" + Date.now()),
                        parent_id: event.parent_span_id || null,
                        name: event.event_type || "unknown",
                        start_ms: event.start_ms || 0,
                        end_ms: event.end_ms || event.elapsed_ms || 0,
                        status: event.status || "ok",
                        module: event.module || ""
                    })
                    copy[i] = Object.assign({}, copy[i], { spans: spans })
                    found = true
                    break
                }
            }

            if (!found) {
                copy.push({
                    trace_id: event.trace_id,
                    module: event.module || "",
                    timestamp: event.timestamp || new Date().toISOString(),
                    spatial: event.spatial || null,
                    spans: [{
                        span_id: event.span_id || ("span_" + Date.now()),
                        parent_id: null,
                        name: event.event_type || "unknown",
                        start_ms: event.start_ms || 0,
                        end_ms: event.end_ms || event.elapsed_ms || 0,
                        status: event.status || "ok",
                        module: event.module || ""
                    }]
                })
            }

            // Garder max 100 traces
            if (copy.length > 100) copy = copy.slice(-100)
            root.traces = copy
        }
    }

    // ── Filtrage ──
    property var filteredTraces: {
        if (!root.filterModule) return root.traces
        var result = []
        for (var i = 0; i < root.traces.length; i++) {
            if (root.traces[i].module === root.filterModule) {
                result.push(root.traces[i])
            } else {
                // Vérifier les spans
                for (var j = 0; j < root.traces[i].spans.length; j++) {
                    if (root.traces[i].spans[j].module === root.filterModule) {
                        result.push(root.traces[i])
                        break
                    }
                }
            }
        }
        return result
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing4

        // ── Header + filtre ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            Text {
                text: "TRACES"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Bold
                color: Theme.textSecondary
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            // Badge count
            Rectangle {
                width: countText.implicitWidth + 10
                height: 18
                radius: 9
                color: Theme.bgElevated
                visible: root.filteredTraces.length > 0

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: root.filteredTraces.length.toString()
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.accent
                }
            }

            // Clear filter
            Rectangle {
                width: 20; height: 20; radius: Theme.radiusSmall
                color: clearMouse.containsMouse ? Theme.bgHover : "transparent"
                visible: root.filterModule !== ""

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 10
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.filterModule = ""
                }
            }
        }

        // Filtre actif
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            radius: Theme.radiusSmall
            color: Theme.bgElevated
            visible: root.filterModule !== ""

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing8
                anchors.rightMargin: Theme.spacing8

                Text {
                    text: "Module : " + root.filterModule
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontMicro
                    color: Theme.accent
                }
            }
        }

        // ── Liste de traces ──
        ListView {
            id: traceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.filteredTraces
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                width: traceList.width
                height: traceCol.implicitHeight + Theme.spacing8
                radius: Theme.radiusSmall
                color: traceMouse.containsMouse ? Theme.bgHover : Theme.bgElevated

                property var trace: modelData

                ColumnLayout {
                    id: traceCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing4
                    spacing: 2

                    // Trace header
                    RowLayout {
                        spacing: Theme.spacing4

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: _traceStatusColor(trace)
                        }

                        Text {
                            text: trace.trace_id ? trace.trace_id.substring(0, 8) : "—"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontMicro
                            color: Theme.accent
                        }

                        Text {
                            text: trace.module || ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontMicro
                            color: Theme.textMuted
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: trace.spans ? trace.spans.length + " spans" : ""
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: Theme.textMuted
                        }
                    }

                    // Spans (max 5 visibles)
                    Repeater {
                        model: trace.spans ? Math.min(trace.spans.length, 5) : 0
                        delegate: RowLayout {
                            Layout.leftMargin: 12
                            spacing: Theme.spacing4

                            property var span: trace.spans[index]

                            // Indentation (tree-like)
                            Rectangle {
                                width: 1; height: 14
                                color: Theme.textMuted
                                opacity: 0.3
                            }

                            Rectangle {
                                width: 4; height: 4; radius: 2
                                color: span.status === "error" ? Theme.error :
                                       span.status === "ok" ? Theme.success : Theme.textMuted
                            }

                            Text {
                                text: span.name || "—"
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: span.end_ms ? span.end_ms.toFixed(0) + "ms" : ""
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                                color: {
                                    if (span.end_ms > 3000) return Theme.error
                                    if (span.end_ms > 1000) return Theme.warning
                                    return Theme.textMuted
                                }
                            }
                        }
                    }

                    // "...et N de plus"
                    Text {
                        visible: trace.spans && trace.spans.length > 5
                        text: "… +" + (trace.spans.length - 5) + " spans"
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: Theme.textMuted
                        Layout.leftMargin: 12
                    }
                }

                MouseArea {
                    id: traceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var wx = trace.spatial ? trace.spatial.x : 0
                        var wy = trace.spatial ? trace.spatial.y : 0
                        root.traceSelected(trace.trace_id, wx, wy)
                    }
                }
            }
        }

        // ── Empty state ──
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.filteredTraces.length === 0
            text: root.filterModule ? "Aucune trace pour « " + root.filterModule + " »"
                                    : "En attente de traces…"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            color: Theme.textMuted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    function _traceStatusColor(trace) {
        if (!trace.spans || trace.spans.length === 0) return Theme.textMuted
        for (var i = 0; i < trace.spans.length; i++) {
            if (trace.spans[i].status === "error") return Theme.error
        }
        return Theme.success
    }
}
