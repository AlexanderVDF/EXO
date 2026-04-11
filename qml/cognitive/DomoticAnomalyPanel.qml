import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  DomoticAnomalyPanel — Anomalies domotiques
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null

    property var alerts: {
        if (!engine) return []
        var all = engine.activeAlerts || []
        return all.filter(function(a) { return a.riskType === 5 }) // RiskType::DomoticAnomaly = 5
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "🏠 Anomalies Domotiques"
                font.pixelSize: 14; font.bold: true
                color: Theme.textPrimary
            }
            Item { Layout.fillWidth: true }
            Label {
                text: root.alerts.length + " alerte(s)"
                font.pixelSize: 11
                color: root.alerts.length > 0 ? Theme.warning : Theme.textSecondary
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true; spacing: 6
            model: root.alerts

            delegate: Rectangle {
                width: ListView.view.width
                height: col.implicitHeight + 16
                radius: 6
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                border.color: Theme.accent; border.width: 1

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; margins: 8; verticalCenter: parent.verticalCenter }
                    spacing: 4

                    Label {
                        Layout.fillWidth: true
                        text: modelData.description || ""
                        font.pixelSize: 11; font.bold: true
                        color: Theme.textPrimary; wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        spacing: 12
                        Label { text: "📍 " + (modelData.roomId || "—"); font.pixelSize: 10; color: Theme.textSecondary }
                        Label { text: "🎯 " + Math.round((modelData.confidence || 0) * 100) + "%"; font.pixelSize: 10; color: Theme.warning }
                    }

                    Label {
                        visible: !!modelData.explanation
                        text: modelData.explanation || ""
                        font.pixelSize: 10; font.italic: true
                        color: Theme.info; wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
