import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionAnomalyPanel — Anomalies détectées par vision
//  Feu, fumée, obstruction, chutes
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var events: engine ? engine.recentEvents : []

    // Filtrer les anomalies (type >= Fire(4))
    property var anomalies: {
        var result = [];
        for (var i = 0; i < events.length; ++i) {
            var t = events[i].type || 0;
            if (t >= 4 && t <= 7) result.push(events[i]);  // Fire, Smoke, Obstruction, Fall
        }
        return result;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "⚠️ Anomalies Vision (" + root.anomalies.length + ")"
                font.pixelSize: 13
                font.bold: true
                color: root.anomalies.length > 0 ? Theme.error : Theme.textPrimary
            }
            Item { Layout.fillWidth: true }
        }

        // ── Compteurs rapides ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { icon: "🔥", label: "Feu", type: 4 },
                    { icon: "💨", label: "Fumée", type: 5 },
                    { icon: "🚫", label: "Obstruction", type: 6 },
                    { icon: "🧎", label: "Chutes", type: 7 }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 4
                    color: {
                        var count = 0;
                        for (var i = 0; i < root.anomalies.length; ++i)
                            if (root.anomalies[i].type === modelData.type) count++;
                        return count > 0 ? Qt.rgba(1, 0, 0, 0.1) : Qt.rgba(0.5, 0.5, 0.5, 0.05);
                    }

                    property int typeCount: {
                        var c = 0;
                        for (var i = 0; i < root.anomalies.length; ++i)
                            if (root.anomalies[i].type === modelData.type) c++;
                        return c;
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1
                        Label {
                            text: modelData.icon + " " + typeCount
                            font.pixelSize: 14
                            font.bold: true
                            color: typeCount > 0 ? Theme.error : Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: modelData.label
                            font.pixelSize: 9
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // ── Liste ──
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.anomalies

            delegate: Rectangle {
                width: ListView.view.width
                height: 40
                radius: 4
                color: Qt.rgba(1, 0, 0, 0.06)
                border.color: Theme.error
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Label {
                        text: modelData.description || "Anomalie"
                        font.pixelSize: 11
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: modelData.cameraId || ""
                        font.pixelSize: 9
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }
}
