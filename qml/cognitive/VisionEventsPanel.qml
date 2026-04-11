import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionEventsPanel — Fil d'événements vision
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var events: engine ? engine.recentEvents : []

    readonly property var severityNames: ["Info", "Basse", "Moyenne", "Haute", "Critique", "Urgence"]
    readonly property var severityColors: [
        Theme.textSecondary, Theme.info, Theme.warning,
        "#FF8C00", Theme.error, "#FF0040"
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Label {
            text: "📋 Événements Vision (" + root.events.length + ")"
            font.pixelSize: 13
            font.bold: true
            color: Theme.textPrimary
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.events

            delegate: Rectangle {
                width: ListView.view.width
                height: 48
                radius: 4
                color: Qt.rgba(root.severityColors[modelData.severity || 0].r || 0,
                               root.severityColors[modelData.severity || 0].g || 0,
                               root.severityColors[modelData.severity || 0].b || 0, 0.08)
                border.color: root.severityColors[modelData.severity || 0]
                border.width: (modelData.severity || 0) >= 3 ? 1 : 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: root.severityColors[modelData.severity || 0]
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Label {
                            text: modelData.description || "Événement"
                            font.pixelSize: 11
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: (modelData.cameraId || "") + " • " +
                                  root.severityNames[modelData.severity || 0]
                            font.pixelSize: 9
                            color: Theme.textSecondary
                        }
                    }

                    Label {
                        text: Math.round((modelData.confidence || 0) * 100) + "%"
                        font.pixelSize: 10
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }
}
