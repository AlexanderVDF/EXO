import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  AnomalyPanel — Anomalies PipelineTracer
//  Type, module, sévérité, zoom spatial
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    signal anomalyClicked(string anomalyId, real worldX, real worldY)

    property var anomalies: []  // [{ id, type, module, severity, message, timestamp, spatial: {x,y} }]
    property string filterSeverity: ""  // "", "critical", "high", "medium", "low"

    // ── Connexion temps réel ──
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onEventEmitted(event) {
            if (event.event_type !== "anomaly" && !event.anomaly) return
            var copy = root.anomalies.slice()
            copy.push({
                id: event.anomaly_id || ("anom_" + Date.now()),
                type: event.anomaly_type || event.event_type || "unknown",
                module: event.module || "",
                severity: event.severity || "medium",
                message: event.message || event.anomaly_message || "",
                timestamp: event.timestamp || new Date().toISOString(),
                spatial: event.spatial || null,
                resolved: false
            })
            if (copy.length > 200) copy = copy.slice(-200)
            root.anomalies = copy
        }
    }

    // ── Filtrage ──
    property var filteredAnomalies: {
        if (!root.filterSeverity) return root.anomalies
        var result = []
        for (var i = 0; i < root.anomalies.length; i++) {
            if (root.anomalies[i].severity === root.filterSeverity)
                result.push(root.anomalies[i])
        }
        return result
    }

    // ── Stats ──
    property int criticalCount: _countSeverity("critical")
    property int highCount: _countSeverity("high")
    property int mediumCount: _countSeverity("medium")
    property int lowCount: _countSeverity("low")

    function _countSeverity(level) {
        var c = 0
        for (var i = 0; i < root.anomalies.length; i++) {
            if (root.anomalies[i].severity === level) c++
        }
        return c
    }

    function _severityColor(severity) {
        switch (severity) {
            case "critical": return Theme.error
            case "high":     return "#CE9178"
            case "medium":   return Theme.warning
            case "low":      return Theme.info
            default:         return Theme.textMuted
        }
    }

    function _severityIcon(severity) {
        switch (severity) {
            case "critical": return "🔴"
            case "high":     return "🟠"
            case "medium":   return "🟡"
            case "low":      return "🔵"
            default:         return "⚪"
        }
    }

    function _anomalyTypeIcon(type) {
        switch (type) {
            case "latency":    return "⏱"
            case "error":      return "❌"
            case "timeout":    return "⌛"
            case "crash":      return "💥"
            case "drift":      return "📉"
            case "spike":      return "📈"
            case "disconnect": return "🔌"
            default:           return "⚠"
        }
    }

    function _timeAgo(timestamp) {
        if (!timestamp) return ""
        var diff = Date.now() - new Date(timestamp).getTime()
        if (diff < 60000) return Math.floor(diff / 1000) + "s"
        if (diff < 3600000) return Math.floor(diff / 60000) + "min"
        return Math.floor(diff / 3600000) + "h"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "ANOMALIES"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Bold
                color: Theme.textSecondary
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            // Total badge
            Rectangle {
                width: totalText.implicitWidth + 10
                height: 18
                radius: 9
                color: root.criticalCount > 0 ? Qt.rgba(Qt.color(Theme.error).r, Qt.color(Theme.error).g, Qt.color(Theme.error).b, 0.2) : Theme.bgElevated

                Text {
                    id: totalText
                    anchors.centerIn: parent
                    text: root.anomalies.length.toString()
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: root.criticalCount > 0 ? Theme.error : Theme.accent
                }
            }
        }

        // ── Severity filter chips ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing4

            Repeater {
                model: [
                    { label: "Critique", level: "critical", count: root.criticalCount },
                    { label: "Haute",    level: "high",     count: root.highCount },
                    { label: "Moyenne",  level: "medium",   count: root.mediumCount },
                    { label: "Basse",    level: "low",      count: root.lowCount }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.radiusSmall
                    color: root.filterSeverity === modelData.level
                        ? Qt.rgba(Qt.color(root._severityColor(modelData.level)).r,
                                  Qt.color(root._severityColor(modelData.level)).g,
                                  Qt.color(root._severityColor(modelData.level)).b, 0.2)
                        : chipMouse.containsMouse ? Theme.bgHover : Theme.bgElevated
                    border.width: root.filterSeverity === modelData.level ? 1 : 0
                    border.color: root._severityColor(modelData.level)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: modelData.count.toString()
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: root._severityColor(modelData.level)
                        }
                        Text {
                            text: modelData.label
                            font.family: Theme.fontMono
                            font.pixelSize: 8
                            color: Theme.textMuted
                        }
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.filterSeverity = root.filterSeverity === modelData.level
                                ? "" : modelData.level
                        }
                    }
                }
            }
        }

        // ── Liste d'anomalies ──
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.filteredAnomalies
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                width: parent ? parent.width : 0
                height: anomCol.implicitHeight + Theme.spacing8
                radius: Theme.radiusSmall
                color: anomMouse.containsMouse ? Theme.bgHover : Theme.bgElevated

                property var anomaly: modelData

                ColumnLayout {
                    id: anomCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing4
                    spacing: 2

                    RowLayout {
                        spacing: Theme.spacing4

                        Text {
                            text: root._severityIcon(anomaly.severity)
                            font.pixelSize: 12
                        }

                        Text {
                            text: root._anomalyTypeIcon(anomaly.type) + " " + anomaly.type
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                            color: root._severityColor(anomaly.severity)
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root._timeAgo(anomaly.timestamp)
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: Theme.textMuted
                        }
                    }

                    RowLayout {
                        spacing: Theme.spacing4

                        Text {
                            text: anomaly.module || ""
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: Theme.accent
                            visible: text !== ""
                        }

                        Text {
                            text: anomaly.message || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontMicro
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Spatial badge
                    Rectangle {
                        visible: anomaly.spatial !== null && anomaly.spatial !== undefined
                        width: spatialRow.implicitWidth + 8
                        height: 16
                        radius: 8
                        color: Qt.rgba(Qt.color(Theme.accent).r, Qt.color(Theme.accent).g, Qt.color(Theme.accent).b, 0.1)

                        RowLayout {
                            id: spatialRow
                            anchors.centerIn: parent
                            spacing: 3

                            Text { text: "📍"; font.pixelSize: 8 }
                            Text {
                                text: anomaly.spatial
                                    ? "x:" + (anomaly.spatial.x || 0).toFixed(0) + " y:" + (anomaly.spatial.y || 0).toFixed(0)
                                    : ""
                                font.family: Theme.fontMono
                                font.pixelSize: 8
                                color: Theme.accent
                            }
                        }
                    }
                }

                MouseArea {
                    id: anomMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var wx = anomaly.spatial ? anomaly.spatial.x : 0
                        var wy = anomaly.spatial ? anomaly.spatial.y : 0
                        root.anomalyClicked(anomaly.id, wx, wy)
                    }
                }
            }
        }

        // ── Empty state ──
        Text {
            Layout.fillWidth: true
            visible: root.filteredAnomalies.length === 0 && root.anomalies.length === 0
            text: "Aucune anomalie détectée"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            color: Theme.textMuted
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
